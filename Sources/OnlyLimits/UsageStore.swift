import Foundation
import SwiftUI
import AppKit

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

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var rows: [AccountRow] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var nextRefreshAt: Date?
    @Published private(set) var isRefreshing = false
    @Published var lastMessage: String?          // transient import/error banner
    @Published var isLoggingIn = false
    @Published private(set) var activeAccountID: String?
    @Published var menuMode: MenuMode = MenuMode(rawValue: UserDefaults.standard.string(forKey: "menuMode") ?? "") ?? .active {
        didSet { UserDefaults.standard.set(menuMode.rawValue, forKey: "menuMode") }
    }
    @Published var language: Language = UsageStore.initialLanguage() {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
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

    @Published var refreshMinutes: Double = 5

    private let store = AccountStore()
    private var stateByID: [String: (usage: AccountUsage?, error: String?, loading: Bool)] = [:]
    private var timer: Timer?
    private var loginTask: Task<Void, Never>?

    init() {
        if store.accounts.isEmpty {
            // First launch: silently pull in whatever the CLI is logged into now.
            if let acc = try? AuthImport.importCurrent() { store.upsert(acc) }
        }
        activeAccountID = AuthImport.currentActiveAccountID()
        rebuildRows()
        startTimer()
        Task { await refreshAll() }
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
        rows = store.accounts.map { a in
            let st = stateByID[a.id]
            return AccountRow(id: a.id, label: a.label, plan: a.planType,
                              usage: st?.usage, error: st?.error, isLoading: st?.loading ?? false)
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
