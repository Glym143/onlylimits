import Foundation

/// Persists the list of monitored accounts (including refresh tokens) to
/// ~/Library/Application Support/OnlyLimits/accounts.json with 0600 perms.
///
/// Note: these refresh tokens are the same secrets already stored in
/// ~/.codex/auth.json on this machine, so this is not a new exposure class.
/// A future hardening step would move the token fields into the Keychain.
@MainActor
final class AccountStore {
    private(set) var accounts: [StoredAccount] = []

    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("OnlyLimits", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                 attributes: [.posixPermissions: 0o700])
        fileURL = dir.appendingPathComponent("accounts.json")

        // One-time migration from the previous app name (CodexUsageBar).
        let legacy = base.appendingPathComponent("CodexUsageBar/accounts.json")
        if !FileManager.default.fileExists(atPath: fileURL.path),
           FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.copyItem(at: legacy, to: fileURL)
        }

        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([StoredAccount].self, from: data) else { return }
        accounts = list
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    /// Add or update an account (keyed by account id). Returns true if it was new.
    @discardableResult
    func upsert(_ account: StoredAccount) -> Bool {
        if let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            // preserve original addedAt, refresh the token material
            var updated = account
            updated.addedAt = accounts[idx].addedAt
            accounts[idx] = updated
            persist()
            return false
        }
        accounts.append(account)
        persist()
        return true
    }

    func remove(id: String) {
        accounts.removeAll { $0.id == id }
        persist()
    }

    /// Update just the token material after a refresh, keeping labels intact.
    func updateTokens(id: String, tokens: RefreshedTokens) {
        guard let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[idx].accessToken = tokens.accessToken
        accounts[idx].refreshToken = tokens.refreshToken
        accounts[idx].accessTokenExp = tokens.expiry
        persist()
    }

    /// Cache the label fields discovered from a usage response.
    func updateLabels(id: String, email: String?, plan: String?) {
        guard let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        var changed = false
        if let email, accounts[idx].email != email { accounts[idx].email = email; changed = true }
        if let plan, accounts[idx].planType != plan { accounts[idx].planType = plan; changed = true }
        if changed { persist() }
    }
}
