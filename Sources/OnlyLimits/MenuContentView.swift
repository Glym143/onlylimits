import SwiftUI
import AppKit

/// Muted, non-garish status colors (used for the remaining bars).
enum UsageColor {
    static func forRemaining(_ remaining: Double) -> Color {
        let c = Palette.rgb(remaining)
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    @State private var showLanguage = false

    private var s: Strings { store.s }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if store.rows.isEmpty {
                emptyState
            } else {
                // Plain VStack (not ScrollView): inside a self-sizing MenuBarExtra
                // window a ScrollView collapses to zero height and hides the rows.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.rows) { row in
                        AccountRowView(row: row,
                                       isActive: row.id == store.activeAccountID,
                                       strings: s,
                                       onRemove: { store.remove(id: row.id) })
                        if row.id != store.rows.last?.id { Divider().padding(.leading, 12) }
                    }
                }
            }

            if let msg = store.lastMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14).padding(.top, 8)
                    .lineLimit(2)
            }

            Divider().padding(.top, 8)
            footer
        }
        .frame(width: 340)
    }

    /// "m:ss" remaining until the given date.
    private func countdown(to date: Date, now: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private var header: some View {
        HStack {
            Image(systemName: "gauge.medium").foregroundStyle(.tint)
            Text(s.appTitle).font(.headline)
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            } else {
                if let next = store.nextRefreshAt {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        Text(countdown(to: next, now: ctx.date))
                            .font(.caption2).monospacedDigit().foregroundStyle(.tertiary)
                    }
                    .help(s.untilAutoRefresh)
                }
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help(s.refreshNow)
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(s.noAccounts)
                .font(.subheadline).bold()
            Text(s.emptyHint)
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18).padding(.vertical, 16)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(s.inMenuBar).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $store.menuMode) {
                    Image(systemName: "person.fill").tag(MenuMode.active)
                        .help(s.modeActiveHelp)
                    Image(systemName: "chart.bar.fill").tag(MenuMode.all)
                        .help(s.modeAllBarsHelp)
                    Image(systemName: "list.bullet").tag(MenuMode.allNumbers)
                        .help(s.modeAllNumHelp)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .fixedSize()
            }

            if store.isLoggingIn {
                // Neutral (bordered) button while waiting — default spinner/text
                // read correctly in both themes; tap to cancel.
                Button { store.cancelLogin() } label: {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(s.waitingBrowser)
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help(s.cancelLoginHint)
            } else {
                Button { store.loginWithBrowser() } label: {
                    Label(s.addAccount, systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            HStack(spacing: 10) {
                Button(s.importCLI) { store.addCurrentAccount() }
                    .buttonStyle(.link).font(.caption)
                    .help(s.importCLIHelp)
                Spacer()
                if let ts = store.lastUpdated {
                    Text(s.updatedAt(ts.formatted(.dateTime.hour().minute())))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Button { showLanguage.toggle() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless)
                    .help(s.settings)
                    .popover(isPresented: $showLanguage, arrowEdge: .bottom) {
                        LanguagePicker(strings: s, selection: $store.language) { showLanguage = false }
                    }
                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help(s.quit)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - Language popover

struct LanguagePicker: View {
    let strings: Strings
    @Binding var selection: Language
    var onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(strings.languageTitle.uppercased())
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 2)
            ForEach(Language.allCases) { lang in
                Button {
                    selection = lang
                    onPick()
                } label: {
                    HStack {
                        Text(lang.displayName)
                        Spacer()
                        if lang == selection {
                            Image(systemName: "checkmark").font(.caption).foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 10).padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 150)
        .padding(.bottom, 6)
    }
}

// MARK: - Account row

struct AccountRowView: View {
    let row: AccountRow
    let isActive: Bool
    let strings: Strings
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(row.label).font(.subheadline).bold().lineLimit(1)
                if let plan = row.plan {
                    Text(plan.capitalized)
                        .font(.caption2).bold()
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                if isActive {
                    Text(strings.activeBadge)
                        .font(.caption2).bold()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(UsageColor.forRemaining(100), in: Capsule())
                        .help(strings.activeBadgeHelp)
                }
                Spacer()
                if row.isLoading && row.usage == nil {
                    ProgressView().controlSize(.mini)
                }
                Button(action: onRemove) { Image(systemName: "trash").font(.caption) }
                    .buttonStyle(.borderless).foregroundStyle(.secondary)
                    .help(strings.removeAccountHelp)
            }

            if let error = row.error, row.usage == nil {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let usage = row.usage {
                if usage.windows.isEmpty {
                    Text(strings.noWindow).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(usage.windows) { w in RemainingBar(window: w, strings: strings) }
                if usage.creditsUnlimited {
                    Text(strings.creditsUnlimited).font(.caption2).foregroundStyle(.secondary)
                } else if let bal = usage.creditsBalance, (Double(bal) ?? 0) > 0 {
                    Text(strings.creditsBalance(bal)).font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text(strings.loading).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - One window bar showing how much is LEFT
// 0% = nothing left (red, empty bar) · 100% = full limit available (green, full bar)

struct RemainingBar: View {
    let window: UsageWindow
    let strings: Strings

    private var remaining: Double { max(0, min(100, 100 - window.usedPercent)) }
    private var color: Color { UsageColor.forRemaining(remaining) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(strings.windowTitle(window.windowSeconds)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(strings.remaining(Int(remaining.rounded())))
                    .font(.caption).monospacedDigit().bold().foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: remaining / 100 * geo.size.width)
                }
            }
            .frame(height: 6)
            if let reset = window.resetsAt {
                Text(strings.resetText(reset)).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}
