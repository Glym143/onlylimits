<div align="center">

[English](README.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · **中文**

<img src="icon/icon_1024.png" alt="OnlyLimits" width="120">

# OnlyLimits

**在 macOS 菜单栏中，一次性查看你所有 Codex 账户的用量额度。**

只做一件事，并把它做好。原生、小巧、零后台负载。

**[⬇ 下载 OnlyLimits 1.2 (.dmg)](https://github.com/Glym143/onlylimits/releases/latest)**

![macOS](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-0A84FF)
![Dependencies](https://img.shields.io/badge/dependencies-none-2ecc71)
![Binary](https://img.shields.io/badge/binary-940%20KB-2ecc71)
![License](https://img.shields.io/badge/license-MIT-green)

<br>

<img src="docs/panel.png" alt="OnlyLimits - 在 macOS 菜单栏中一次性查看每个 Codex 账户的剩余额度" width="440">

</div>

---

> _我为自己做了这款应用，因为我实在找不到一个没有一大堆多余功能的替代品。我只想看看自己还剩多少额度，而不想给我的 Mac 塞满我根本用不上的累赘。_

## 这是什么

一款专注的 macOS **菜单栏应用**，用来显示你的 **Codex（ChatGPT）用量额度还剩多少**-而且是**你拥有的每个账户，同时显示**。无需切换账户，没有仪表盘，也不用点开层层菜单去找账户。瞄一眼菜单栏，看看还剩多少，然后继续干活。

它只做一件事，而且在做这件事的时候绝不碍你的事。

## 为什么又要做一个用量追踪器？

大多数追踪器读取的是本地的 Codex CLI，而它一次只登录**一个**账户-所以它们永远只能显示那一个。切换器只显示当前活跃的一个账户，逼你来回轮换。**OnlyLimits 会为每个账户保留其各自的凭据，并独立轮询它们**，因此你所有的账户都能*同时*可见-而这恰恰是出人意料地难找的功能。

而且它天生就是要融入系统、隐于无形的:一个 **940 KB** 的二进制文件、**没有任何外部依赖**、**空闲时 CPU 占用约为 0%**（只在每隔几分钟刷新时才唤醒）。

## 功能特性

| | |
|---|---|
| 🧮 **所有账户一览无余** | 你添加的每个 Codex 账户都会被独立轮询并一并展示-剩余百分比、重置时间，逐个账户呈现。 |
| 🔐 **使用 ChatGPT 登录** | 通过官方浏览器 OAuth 流程（PKCE）直接在应用内添加账户。无需折腾 `codex login`，也不用粘贴令牌。想加多少个就加多少个。 |
| 📊 **自定义菜单栏迷你图表** | 一幅手绘的状态图形-就像系统监视器一样-而不是一串挤在一起的数字。三种显示模式（见下文）。 |
| 🟢 **显示剩余，而非已用** | 条形显示的是**还剩多少**:满格且为绿色 = 富余充足，空格且为红色 = 快用完了。这才是你真正关心的数字。 |
| ⏱️ **实时刷新倒计时** | 精确看到距离下次自动更新还有多久;一键即可立即刷新。 |
| 🧠 **还有 Mac 内存** | 已用内存与用量限额并排显示 - 菜单栏是芯片图标 + **已用 GB**,面板里是条形图,附总容量、交换空间以及 macOS 的**内存压力**（绿 / 黄 / 红）。 |
| 💽 **…以及磁盘空间** | 启动卷同样如此 - 菜单栏是磁盘图标 + **已占用容量**,面板里是条形图,附总容量与剩余空间。颜色按*剩余*空间判断,只有磁盘真的快满时才会报警。 |
| 🌍 **4 种语言** | Русский · English · 日本語 · 中文 - 从齿轮菜单中即时切换。 |
| 🪶 **轻若鸿毛** | 原生 SwiftUI、零依赖,没有 Electron/Node/Python。CPU 占用微乎其微,二进制文件极小。 |
| 🔒 **本地且私密** | 只与 OpenAI 的端点通信。凭据绝不离开你的 Mac;没有分析统计、没有服务器、没有遥测。 |

### 三种菜单栏模式

从面板底部的分段切换器中选择:

| 图标 | 模式 | 菜单栏显示 |
|:---:|---|---|
| 👤 | **活跃** | Codex CLI 当前登录的那个账户-一个仪表 + 其百分比 |
| 📊 | **全部（条形）** | 每个账户一个仪表,紧凑排列,不带数字 |
| ☰ | **全部 + 数字** | 每个账户一个仪表,每个旁边标注其剩余百分比 |

这三种模式旁边还有 🧠 和 💽 两个按钮:它们分别把**已用内存(或已用磁盘空间)**加到当前模式已显示的内容旁-任意模式下均可,一键开关。面板中的内存行与存储行则在 ⚙️ 中单独开关。

菜单栏图形是一张**模板图像（template image）**,因此 macOS 会自动为其上色-在深色菜单栏上呈清晰的白色,在浅色菜单栏上呈黑色。而在面板内部,条形保持**彩色**（柔和的绿色 → 琥珀色 → 红色）,这样状态一眼可辨,又不至于刺眼。

## 安装

### 环境要求
- macOS 14 (Sonoma) 或更高版本
- Xcode 16+ / Swift 6 工具链（用于从源码构建）
- 已安装并至少登录过一次的 [Codex CLI](https://github.com/openai/codex)（用于初始化你的第一个账户;后续账户在应用内添加）

### 从源码构建
```bash
git clone <your-repo-url> codex-usage-bar
cd codex-usage-bar
./build.sh                 # → OnlyLimits.app (ad-hoc signed, dock-less)
open OnlyLimits.app
```

像安装任何应用一样安装它,并启用开机自启:
```bash
cp -R OnlyLimits.app /Applications/
# System Settings → General → Login Items → add OnlyLimits
```

## 使用方法

1. **启动它。** 首次运行时,它会导入 Codex CLI 当前登录的那个账户。
2. **添加更多账户。** 点击 **Add account** → 在浏览器中使用 ChatGPT 登录 → 完成。为每个账户重复此操作。
   - 登录会强制重新登录（`prompt=login`）,因此你每次都可以添加一个*不同*的账户。
   - 登录中途改主意了?按钮会变成取消-点一下就恢复原样。
3. **查看你的额度。** 每个账户都会将其时间窗口（例如 *Weekly*）显示为一个**剩余**条形,外加重置倒计时。
4. **选择菜单栏模式**（👤 / 📊 / ☰）和**语言**（⚙️）-两者都会在多次启动之间被记住。
5. **移除账户**,点击其所在行上的 🗑 即可。

## 工作原理

- **账户**是一次 Codex 登录的快照:`access_token` + `refresh_token` + `account_id`。为每个账户保留其各自的**刷新令牌（refresh token）**,正是实现独立、同时轮询的关键-无论 CLI 当前处于哪个账户。
- **用量**数据来自 `GET https://chatgpt.com/backend-api/wham/usage`（`Authorization: Bearer …`、`ChatGPT-Account-Id: …`）。响应中携带 `email`、`plan_type` 以及速率限制窗口信息,因此每个账户都能自我标注。
- **令牌**通过 `POST https://auth.openai.com/oauth/token` 刷新-在临近过期时主动刷新,并在遇到 401 时被动刷新并重试一次。
- 各时间窗口按其**实际时长**标注,因此应用始终反映真实情况（Codex 目前暴露的是一个每周窗口;如果返回的是 5 小时窗口,它也会正确显示）。
- **磁盘空间**取自 `/` 卷的资源值-总容量与 “available for important usage”,即可用空间*加上* macOS 可清除的部分,正是 Finder 显示的那个数字。与内存的二进制 GiB 不同,磁盘按 Finder 的十进制 GB/TB 计算。每 30 秒采样一次。
- **Mac 内存**直接从内核读取（`host_statistics64` + `sysctl`,不调用任何外部命令）:*已用 = 应用 + 联动 + 已压缩*,与「活动监视器」的算法完全一致（缓存文件不计入“已用”）。颜色取自内核报告的**内存压力**等级,而非单纯的百分比-一台靠缓存和压缩页面占到 90% 的 Mac 完全健康。每 2-3 秒采样一次,只有可见数字发生变化时才重绘。

## 性能与占用

在构建好的应用上于空闲状态测得:

| 指标 | 数值 |
|---|---|
| 二进制大小 | **940 KB** |
| 应用包 | **~1 MB** |
| 外部依赖 | **0** |
| 空闲时 CPU | **~0%**（仅在刷新时唤醒,每隔几分钟一次） |
| 运行时 | 原生 SwiftUI / AppKit - 没有 Electron、Node 或 Python |
| Dock 图标 | 无（`LSUIElement`）- 纯粹存在于菜单栏中 |

## 隐私与安全

- **只**与 `chatgpt.com` 和 `auth.openai.com` 通信。没有任何第三方服务器、分析统计或遥测。
- 凭据以本地方式存储于 `~/Library/Application Support/OnlyLimits/accounts.json`,权限为 `0600`-与你机器上 `~/.codex/auth.json` 中已有的机密属于同一类别。
- 不会向任何地方上传任何东西。一切都在你的 Mac 上运行。
- _未来的安全加固:_ 将令牌字段迁移至 Keychain。

## 项目结构

```
Sources/OnlyLimits/
├── OnlyLimitsApp.swift    # @main - MenuBarExtra + status-bar image
├── MenuContentView.swift     # the panel UI (rows, bars, modes, countdown, language)
├── StatusBarImage.swift      # hand-drawn menu-bar mini bar chart + color palette
├── UsageStore.swift          # polling, timer, modes, orchestration
├── CodexLogin.swift          # Sign in with ChatGPT (browser OAuth, PKCE)
├── OAuthCallbackServer.swift # localhost callback listener
├── PKCE.swift                # PKCE codes
├── CodexClient.swift         # usage + token-refresh requests
├── AccountStore.swift        # persistence
├── AuthImport.swift          # read ~/.codex/auth.json, detect active account
├── Models.swift              # API response + normalized model
├── MemoryMonitor.swift       # Mac RAM sampling (mach + sysctl) + pressure
├── DiskMonitor.swift         # startup-volume capacity (Finder's numbers)
└── Localization.swift        # ru / en / ja / zh strings
```

## 免责声明

这是一款**非官方**的独立工具。它与 OpenAI 没有任何关联,未获其认可,也不受其支持。它使用与官方 Codex CLI 相同的公开 OAuth 客户端和用量端点,并且旨在**供你个人使用你自己拥有的账户**。端点随时可能发生变化。

## 许可证

MIT - 参见 [LICENSE](LICENSE)。
