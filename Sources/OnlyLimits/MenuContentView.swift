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

            if let upd = store.availableUpdate {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text(s.updateAvailable(upd.version)).font(.caption).bold()
                    Spacer(minLength: 6)
                    Button(s.updateDownload) { store.openUpdate() }
                        .buttonStyle(.borderless).font(.caption).bold()
                        .foregroundStyle(.white)
                    Button { store.skipUpdate() } label: { Image(systemName: "xmark") }
                        .buttonStyle(.borderless).font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .help(s.skipVersion)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor)
            }

            if store.rows.isEmpty {
                emptyState
            } else {
                // Plain VStack (not ScrollView): inside a self-sizing MenuBarExtra
                // window a ScrollView collapses to zero height and hides the rows.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(store.rows) { row in
                        AccountRowView(row: row,
                                       isActive: row.id == store.activeAccountID,
                                       isAnchoring: store.anchoringIDs.contains(row.id),
                                       isSliding: store.slidingIDs.contains(row.id),
                                       canAnchor: store.canAnchor,
                                       strings: s,
                                       onRemove: { store.remove(id: row.id) },
                                       onAnchor: { store.anchor(id: row.id) })
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

            if store.showMemory, let mem = store.memory {
                MemoryRowView(mem: mem, strings: s)
                Divider()
            }
            if store.showDisk, let disk = store.disk {
                DiskRowView(disk: disk, strings: s)
                Divider()
            }

            footer
        }
        .frame(width: 340)
        .onAppear { store.panelDidAppear() }
        .onDisappear { store.panelDidDisappear() }
    }

    /// "m:ss" remaining until the given date.
    private func countdown(to date: Date, now: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSince(now)))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    private var appIcon: NSImage {
        NSApplication.shared.applicationIconImage
            ?? NSImage(named: NSImage.applicationIconName)
            ?? NSImage()
    }

    private var header: some View {
        HStack {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 18, height: 18)
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

                // Independent of the mode above: these add "how much is taken"
                // to whatever those modes already put in the menu bar.
                Toggle(isOn: $store.memoryInMenuBar) {
                    Image(systemName: "memorychip")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help(s.memoryMenuBarHelp)

                Toggle(isOn: $store.diskInMenuBar) {
                    Image(systemName: "internaldrive")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help(s.diskMenuBarHelp)
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
                        SettingsPopover(strings: s,
                                        language: $store.language,
                                        sortMode: $store.sortMode,
                                        autoAnchor: $store.autoAnchor,
                                        launchAtLogin: Binding(get: { store.launchAtLogin },
                                                               set: { store.setLaunchAtLogin($0) }),
                                        showMemory: $store.showMemory,
                                        showDisk: $store.showDisk,
                                        canAnchor: store.canAnchor,
                                        version: UpdateChecker.currentVersion(),
                                        updateState: store.updateCheckState,
                                        onDismissLanguage: { showLanguage = false },
                                        onCheckUpdate: { store.checkForUpdate(manual: true) },
                                        onOpen: { store.resetUpdateStatus() })
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

struct SettingsPopover: View {
    let strings: Strings
    @Binding var language: Language
    @Binding var sortMode: SortMode
    @Binding var autoAnchor: Bool
    @Binding var launchAtLogin: Bool
    @Binding var showMemory: Bool
    @Binding var showDisk: Bool
    let canAnchor: Bool
    let version: String
    let updateState: UpdateCheckState
    var onDismissLanguage: () -> Void
    var onCheckUpdate: () -> Void
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(strings.languageTitle.uppercased())
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 12).padding(.top, 10)
            ForEach(Language.allCases) { lang in
                Button {
                    language = lang
                    onDismissLanguage()
                } label: {
                    HStack {
                        Text(lang.displayName)
                        Spacer()
                        if lang == language {
                            Image(systemName: "checkmark").font(.caption).foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                    .padding(.horizontal, 12).padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }

            Divider().padding(.vertical, 3)

            HStack {
                Text(strings.sortTitle).font(.callout)
                Spacer()
                Picker("", selection: $sortMode) {
                    Text(strings.sortDefault).tag(SortMode.default)
                    Text(strings.sortReset).tag(SortMode.resetSoonest)
                    Text(strings.sortRemaining).tag(SortMode.remainingLeast)
                }
                .labelsHidden().pickerStyle(.menu).fixedSize()
            }
            .padding(.horizontal, 12)

            HStack {
                Text(strings.launchAtLoginLabel).font(.callout)
                Spacer()
                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
            }
            .padding(.horizontal, 12)

            Divider().padding(.vertical, 3)

            Text(strings.panelSectionTitle.uppercased())
                .font(.caption2).foregroundStyle(.secondary)
                .padding(.horizontal, 12)
            HStack {
                Label(strings.memoryTitle, systemImage: "memorychip").font(.callout)
                Spacer()
                Toggle("", isOn: $showMemory)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                    .help(strings.memoryPanelLabel)
            }
            .padding(.horizontal, 12)
            HStack {
                Label(strings.diskTitle, systemImage: "internaldrive").font(.callout)
                Spacer()
                Toggle("", isOn: $showDisk)
                    .toggleStyle(.switch).controlSize(.small).labelsHidden()
                    .help(strings.memoryPanelLabel)
            }
            .padding(.horizontal, 12)

            Divider().padding(.vertical, 3)

            if canAnchor {
                HStack {
                    Text(strings.autoAnchorLabel).font(.callout)
                    Spacer()
                    Toggle("", isOn: $autoAnchor)
                        .toggleStyle(.switch).controlSize(.small).labelsHidden()
                }
                .padding(.horizontal, 12)
                Text(strings.anchorHelp)
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12).padding(.bottom, 10)
            } else {
                Text(strings.codexNotFound)
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12).padding(.bottom, 10)
            }

            Divider().padding(.vertical, 3)
            HStack {
                Text("OnlyLimits \(version)").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                switch updateState {
                case .checking:
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text(strings.checking).font(.caption).foregroundStyle(.secondary)
                    }
                case .upToDate:
                    Text(strings.upToDate).font(.caption).foregroundStyle(.secondary)
                case .idle:
                    Button(strings.checkUpdates) { onCheckUpdate() }
                        .buttonStyle(.link).font(.caption)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 10)
        }
        .frame(width: 250)
        .onAppear { onOpen() }
    }
}

// MARK: - Account row

struct AccountRowView: View {
    let row: AccountRow
    let isActive: Bool
    let isAnchoring: Bool
    let isSliding: Bool
    let canAnchor: Bool
    let strings: Strings
    let onRemove: () -> Void
    let onAnchor: () -> Void

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
                if isAnchoring {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text(strings.anchoring).font(.caption2).foregroundStyle(.secondary)
                    }
                } else if canAnchor && isSliding {
                    HStack(spacing: 8) {
                        Label(strings.unanchoredHint, systemImage: "clock.badge.exclamationmark")
                            .font(.caption2).foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 6)
                        Button(strings.anchorButton, action: onAnchor)
                            .buttonStyle(.bordered).controlSize(.small)
                            .help(strings.anchorHelp)
                    }
                }
            } else {
                Text(strings.loading).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Mac memory
// Same bar idiom as the limits, but it shows what's TAKEN (that's how everyone
// reads RAM). Colored by macOS memory pressure, not by the raw percentage —
// a Mac sitting at 90% with cache and compressed pages is perfectly healthy.

struct MemoryRowView: View {
    let mem: MemorySnapshot
    let strings: Strings

    private var usedPercent: Double { mem.usedPercent }
    private var color: Color { UsageColor.forRemaining(mem.pressure.paletteRemaining) }

    private var pressureText: String {
        switch mem.pressure {
        case .normal: return strings.memoryPressureNormal
        case .warning: return strings.memoryPressureWarning
        case .critical: return strings.memoryPressureCritical
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "memorychip").font(.caption).foregroundStyle(.secondary)
                Text(strings.memoryTitle).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(strings.gb(mem.used)) \(strings.memUnit)")
                    .font(.caption).monospacedDigit().bold().foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: usedPercent / 100 * geo.size.width)
                }
            }
            .frame(height: 6)
            HStack(spacing: 6) {
                Text(strings.ofTotal("\(strings.gb(mem.total)) \(strings.memUnit)"))
                    .font(.caption2).foregroundStyle(.tertiary)
                if mem.swapUsed > 0 {
                    Text("·").font(.caption2).foregroundStyle(.tertiary)
                    Text(strings.memorySwap(strings.gb(mem.swapUsed)))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 5, height: 5)
                    Text(pressureText).font(.caption2).foregroundStyle(.tertiary)
                }
                .help(strings.memoryPressureHelp)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .help(strings.memoryBreakdown(app: strings.gb(mem.app),
                                      wired: strings.gb(mem.wired),
                                      compressed: strings.gb(mem.compressed),
                                      cached: strings.gb(mem.cached)))
    }
}

// MARK: - Mac storage
// Same shape as the memory row. Colored by how much room is LEFT, though:
// a 75%-full disk is fine, one with a few gigabytes left is not.

struct DiskRowView: View {
    let disk: DiskSnapshot
    let strings: Strings

    private var color: Color { UsageColor.forRemaining(disk.paletteRemaining) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "internaldrive").font(.caption).foregroundStyle(.secondary)
                Text(strings.diskTitle).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(strings.disk(disk.used))
                    .font(.caption).monospacedDigit().bold().foregroundStyle(.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: disk.usedPercent / 100 * geo.size.width)
                }
            }
            .frame(height: 6)
            HStack(spacing: 6) {
                Text(strings.ofTotal(strings.disk(disk.total)))
                    .font(.caption2).foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Circle().fill(color).frame(width: 5, height: 5)
                    Text(strings.diskFree(strings.disk(disk.available)))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .help(strings.diskBreakdown(name: disk.volumeName,
                                    used: strings.disk(disk.used),
                                    free: strings.disk(disk.available),
                                    total: strings.disk(disk.total)))
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
