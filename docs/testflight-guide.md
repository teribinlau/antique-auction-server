# 把「古董拍卖」发到 TestFlight 给真人测（0 基础图文步骤）

> 前提：一台 Mac + Xcode、一个已部署好的 `wss://` 服务器、**Apple 开发者账号（$99/年）**。
> 服务器部署见 [`deploy-guide.md`](./deploy-guide.md)。

---

## 0 · 一次性准备
- **Apple 开发者账号**：[developer.apple.com/programs](https://developer.apple.com/programs) 注册，$99/年，审核约 1–2 天。
- 确认 App 能在模拟器正常跑（你已做到 ✅）。
- **App 图标**：TestFlight 上传要求一张 **1024×1024、不透明、无圆角** 的图标，缺了会被打回（见末尾「App 图标」）。

## 1 · 设置 Bundle ID 与签名（Xcode）
1. 选中工程 → TARGETS：`AntiqueAuction` → **Signing & Capabilities**。
2. 勾上 **Automatically manage signing**。
3. **Team** 选你的开发者账号（账号审核通过后才会出现在下拉里）。
4. **Bundle Identifier** 改成你自己的反向域名、**全网唯一**，例如 `com.aijuil.antiqueauction`（定了以后别随便改）。

## 2 · 在 App Store Connect 建 App 记录
1. 打开 [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **我的 App → ＋ → 新建 App**。
2. 平台选 iOS；名称（展示名，可中文，如「古董拍卖」）；主要语言；**Bundle ID** 选第 1 步那个；SKU 填个唯一串（如 `antiqueauction001`）。

## 3 · 版本号 + 选归档目标
1. Xcode 顶部的运行目标改成 **Any iOS Device (arm64)**——**不是**模拟器，否则 Archive 是灰的。
2. 工程 → General → 填 **Version**（如 `1.0`）和 **Build**（如 `1`）。以后每次上传，Build 号要 **+1**。

## 4 · Archive 并上传
1. 菜单 **Product → Archive**（等几分钟编译打包）。
2. 弹出 Organizer 窗口 → **Distribute App** → **App Store Connect** → **Upload** → 一路 Next（自动签名）→ Upload。
3. 几分钟后，App Store Connect 里会出现这个 Build（状态从「处理中」变为可用）。

## 5 · TestFlight 加测试者
1. App Store Connect → 你的 App → **TestFlight** 标签。
2. 第一次会问 **出口合规（加密）**：本 App 只用标准 HTTPS / `wss`，一般选 **「没有使用非豁免加密」/ No**。
3. 两种测试：
   - **内部测试**：最多 100 人，需是你 App Store Connect 团队成员，**无需审核**，最快。
   - **外部测试**：最多 1 万人，可生成**公开链接**发给任何人；首次需一次**简短 Beta 审核**（通常 1 天内过）。
4. 测试者：手机装苹果的 **TestFlight** App → 点你的邀请链接 → 安装「古董拍卖」开玩。

## 6 · 本项目专属注意
- **服务器地址**：发布前会把 `Networking/Endpoints.swift` 的 `defaultURLString` 设成你的 `wss://…`，测试者打开即连、**无需手填**（要换服务器在连接页改即可）。
- **`wss://` 不需要 ATS 例外**：生产走 TLS，审核无障碍。`NSAllowsLocalNetworking` 只是本地 `ws://` 调试用，留着也不影响上架。
- **Render 免费档会休眠**：15 分钟没人连就睡，测试者首次连接要等约 1 分钟冷启动。约人同测前，自己先连一下把它「叫醒」；想常驻不睡，把 plan 升到 `starter`（~$7/月）。
- **卡图**：确保 `CardArt.xcassets` 已装进工程（你已完成）；没图的卡会走渐变兜底，不影响测。

## App 图标（上传前必做）
TestFlight 要求 `Assets.xcassets → AppIcon` 里有一张 **1024×1024、不透明（无 alpha）、无自带圆角** 的图标，缺了上传会失败。
- Xcode 新工程的 AppIcon 默认是「单尺寸」格，把一张 1024 PNG 拖进去即可。
- 没有现成图？可以用我们这套 Gemini 出图，生成一张古董拍卖主题的方形图标。

## 常见报错速查
| 现象 | 多半原因 |
|---|---|
| **Archive 菜单灰着点不动** | 运行目标选了模拟器，要选 **Any iOS Device** |
| **上传报「缺少 App 图标」** | 补 1024×1024 不透明图标 |
| **No Team / 无法签名** | 开发者账号还没审核通过，或没在 Signing 里选 Team |
| **Bundle ID 已被占用** | 换一个更独特的反向域名 |
| **测试者进去连不上服务器** | 服务器在睡（冷启动等 1 分钟）/ 地址不对 / 服务器没部署 |
