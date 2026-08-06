import Foundation

/// One stored Codex account. `refreshToken` lets us keep the account fresh
/// forever, independently of which account the Codex CLI is currently logged
/// into — that is what makes simultaneous multi-account monitoring possible.
struct StoredAccount: Codable, Identifiable, Equatable {
    var id: String            // ChatGPT account_id (uuid) — stable key
    var email: String?
    var planType: String?
    var authMode: String?
    var accessToken: String
    var refreshToken: String
    var accessTokenExp: Date?
    var addedAt: Date

    var label: String { email ?? String(id.prefix(8)) }
}

enum AuthImportError: LocalizedError {
    case notFound
    case unreadable(String)
    case notChatGPT

    var errorDescription: String? {
        switch self {
        case .notFound: return "~/.codex/auth.json not found. Run `codex login` first."
        case .unreadable(let m): return "Couldn't read auth.json: \(m)"
        case .notChatGPT: return "This account uses an API key, not a ChatGPT login — usage limits are only available for ChatGPT/plan accounts."
        }
    }
}

enum AuthImport {

    /// Locations the Codex CLI may store credentials, in priority order.
    static var candidatePaths: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".codex/auth.json"),
            home.appendingPathComponent(".config/codex/auth.json"),
            home.appendingPathComponent(".openai/auth.json"),
        ]
    }

    /// The account_id the Codex CLI is currently logged into (from auth.json),
    /// used to mark which stored account is "active" right now. nil if none.
    static func currentActiveAccountID() -> String? {
        guard let url = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let data = try? Data(contentsOf: url) else { return nil }
        struct A: Decodable { struct T: Decodable { var account_id: String? }; var tokens: T? }
        return (try? JSONDecoder().decode(A.self, from: data))?.tokens?.account_id
    }

    /// Read the currently logged-in Codex account from disk.
    static func importCurrent() throws -> StoredAccount {
        guard let url = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw AuthImportError.notFound
        }
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw AuthImportError.unreadable(error.localizedDescription) }

        struct AuthFile: Decodable {
            var auth_mode: String?
            var OPENAI_API_KEY: String?
            var tokens: Tokens?
            struct Tokens: Decodable {
                var access_token: String?
                var refresh_token: String?
                var account_id: String?
                var id_token: String?
            }
        }
        guard let auth = try? JSONDecoder().decode(AuthFile.self, from: data),
              let t = auth.tokens,
              let access = t.access_token, !access.isEmpty,
              let refresh = t.refresh_token, !refresh.isEmpty else {
            throw AuthImportError.notChatGPT
        }
        let accountId = t.account_id ?? JWT.claim("chatgpt_account_id", in: access) ?? access.hashValue.description
        let claims = JWT.profile(from: t.id_token ?? access)
        return StoredAccount(
            id: accountId,
            email: claims.email,
            planType: claims.plan,
            authMode: auth.auth_mode,
            accessToken: access,
            refreshToken: refresh,
            accessTokenExp: JWT.expiry(access),
            addedAt: .now
        )
    }
}

// MARK: - Minimal JWT decoding (payload only, no signature verification)

enum JWT {
    static func payload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+")
                                   .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    static func expiry(_ token: String) -> Date? {
        guard let exp = payload(token)?["exp"] as? Double else {
            if let expI = payload(token)?["exp"] as? Int { return Date(timeIntervalSince1970: TimeInterval(expI)) }
            return nil
        }
        return Date(timeIntervalSince1970: exp)
    }

    /// Look up a claim inside the nested OpenAI auth object.
    static func claim(_ key: String, in token: String) -> String? {
        guard let p = payload(token) else { return nil }
        if let v = p[key] as? String { return v }
        if let auth = p["https://api.openai.com/auth"] as? [String: Any], let v = auth[key] as? String { return v }
        return nil
    }

    static func profile(from token: String) -> (email: String?, plan: String?) {
        guard let p = payload(token) else { return (nil, nil) }
        var email: String?
        var plan: String?
        if let prof = p["https://api.openai.com/profile"] as? [String: Any] {
            email = prof["email"] as? String
        }
        if let auth = p["https://api.openai.com/auth"] as? [String: Any] {
            plan = (auth["chatgpt_plan_type"] as? String) ?? (auth["plan_type"] as? String)
        }
        return (email, plan)
    }
}
