import Foundation
import CryptoKit
import Security

/// PKCE (RFC 7636) parameters plus an OAuth `state` for CSRF protection.
/// code_challenge = base64url(SHA256(code_verifier)).
struct PKCECodes {
    let codeVerifier: String
    let codeChallenge: String
    let state: String

    init() {
        codeVerifier = Self.randomURLSafe(byteCount: 64)
        state = Self.randomURLSafe(byteCount: 32)
        let digest = SHA256.hash(data: Data(codeVerifier.utf8))
        codeChallenge = Self.base64URL(Data(digest))
    }

    private static func randomURLSafe(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
