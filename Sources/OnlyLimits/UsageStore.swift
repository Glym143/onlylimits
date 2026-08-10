import Foundation
import SwiftUI
import AppKit
import ServiceManagement

struct AccountRow: Identifiable {
    let id: String
    var label: String
    var plan: String?
    var usage: AccountUsage?
    var error: String?
    var isLoading: Bool
}

/// Outcome of one account's network round-trip. Computed off the main actor,
/// then applied back on the main actor.
private struct FetchOutcome {
    let id: String
    var usage: AccountUsage?
    var email: String?
    var plan: String?
    var refreshed: RefreshedTokens?
    var error: String?
}

/// What the menu-bar title shows.
enum MenuMode: String, CaseIterable {
    case active      // only the account Codex is logged into right now (bar + %)
    case all         // every account as a bar, no numbers
    case allNumbers  // every account as a bar + its %
}

/// How account rows are ordered in the panel.
enum SortMode: String, CaseIterable {
    case `default`        // order accounts were added
    case resetSoonest     // the one that resets first on top
    case remainingLeast   // the most-constrained (least remaining) on top
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var rows: [AccountRow] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var nextRefreshAt: Date?
    @Published private(set) var isRefreshing = false
    @Published var lastMessage: String?          // transient import/error banner
    @Published var availableUpdate: UpdateChecker.Update?
    @Published var isLoggingIn = false
    @Published private(set) var activeAccountID: String?
    @Published var menuMode: MenuMode = MenuMode(rawValue: UserDefaults.standard.string(forKey: "menuMode") ?? "") ?? .active {
        didSet { UserDefaults.standard.set(menuMode.rawValue, forKey: "menuMode") }
    }
    @Published var language: Language = UsageStore.initialLanguage() {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    @Published var sortMode: SortMode = SortMode(rawValue: UserDefaults.standard.string(forKey: "sortMode") ?? "") ?? .default {
        didSet { UserDefaults.standard.set(sortMode.rawValue, forKey: "sortMode"); rebuildRows() }
    }

    /// A saved choice wins; otherwise match the macOS system language if it's one
    /// we support (ru / ja / zh), else fall back to English.
    private static func initialLanguage() -> Language {
        if let saved = UserDefaults.standard.string(forKey: "language"),
           let lang = Language(rawValue: saved) {
            return lang
        }
        for code in Locale.preferredLanguages {
            let c = code.lowercased()
            if c.hasPrefix("ru") { return .ru }
            if c.hasPrefix("ja") { return .ja }
            if c.hasPrefix("zh") { return .zh }
            if c.hasPrefix("en") { return .en }
        }
        return .en
    }
    /// Localized strings for the current language.
    var s: Strings { Strings(lang: language) }

    // On by default; a saved choice (incl. off) wins.
    @Published var autoAnchor: Bool = (UserDefaults.standard.object(forKey: "autoAnchor") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(autoAnchor, forKey: "autoAnchor") }
    }
    @Published private(set) var anchoringIDs: Set<String> = []
    /// Accounts whose weekly reset was observed sliding forward (not yet started).
    @Published private(set) var slidingIDs: Set<String> = []
    let canAnchor = Anchorer.isAvailable
    /// Previous poll's weekly reset (unix) per account — to detect forward movement.
    private var lastWeeklyReset: [String: TimeInterval] = [:]
    /// Accounts just anchored — skip one sliding-eval so the anchor's own forward
    /// jump in reset time isn't mistaken for sliding.
    private var anchorGrace: Set<String> = []

    @Published var refreshMinutes: Double = 5

    private let store = AccountStore()
    private var stateByID: [String: (usage: AccountUsage?, error: String?, loading: Bool)] = [:]
    private var timer: Timer?
    private var updateTimer: Timer?
    private var loginTask: Task<Void, Never>?

    init() {
        if store.accounts.isEmpty {
            // First launch: silently pull in whatever the CLI is logged into now.
            if let acc = try? AuthImport.importCurrent() { store.upsert(acc) }
        }
        activeAccountID = AuthImport.currentActiveAccountID()
        rebuildRows()
        startTimer()
        Task {
            await refreshAll()
            checkForUpdate()
            // A quick second sample so a sliding window is caught within ~40s, not minutes.
            try? await Task.sleep(nanoseconds: 40_000_000_000)
            await refreshAll()
        }
        // Re-check for updates every 6 hours.
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { await self?.checkForUpdate() }
        }
    }

    // MARK: - Updates

    private var skippedVersion = UserDefaults.standard.string(forKey: "skippedVersion") ?? ""

    func checkForUpdate(manual: Bool = false) {
        Task {
            if manual {                              // an explicit check un-skips
                skippedVersion = ""
                UserDefaults.standard.removeObject(forKey: "skippedVersion")
            }
            if let upd = await UpdateChecker.check(), upd.version != skippedVersion {
                availableUpdate = upd
            } else {
                availableUpdate = nil
                if manual { lastMessage = s.upToDate }
            }
        }
    }

    /// Dismiss the banner for this version; it reappears only for a newer one.
    func skipUpdate() {
        if let v = availableUpdate?.version {
            skippedVersion = v
            UserDefaults.standard.set(v, forKey: "skippedVersion")
        }
        availableUpdate = nil
    }

    func openUpdate() {
        let target = availableUpdate?.url ?? UpdateChecker.releasesPage
        if let url = URL(string: target) { NSWorkspace.shared.open(url) }
    }

    // MARK: - Launch at login (modern SMAppService, macOS 13+)

    @Published var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)

    func setLaunchAtLogin(_ on: Bool) {
        let svc = SMAppService.mainApp
        do {
            if on {
                if svc.status != .enabled { try svc.register() }
            } else {
                if svc.status == .enabled { try svc.unregister() }
            }
        } catch {
            lastMessage = "Login item: \(error.localizedDescription)"
        }
        launchAtLogin = (SMAppService.mainApp.status == .enabled)   // reflect the real state
    }

    // MARK: - Public actions

    /// Add an account via the in-app "Sign in with ChatGPT" browser flow.
    /// Works for any number of accounts, independent of the Codex CLI.
    func loginWithBrowser() {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        lastMessage = s.openingBrowser
        loginTask = Task {
            do {
                let acc = try await CodexLogin.login()
                let isNew = store.upsert(acc)
                lastMessage = isNew ? s.added(acc.label) : s.updated(acc.label)
                isLoggingIn = false
                loginTask = nil
                rebuildRows()
                await refreshAll()
            } catch is CancellationError {
                lastMessage = s.loginCancelled
                isLoggingIn = false
                loginTask = nil
            } catch {
                lastMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isLoggingIn = false
                loginTask = nil
            }
        }
    }

    /// Abort a pending browser login (user changed their mind). Resets the
    /// button immediately and stops the local callback server.
    func cancelLogin() {
        loginTask?.cancel()
        loginTask = nil
        isLoggingIn = false
        lastMessage = s.loginCancelled
    }

    /// Send one tiny Codex request as this account to start (anchor) its weekly
    /// window, so its reset stops sliding forward every refresh.
    func anchor(id: String) {
        guard canAnchor, !anchoringIDs.contains(id),
              let acc = store.accounts.first(where: { $0.id == id }) else { return }
        anchoringIDs.insert(id)
        rebuildRows()
        Task {
            do {
                // Refresh first so the CLI won't need to — avoids it rotating the
                // refresh token out from under our own polling. Persist the fresh set.
                let r = try await CodexClient.refresh(refreshToken: acc.refreshToken)
                store.updateTokens(id: id, tokens: r)
                let outcome = await Anchorer.anchor(accountID: id, access: r.accessToken,
                                                    idToken: r.idToken ?? "", refresh: r.refreshToken)
                anchoringIDs.remove(id)
                if outcome.ok {
                    anchorGrace.insert(id)          // rebaseline next poll (ignore the anchor's own jump)
                    slidingIDs.remove(id)
                    lastMessage = s.anchored(acc.label)
                } else {
                    lastMessage = "\(s.anchorFailed): \(outcome.output.suffix(140))"
                }
                rebuildRows()
                await refreshAll()
            } catch {
                anchoringIDs.remove(id)
                lastMessage = "\(s.anchorFailed): \(error.localizedDescription)"
                rebuildRows()
            }
        }
    }

    /// Secondary path: snapshot whatever account the Codex CLI is logged into.
    func addCurrentAccount() {
        do {
            let acc = try AuthImport.importCurrent()
            let isNew = store.upsert(acc)
            lastMessage = isNew ? s.added(acc.label) : s.updated(acc.label)
            rebuildRows()
            Task { await refreshAll() }
        } catch {
            lastMessage = error.localizedDescription
        }
    }

    func remove(id: String) {
        store.remove(id: id)
        stateByID[id] = nil
        rebuildRows()
    }

    func refresh() { Task { await refreshAll() } }

    func setRefreshMinutes(_ m: Double) {
        refreshMinutes = m
        startTimer()
    }

    // MARK: - Status bar summary

    /// Remaining % (0…100) for a row, or nil if not loaded yet.
    private func remaining(_ row: AccountRow) -> Int? {
        guard let u = row.usage else { return nil }
        return Int((100 - u.worstPercent).rounded())
    }

    /// The menu-bar image: a compact colored mini bar chart.
    /// active → one bar + %, all → one bar per account.
    var statusImage: NSImage {
        let loaded = rows.filter { $0.usage != nil }
        guard !loaded.isEmpty else { return StatusBarImage.placeholder() }

        func value(_ r: AccountRow) -> StatusBarImage.Value {
            let rem = Double(remaining(r) ?? 0)
            return .init(remaining: rem, color: Palette.nsColor(rem))
        }

        switch menuMode {
        case .active:
            let row = loaded.first(where: { $0.id == activeAccountID })
                ?? loaded.min(by: { (remaining($0) ?? 100) < (remaining($1) ?? 100) })!
            return StatusBarImage.make(values: [value(row)], showNumber: true)
        case .all:
            return StatusBarImage.make(values: loaded.map(value), showNumber: false)
        case .allNumbers:
            return StatusBarImage.make(values: loaded.map(value), showNumber: true)
        }
    }

    // MARK: - Refresh pipeline

    func refreshAll() async {
        guard !isRefreshing else { return }
        let snapshot = store.accounts
        guard !snapshot.isEmpty else { rebuildRows(); return }

        activeAccountID = AuthImport.currentActiveAccountID()
        isRefreshing = true
        for a in snapshot { stateByID[a.id, default: (nil, nil, false)].loading = true }
        rebuildRows()

        let results = await withTaskGroup(of: FetchOutcome.self) { group -> [FetchOutcome] in
            for a in snapshot { group.addTask { await Self.fetchOne(a) } }
            var acc: [FetchOutcome] = []
            for await o in group { acc.append(o) }
            return acc
        }

        for o in results {
            if let r = o.refreshed { store.updateTokens(id: o.id, tokens: r) }
            store.updateLabels(id: o.id, email: o.email, plan: o.plan)
            stateByID[o.id] = (usage: o.usage, error: o.error, loading: false)
        }
        isRefreshing = false
        lastUpdated = .now
        rebuildRows()
        startTimer()          // realign the countdown to the last refresh

        detectSlidingAndAnchor()
    }

    /// A weekly window is "sliding" when it's at 0% and its reset keeps moving
    /// forward every poll (server sets reset = now + 7d until the window starts).
    /// We detect that by comparing reset across polls — reliable, unlike a single
    /// snapshot — and anchor whenever movement is seen (continuously).
    private func detectSlidingAndAnchor() {
        var sliding: Set<String> = []
        for row in rows {
            guard let u = row.usage,
                  let w = u.windows.max(by: { ($0.windowSeconds ?? 0) < ($1.windowSeconds ?? 0) }),
                  let reset = w.resetsAt else { continue }
            let id = row.id
            let cur = reset.timeIntervalSince1970
            if anchorGrace.contains(id) {            // ignore the anchor's own forward jump
                anchorGrace.remove(id)
                lastWeeklyReset[id] = cur
                continue
            }
            if w.usedPercent == 0, let prev = lastWeeklyReset[id], cur > prev + 20 {
                sliding.insert(id)                   // reset moved forward → still sliding
            }
            lastWeeklyReset[id] = cur
        }
        slidingIDs = sliding
        if autoAnchor && canAnchor {
            for id in sliding where !anchoringIDs.contains(id) { anchor(id: id) }
        }
    }

    /// Network round-trip for a single account. Refreshes the access token
    /// proactively (near expiry) and reactively (on a 401), then retries once.
    private nonisolated static func fetchOne(_ account: StoredAccount) async -> FetchOutcome {
        var access = account.accessToken
        var refreshed: RefreshedTokens?

        let nearExpiry = account.accessTokenExp.map { $0 < Date().addingTimeInterval(300) } ?? true
        if nearExpiry {
            do {
                let r = try await CodexClient.refresh(refreshToken: account.refreshToken)
                access = r.accessToken; refreshed = r
            } catch {
                return FetchOutcome(id: account.id, error: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }

        do {
            let resp = try await CodexClient.fetchUsage(accessToken: access, accountID: account.id)
            return FetchOutcome(id: account.id, usage: .from(resp),
                                email: resp.email, plan: resp.plan_type, refreshed: refreshed)
        } catch CodexError.unauthorized {
            // Access token rejected — force a refresh and retry exactly once.
            do {
                let r = try await CodexClient.refresh(refreshToken: account.refreshToken)
                let resp = try await CodexClient.fetchUsage(accessToken: r.accessToken, accountID: account.id)
                return FetchOutcome(id: account.id, usage: .from(resp),
                                    email: resp.email, plan: resp.plan_type, refreshed: r)
            } catch {
                return FetchOutcome(id: account.id, refreshed: refreshed,
                                    error: (error as? LocalizedError)?.errorDescription ?? "Re-import this account (codex login).")
            }
        } catch {
            return FetchOutcome(id: account.id, refreshed: refreshed,
                                error: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func rebuildRows() {
        let built = store.accounts.map { a -> AccountRow in
            let st = stateByID[a.id]
            return AccountRow(id: a.id, label: a.label, plan: a.planType,
                              usage: st?.usage, error: st?.error, isLoading: st?.loading ?? false)
        }
        rows = sorted(built)
    }

    /// Weekly reset (unix) for sorting; no-data sorts last.
    private func weeklyReset(_ r: AccountRow) -> TimeInterval {
        r.usage?.windows.max(by: { ($0.windowSeconds ?? 0) < ($1.windowSeconds ?? 0) })?
            .resetsAt?.timeIntervalSince1970 ?? .greatestFiniteMagnitude
    }

    private func sorted(_ rows: [AccountRow]) -> [AccountRow] {
        switch sortMode {
        case .default:
            return rows
        case .resetSoonest:
            return rows.sorted { a, b in
                let ra = weeklyReset(a), rb = weeklyReset(b)
                return ra != rb ? ra < rb : a.label < b.label
            }
        case .remainingLeast:
            return rows.sorted { a, b in
                let ra = remaining(a).map(Double.init) ?? .greatestFiniteMagnitude
                let rb = remaining(b).map(Double.init) ?? .greatestFiniteMagnitude
                return ra != rb ? ra < rb : a.label < b.label
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        let interval = max(60, refreshMinutes * 60)
        nextRefreshAt = Date().addingTimeInterval(interval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.refreshAll() }
        }
    }
}
