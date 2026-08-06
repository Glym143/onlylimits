import Foundation

enum CodexError: LocalizedError {
    case unauthorized
    case http(Int)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Token expired — re-import this account (codex login)."
        case .http(let c): return "Server returned HTTP \(c)."
        case .network(let m): return m
        }
    }
}

/// Result of refreshing an access token via the OpenAI OAuth endpoint.
struct RefreshedTokens {
    var accessToken: String
    var refreshToken: String      // may be rotated
    var expiry: Date?
}

/// Stateless client for the two Codex endpoints we need. Safe to call
/// concurrently for many accounts.
enum CodexClient {
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    static let tokenURL = URL(string: "https://auth.openai.com/oauth/token")!

    private static let browserUA =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    // MARK: Refresh

    static func refresh(refreshToken: String) async throws -> RefreshedTokens {
        var req = URLRequest(url: tokenURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken,
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            if code == 401 || code == 400 { throw CodexError.unauthorized }
            throw CodexError.http(code)
        }
        struct TokenResp: Decodable { var access_token: String; var refresh_token: String? }
        let t = try JSONDecoder().decode(TokenResp.self, from: data)
        return RefreshedTokens(
            accessToken: t.access_token,
            refreshToken: t.refresh_token?.isEmpty == false ? t.refresh_token! : refreshToken,
            expiry: JWT.expiry(t.access_token)
        )
    }

    // MARK: Usage

    static func fetchUsage(accessToken: String, accountID: String) async throws -> UsageResponse {
        var req = URLRequest(url: usageURL)
        req.httpMethod = "GET"
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
        req.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("*/*", forHTTPHeaderField: "accept")
        req.setValue(browserUA, forHTTPHeaderField: "user-agent")
        req.setValue("https://chatgpt.com", forHTTPHeaderField: "origin")
        req.setValue("https://chatgpt.com/", forHTTPHeaderField: "referer")
        req.timeoutInterval = 30

        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw CodexError.network(error.localizedDescription) }

        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            if code == 401 { throw CodexError.unauthorized }
            throw CodexError.http(code)
        }
        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }
}
