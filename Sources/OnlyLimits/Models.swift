import Foundation

// MARK: - Raw API response  (GET /backend-api/wham/usage)

/// Mirrors the fields we care about from ChatGPT's Codex usage endpoint.
/// The endpoint returns more keys (code_review_rate_limit, promo, …) which we
/// intentionally ignore for this single-purpose monitor.
struct UsageResponse: Decodable {
    var account_id: String?
    var email: String?
    var plan_type: String?
    var rate_limit: RateLimit?
    var credits: Credits?

    struct RateLimit: Decodable {
        var allowed: Bool?
        var limit_reached: Bool?
        var primary_window: Window?
        var secondary_window: Window?
    }

    struct Window: Decodable {
        var used_percent: Double?
        var limit_window_seconds: Int?
        var reset_after_seconds: Int?
        var reset_at: Int?           // unix seconds
    }

    struct Credits: Decodable {
        var has_credits: Bool?
        var unlimited: Bool?
        // balance may come back as string / number — decode leniently.
        var balance: String?

        enum CodingKeys: String, CodingKey { case has_credits, unlimited, balance }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            has_credits = try c.decodeIfPresent(Bool.self, forKey: .has_credits)
            unlimited = try c.decodeIfPresent(Bool.self, forKey: .unlimited)
            if let s = try? c.decodeIfPresent(String.self, forKey: .balance) { balance = s }
            else if let d = try? c.decodeIfPresent(Double.self, forKey: .balance) { balance = String(d) }
            else if let i = try? c.decodeIfPresent(Int.self, forKey: .balance) { balance = String(i) }
            else { balance = nil }
        }
    }
}

// MARK: - Normalized display model

struct UsageWindow: Identifiable {
    let id = UUID()
    /// Actual window duration in seconds, as reported by the API.
    var windowSeconds: Int?
    var usedPercent: Double
    var resetsAt: Date?
}

/// A fully-resolved snapshot for one account, ready to render.
struct AccountUsage {
    var windows: [UsageWindow] = []
    var creditsBalance: String?
    var creditsUnlimited: Bool = false
    var limitReached: Bool = false
    var fetchedAt: Date = .now

    /// Highest used percentage across all windows — drives the compact bar label.
    var worstPercent: Double { windows.map(\.usedPercent).max() ?? 0 }

    /// True when a window is at 0% and its reset is still a full window away —
    /// meaning the window hasn't been "started", so its reset keeps sliding
    /// forward by the full period on every refresh. Sending one small request
    /// anchors it. (A just-started window has secondsLeft < full period.)
    var unanchored: Bool {
        windows.contains { w in
            guard w.usedPercent == 0, let secs = w.windowSeconds, let reset = w.resetsAt else { return false }
            return reset.timeIntervalSinceNow >= Double(secs) - 60
        }
    }

    static func from(_ r: UsageResponse) -> AccountUsage {
        var out = AccountUsage()
        let now = Date()
        func resolve(_ w: UsageResponse.Window) -> Date? {
            if let at = w.reset_at { return Date(timeIntervalSince1970: TimeInterval(at)) }
            if let after = w.reset_after_seconds { return now.addingTimeInterval(TimeInterval(after)) }
            return nil
        }
        func build(_ w: UsageResponse.Window?) -> UsageWindow? {
            guard let w else { return nil }
            let pct = w.used_percent ?? 0
            // Treat 0% with no reset info as "no data" and skip it.
            if pct == 0 && w.reset_at == nil && w.reset_after_seconds == nil { return nil }
            return UsageWindow(windowSeconds: w.limit_window_seconds,
                               usedPercent: pct, resetsAt: resolve(w))
        }
        let raw = [r.rate_limit?.primary_window, r.rate_limit?.secondary_window].compactMap { $0 }
        var windows = raw.compactMap(build)
        // Shorter window first (nil durations last).
        windows.sort { ($0.windowSeconds ?? .max) < ($1.windowSeconds ?? .max) }
        out.windows = windows
        out.limitReached = r.rate_limit?.limit_reached ?? false
        if let cr = r.credits {
            out.creditsUnlimited = cr.unlimited ?? false
            out.creditsBalance = cr.balance
        }
        return out
    }
}
