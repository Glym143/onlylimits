import Foundation

/// "Anchors" an account's weekly window by sending one minimal Codex request.
///
/// Rather than hand-craft the (complex, changing) `/backend-api/codex/responses`
/// call, we drive the real Codex CLI in a throwaway `CODEX_HOME` seeded with the
/// account's own fresh tokens — so the request goes out exactly the way Codex
/// itself sends it, independently of which account `~/.codex` is logged into.
enum Anchorer {

    /// Locate the Codex CLI binary (bundled in the ChatGPT app, or installed).
    static func codexBinary() -> String? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            NSHomeDirectory() + "/.codex/bin/codex",
            NSHomeDirectory() + "/.local/bin/codex",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static var isAvailable: Bool { codexBinary() != nil }

    struct Outcome { let ok: Bool; let output: String }

    /// Runs one tiny `codex exec` as the given account. `access`/`id`/`refresh`
    /// should be freshly refreshed so the CLI won't rotate the refresh token.
    static func anchor(accountID: String, access: String, idToken: String, refresh: String,
                       timeout: TimeInterval = 120) async -> Outcome {
        guard let bin = codexBinary() else {
            return Outcome(ok: false, output: "Codex CLI not found (install the ChatGPT app or `codex`).")
        }
        let fm = FileManager.default
        let home = fm.temporaryDirectory.appendingPathComponent("ol_home_" + UUID().uuidString)
        let work = fm.temporaryDirectory.appendingPathComponent("ol_work_" + UUID().uuidString)
        try? fm.createDirectory(at: home, withIntermediateDirectories: true)
        try? fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: home); try? fm.removeItem(at: work) }

        let auth: [String: Any] = [
            "OPENAI_API_KEY": NSNull(),
            "tokens": [
                "id_token": idToken,
                "access_token": access,
                "refresh_token": refresh,
                "account_id": accountID,
            ],
            "last_refresh": ISO8601DateFormatter().string(from: Date()),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: auth) else {
            return Outcome(ok: false, output: "Failed to encode temp auth.json")
        }
        let authURL = home.appendingPathComponent("auth.json")
        do {
            try data.write(to: authURL)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: authURL.path)
        } catch {
            return Outcome(ok: false, output: "Failed to write temp auth.json: \(error.localizedDescription)")
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = ["exec", "--sandbox", "read-only", "--skip-git-repo-check",
                          "-C", work.path, "Reply with exactly: ok"]
        var env = ProcessInfo.processInfo.environment
        env["CODEX_HOME"] = home.path
        proc.environment = env
        proc.standardInput = FileHandle.nullDevice     // don't block reading stdin
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        do { try proc.run() } catch {
            return Outcome(ok: false, output: "Launch failed: \(error.localizedDescription)")
        }

        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        if proc.isRunning { proc.terminate(); return Outcome(ok: false, output: "Anchor timed out") }

        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return Outcome(ok: proc.terminationStatus == 0, output: out)
    }
}
