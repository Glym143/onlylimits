import Foundation

/// Lightweight, dependency-free update check against GitHub Releases.
/// (No silent install — an unsigned app can't self-update cleanly past
/// Gatekeeper; we surface the new version and let the user download it.)
enum UpdateChecker {
    static let repo = "Glym143/onlylimits"
    static let releasesAPI = URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!
    static let releasesPage = "https://github.com/\(repo)/releases/latest"

    struct Update: Equatable, Sendable {
        let version: String   // e.g. "1.2"
        let url: String       // .dmg asset, or the release page
    }

    static func currentVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    /// Returns an Update if the latest published release is newer than this build.
    static func check() async -> Update? {
        var req = URLRequest(url: releasesAPI)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("OnlyLimits", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        struct Rel: Decodable {
            var tag_name: String
            var html_url: String
            var draft: Bool
            var prerelease: Bool
            var assets: [Asset]
            struct Asset: Decodable { var name: String; var browser_download_url: String }
        }
        guard let rel = try? JSONDecoder().decode(Rel.self, from: data),
              !rel.draft, !rel.prerelease else { return nil }

        let latest = rel.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        guard isNewer(latest, than: currentVersion()) else { return nil }

        let dmg = rel.assets.first { $0.name.lowercased().hasSuffix(".dmg") }?.browser_download_url
        return Update(version: latest, url: dmg ?? rel.html_url)
    }

    /// Compares dotted numeric versions ("1.10" > "1.9").
    static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ s: String) -> [Int] { s.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 } }
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
