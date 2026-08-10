import Foundation

enum Language: String, CaseIterable, Identifiable {
    case ru, en, ja, zh
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ru: return "Русский"
        case .en: return "English"
        case .ja: return "日本語"
        case .zh: return "中文"
        }
    }

    var localeID: String {
        switch self {
        case .ru: return "ru_RU"
        case .en: return "en_US"
        case .ja: return "ja_JP"
        case .zh: return "zh_CN"
        }
    }
}

/// All user-facing strings, resolved for one language. Value type — cheap to
/// pass into subviews.
struct Strings {
    let lang: Language

    private func pick<T>(_ ru: T, _ en: T, _ ja: T, _ zh: T) -> T {
        switch lang { case .ru: return ru; case .en: return en; case .ja: return ja; case .zh: return zh }
    }

    // Header — brand, same in every language.
    var appTitle: String { "OnlyLimits | Codex" }
    var refreshNow: String { pick("Обновить сейчас", "Refresh now", "今すぐ更新", "立即刷新") }
    var untilAutoRefresh: String { pick("До автообновления", "Until auto-refresh", "自動更新まで", "距自动刷新") }

    // Empty state
    var noAccounts: String { pick("Пока нет аккаунтов", "No accounts yet", "アカウントがありません", "暂无账户") }
    var emptyHint: String {
        pick("Нажми «Добавить аккаунт» ниже и войди в ChatGPT. Повтори для каждого - все будут видны здесь сразу.",
             "Click “Add account” below and sign in to ChatGPT. Repeat for each one - they'll all show here at once.",
             "下の「アカウントを追加」を押して ChatGPT にサインインします。アカウントごとに繰り返すと、すべてここに表示されます。",
             "点击下方的「添加账户」并登录 ChatGPT。为每个账户重复操作，它们会同时显示在这里。")
    }

    // Menu-bar mode
    var inMenuBar: String { pick("В строке меню", "In menu bar", "メニューバー", "菜单栏") }
    var modeActiveHelp: String { pick("Активный аккаунт: полоска + %", "Active account: bar + %", "アクティブなアカウント：バー + %", "当前账户：条形 + %") }
    var modeAllBarsHelp: String { pick("Все: только полоски", "All: bars only", "すべて：バーのみ", "全部：仅条形") }
    var modeAllNumHelp: String { pick("Все: полоски + проценты", "All: bars + percentages", "すべて：バー + パーセント", "全部：条形 + 百分比") }

    // Footer
    var addAccount: String { pick("Добавить аккаунт", "Add account", "アカウントを追加", "添加账户") }
    var waitingBrowser: String { pick("Ожидание браузера…", "Waiting for browser…", "ブラウザを待っています…", "等待浏览器…") }
    var cancelLoginHint: String { pick("Нажми, чтобы отменить", "Click to cancel", "クリックしてキャンセル", "点击取消") }
    var loginCancelled: String { pick("Отменено", "Cancelled", "キャンセルしました", "已取消") }

    // Anchoring the weekly window
    var anchorButton: String { pick("Застолбить", "Anchor", "アンカー", "锚定") }
    var anchoring: String { pick("Закрепляю…", "Anchoring…", "アンカー中…", "锚定中…") }
    var unanchoredHint: String {
        pick("Не начат - сброс уезжает на +7д",
             "Not started - reset keeps sliding +7d",
             "未開始 - リセットが +7日 ずれ続けます",
             "未开始 - 重置持续顺延 +7 天")
    }
    var anchorHelp: String {
        pick("Отправить одно крошечное сообщение, чтобы окно стартовало и сброс перестал уезжать",
             "Send one tiny message to start the window so its reset stops sliding forward",
             "小さなメッセージを1回送って枠を開始し、リセットのずれを止めます",
             "发送一条极小的消息以启动窗口，让重置不再顺延")
    }
    func anchored(_ label: String) -> String {
        pick("Застолблён \(label)", "Anchored \(label)", "アンカー完了：\(label)", "已锚定 \(label)")
    }
    var anchorFailed: String { pick("Не удалось застолбить", "Anchor failed", "アンカーに失敗", "锚定失败") }
    var autoAnchorLabel: String { pick("Авто-якорь при 100%", "Auto-anchor at 100%", "100%で自動アンカー", "100% 时自动锚定") }

    // Sorting
    var sortTitle: String { pick("Сортировка", "Sort", "並び替え", "排序") }
    var sortDefault: String { pick("Как добавлены", "As added", "追加順", "添加顺序") }
    var sortReset: String { pick("Скоро сброс", "Soonest reset", "リセットが近い順", "最快重置") }
    var sortRemaining: String { pick("Меньше осталось", "Least remaining", "残りが少ない順", "剩余最少") }
    var codexNotFound: String {
        pick("Codex CLI не найден - для якоря нужен установленный ChatGPT/codex",
             "Codex CLI not found - anchoring needs the ChatGPT app or codex installed",
             "Codex CLI が見つかりません - アンカーには ChatGPT アプリか codex が必要です",
             "未找到 Codex CLI - 锚定需要安装 ChatGPT 应用或 codex")
    }
    var importCLI: String { pick("Импорт из CLI", "Import from CLI", "CLI からインポート", "从 CLI 导入") }
    var importCLIHelp: String {
        pick("Взять аккаунт, в который сейчас залогинен Codex CLI",
             "Use the account the Codex CLI is currently logged into",
             "現在 Codex CLI がログインしているアカウントを使用します",
             "使用 Codex CLI 当前登录的账户")
    }
    var quit: String { pick("Выход", "Quit", "終了", "退出") }
    var settings: String { pick("Настройки", "Settings", "設定", "设置") }
    var languageTitle: String { pick("Язык", "Language", "言語", "语言") }
    func updatedAt(_ time: String) -> String {
        pick("обновлено \(time)", "updated \(time)", "更新 \(time)", "更新于 \(time)")
    }

    // Account row
    var activeBadge: String { pick("активный", "active", "アクティブ", "当前") }
    var activeBadgeHelp: String {
        pick("Этот аккаунт сейчас используется в Codex CLI",
             "This account is currently used by the Codex CLI",
             "このアカウントは現在 Codex CLI で使用されています",
             "此账户当前正被 Codex CLI 使用")
    }
    var removeAccountHelp: String { pick("Убрать этот аккаунт", "Remove this account", "このアカウントを削除", "移除此账户") }
    var noWindow: String { pick("Нет активного окна лимита", "No active limit window", "アクティブな制限枠がありません", "无活动限额窗口") }
    var creditsUnlimited: String { pick("Кредиты: безлимит", "Credits: unlimited", "クレジット：無制限", "额度：无限") }
    func creditsBalance(_ x: String) -> String {
        pick("Баланс кредитов: \(x)", "Credits balance: \(x)", "クレジット残高：\(x)", "额度余额：\(x)")
    }
    var loading: String { pick("Загрузка…", "Loading…", "読み込み中…", "加载中…") }
    func remaining(_ pct: Int) -> String {
        pick("\(pct)% осталось", "\(pct)% left", "残り\(pct)%", "剩余\(pct)%")
    }

    // Windows
    func windowTitle(_ seconds: Int?) -> String {
        guard let s = seconds else { return pick("Лимит", "Limit", "制限", "限额") }
        if within(s, 18_000) { return pick("5 часов", "5 hours", "5時間", "5小时") }
        if within(s, 604_800) { return pick("Неделя", "Weekly", "週間", "每周") }
        if s % 86_400 == 0 { let n = s / 86_400; return pick("\(n) дн", "\(n)d", "\(n)日", "\(n)天") }
        if s % 3_600 == 0 { let n = s / 3_600; return pick("\(n) ч", "\(n)h", "\(n)時間", "\(n)小时") }
        let n = max(1, s / 60); return pick("\(n) мин", "\(n)m", "\(n)分", "\(n)分")
    }

    func resetText(_ date: Date) -> String {
        let secs = Int(date.timeIntervalSinceNow)
        guard secs > 0 else { return pick("сброс сейчас…", "resetting…", "リセット中…", "正在重置…") }
        let d = secs / 86_400, h = (secs % 86_400) / 3600, m = (secs % 3600) / 60
        let (du, hu, mu) = pick(("д", "ч", "м"), ("d", "h", "m"), ("日", "時間", "分"), ("天", "小时", "分"))
        let join = (lang == .ja || lang == .zh) ? "" : " "
        let rel: String
        if d > 0 { rel = "\(d)\(du)\(join)\(h)\(hu)" }
        else if h > 0 { rel = "\(h)\(hu)\(join)\(m)\(mu)" }
        else { rel = "\(m)\(mu)" }
        let df = DateFormatter()
        df.locale = Locale(identifier: lang.localeID)
        df.dateFormat = "d MMM, HH:mm"
        let ds = df.string(from: date)
        return pick("сброс через \(rel) · \(ds)",
                    "resets in \(rel) · \(ds)",
                    "リセットまで \(rel) · \(ds)",
                    "\(rel)后重置 · \(ds)")
    }

    // Transient messages
    var openingBrowser: String {
        pick("Открываю браузер… войди и вернись сюда.",
             "Opening browser… sign in and come back.",
             "ブラウザを開いています…サインインして戻ってください。",
             "正在打开浏览器…登录后返回。")
    }
    func added(_ label: String) -> String { pick("Добавлен \(label)", "Added \(label)", "追加：\(label)", "已添加 \(label)") }
    func updated(_ label: String) -> String { pick("Обновлён \(label)", "Updated \(label)", "更新：\(label)", "已更新 \(label)") }

    private func within(_ v: Int, _ t: Int) -> Bool { abs(v - t) <= t / 10 }
}
