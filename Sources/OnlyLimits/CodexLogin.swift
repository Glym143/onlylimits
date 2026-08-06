import Foundation
import AppKit

/// "Sign in with ChatGPT" — the official Codex CLI public OAuth client (PKCE,
/// no client secret). Opens the system browser, runs a localhost callback,
/// and exchanges the code for tokens. Lets us store any number of accounts
/// without touching the Codex CLI.
enum CodexLogin {
    static let issuer = "https://auth.openai.com"
    static let authorizeURL = "\(issuer)/oauth/authorize"
    static let tokenURL = URL(string: "\(issuer)/oauth/token")!
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let scope = "openid profile email offline_access api.connectors.read api.connectors.invoke"
    static let ports: [UInt16] = [1455, 1457]
    static let callbackPath = "/auth/callback"
    static let originator = "codex_cli_rs"

    enum LoginError: LocalizedError {
        case portInUse
        case cancelledOrTimedOut
        case stateMismatch
        case provider(String)
        case noRefreshToken

        var errorDescription: String? {
            switch self {
            case .portInUse: return "Ports 1455/1457 are busy — close the Codex CLI login or another tracker and retry."
            case .cancelledOrTimedOut: return "Sign-in timed out. Try again."
            case .stateMismatch: return "Security check failed (state mismatch). Try again."
            case .provider(let m): return m
            case .noRefreshToken: return "OpenAI didn't return a refresh token. Try again."
            }
        }
    }

    /// Thread-safe holder for the first browser callback.
    final class CallbackBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: [String: String]?
        func set(_ v: [String: String]) { lock.lock(); if value == nil { value = v }; lock.unlock() }
        func get() -> [String: String]? { lock.lock(); defer { lock.unlock() }; return value }
    }

    /// Run the full browser OAuth flow and return a ready-to-store account.
    /// Cancellable: cancelling the surrounding Task aborts the wait and stops
    /// the local callback server (throws CancellationError).
    @MainActor
    static func login(timeout: TimeInterval = 180) async throws -> StoredAccount {
        let pkce = PKCECodes()
        let server = OAuthCallbackServer()
        defer { server.stop() }

        let box = CallbackBox()
        guard server.start(ports: ports, onCallback: { box.set($0) }) != nil else {
            throw LoginError.portInUse
        }
        let redirectURI = "http://localhost:\(server.port)\(callbackPath)"
        guard let authURL = buildAuthorizeURL(pkce: pkce, redirectURI: redirectURI) else {
            throw LoginError.provider("Couldn't build the authorization URL.")
        }
        NSWorkspace.shared.open(authURL)

        // Poll for the callback; Task.checkCancellation()/sleep abort instantly
        // when the user hits Cancel, and the deadline enforces the timeout.
        let start = Date()
        var query: [String: String] = [:]
        while true {
            try Task.checkCancellation()
            if let q = box.get() { query = q; break }
            if Date().timeIntervalSince(start) > timeout { throw LoginError.cancelledOrTimedOut }
            try await Task.sleep(nanoseconds: 150_000_000)
        }

        if let err = query["error"] { throw LoginError.provider(err) }
        guard query["state"] == pkce.state else { throw LoginError.stateMismatch }
        guard let code = query["code"] else { throw LoginError.cancelledOrTimedOut }

        return try await exchange(code: code, verifier: pkce.codeVerifier, redirectURI: redirectURI)
    }

    private static func buildAuthorizeURL(pkce: PKCECodes, redirectURI: String) -> URL? {
        var comps = URLComponents(string: authorizeURL)
        comps?.queryItems = [
            .init(name: "response_type", value: "code"),
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "scope", value: scope),
            .init(name: "code_challenge", value: pkce.codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "id_token_add_organizations", value: "true"),
            .init(name: "originator", value: originator),
            .init(name: "state", value: pkce.state),
            // Force a fresh login screen every time, so you can sign in with a
            // DIFFERENT account instead of the browser silently reusing the
            // current chatgpt.com session. This is what makes adding a 2nd,
            // 3rd, … account work without manually logging out first.
            .init(name: "prompt", value: "login"),
        ]
        return comps?.url
    }

    /// Exchange the authorization code for tokens (form-urlencoded, per Codex CLI).
    private static func exchange(code: String, verifier: String, redirectURI: String) async throws -> StoredAccount {
        var comps = URLComponents()
        comps.queryItems = [
            .init(name: "grant_type", value: "authorization_code"),
            .init(name: "code", value: code),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "client_id", value: clientID),
            .init(name: "code_verifier", value: verifier),
        ]
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = (comps.percentEncodedQuery ?? "").data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LoginError.provider("Token exchange failed (HTTP \(code)). \(body.prefix(160))")
        }
        struct T: Decodable { var access_token: String; var refresh_token: String?; var id_token: String? }
        let t = try JSONDecoder().decode(T.self, from: data)
        guard let refresh = t.refresh_token, !refresh.isEmpty else { throw LoginError.noRefreshToken }

        let accountId = JWT.claim("chatgpt_account_id", in: t.access_token)
            ?? (t.id_token.flatMap { JWT.claim("chatgpt_account_id", in: $0) })
            ?? String(t.access_token.suffix(12))
        let profile = JWT.profile(from: t.id_token ?? t.access_token)

        return StoredAccount(
            id: accountId,
            email: profile.email,
            planType: profile.plan,
            authMode: "chatgpt",
            accessToken: t.access_token,
            refreshToken: refresh,
            accessTokenExp: JWT.expiry(t.access_token),
            addedAt: .now
        )
    }
}
