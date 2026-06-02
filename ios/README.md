# 古董拍卖 · iOS 客户端（SwiftUI）

原生 SwiftUI 客户端，连接本仓库的多人「古董拍卖」WebSocket 服务器（`server.js` + `game_logic.js`）。

- **最低系统**：iOS 16
- **生命周期**：SwiftUI App（`@main struct AntiqueAuctionApp`）
- **网络**：仅用系统内置 `URLSessionWebSocketTask`，**无任何第三方依赖**
- **状态**：`ObservableObject` + `@Published` + `@MainActor`（`GameClient`）

> 本目录只包含 Swift 源码与本说明。**不含 `.xcodeproj`**（手写工程文件极易出错）。请按下方步骤在 Xcode 里新建工程并把源码拖进去。

---

## 一、在 Xcode 新建工程

1. 打开 Xcode → **File → New → Project… → iOS → App**。
2. 填写：
   - Product Name：`AntiqueAuction`
   - Interface：**SwiftUI**
   - Language：**Swift**
   - 取消勾选 Core Data / Tests（可选）。
3. 选择保存位置（**不要**直接覆盖本 `ios/` 目录，单独建一处即可）。
4. 建好后，Xcode 会自带一个 `AntiqueAuctionApp.swift` 和 `ContentView.swift`——**删除这两个自带文件**（移到废纸篓），下面会用本目录提供的源码替代。
5. 选中工程 target → **General → Minimum Deployments → iOS 16.0**。

## 二、把源码导入工程

把 `ios/AntiqueAuction/` 下的源码按分组拖入 Xcode（拖入时勾选 **Copy items if needed** 与你的 App target）。建议保持以下分组结构（与磁盘目录一致）：

```
AntiqueAuction/
  App/
    AntiqueAuctionApp.swift      # @main 入口
    AppRootView.swift            # 顶层路由 + 重连 + 横幅覆盖层
  Networking/
    Endpoints.swift              # serverURL（部署后改这里）
    GameClient.swift             # 网络层 + 状态中枢（核心）
  Models/
    Enums.swift                  # ConnState / Phase / Denomination
    Card.swift
    GameView.swift               # Money / MePlayer / Opponent / GameView(state)
    Room.swift                   # RoomSummary / JoinedRoom
    Deal.swift                   # DealTarget / DealResolved
    Score.swift
    ClientAction.swift           # 客户端→服务端 action（平铺 Encodable）
    GameEvent.swift              # 服务端→客户端 event（先解 event 再解 payload）
  Views/
    Lobby/
      ConnectNameView.swift
      LobbyView.swift
      RoomWaitingView.swift
    Game/
      GameContainerView.swift    # 按 phase 路由
      AuctionView.swift
      SnipeView.swift
      PrivateDealView.swift
      GameOverView.swift
  Components/
    BillPicker.swift             # 选钞器（截拍付款 / 私盘暗标）
    OpponentBills.swift          # 只读，仅显示张数（诈唬来源）
    CardView.swift
    BannerOverlay.swift
```

> 拖入「分组（带文件夹）」最省事：把 `App`、`Networking`、`Models`、`Views`、`Components` 五个文件夹整体拖进 Xcode 项目导航器即可。确保每个 `.swift` 的 **Target Membership** 勾上了你的 App target。

## 三、配置服务器地址

打开 `Networking/Endpoints.swift`，把 `serverURL` 改成你的实际地址：

```swift
// 生产（Railway 等，wss 加密，真机/模拟器都能直连）
static let serverURL = URL(string: "wss://你的应用.up.railway.app")!
```

- **真机 / TestFlight / App Store**：用 `wss://`（加密），无需任何 ATS 配置。
- **本地调试**：把上面那行换成下方注释里的本地地址（`server.js` 默认监听 3000）：
  ```swift
  static let serverURL = URL(string: "ws://localhost:3000")!
  ```
  本地用 `localhost` 时若用**模拟器**可直接连；用**真机**需把 `localhost` 换成你 Mac 的局域网 IP（如 `ws://192.168.1.20:3000`），并确保手机与电脑同网段。

### 本地 `ws://`（明文）需要 ATS 例外

iOS 的 App Transport Security 默认拦截明文连接。仅本地调试时，在工程的 **Info.plist** 加入：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

`NSAllowsLocalNetworking` 只放行 `localhost`、`*.local` 与局域网地址，**不影响 App Store 审核**，且不会放开任意明文域名。上线连 `wss://` 时这条可保留也可删除。

> Xcode 15+ 的工程默认没有可见的 `Info.plist` 文件。可在 target 的 **Info** 标签页里用 “+” 直接添加键，或新建一个 `Info.plist` 并在 **Build Settings → Info.plist File** 指向它。

## 四、运行

1. 选一个 iOS 16+ 的模拟器或真机。
2. 本地调试请先在仓库根目录启动服务器：
   ```bash
   npm install
   npm start        # 监听 ws://0.0.0.0:3000
   ```
3. 在 Xcode 点 **Run**。输入昵称 → 进入大厅 → 创建房间或输码加入 → 凑齐 ≥2 人 → 开始游戏。

---

## 五、数据流与架构

整条链路围绕 **`GameClient`（`@MainActor ObservableObject`）** 展开：

```
SwiftUI 视图 ──调用便利方法──▶ GameClient.send(ClientAction)
                                   │ encode 成扁平 JSON
                                   ▼
                         URLSessionWebSocketTask  ◀───────────┐
                                   │ 文本帧                    │
                                   ▼                           │
                  recursive receive() ──decode──▶ GameEvent    │
                                   │                           │
                                   ▼ reduce(event)             │
                  更新 @Published（state/phase/rooms/...）       │
                                   │                           │
                                   ▼ 自动触发                   │
                       SwiftUI 重新渲染（AppRootView 路由）       │
                                                               │
        某些事件（如 room_created）会在 reduce 里再次 send ───────┘
```

- **发送**：视图调用 `client.createRoom / joinRoom / startGame / startAuction / placeBid / passBid / snipe / startDeal / submitOffer / getDealTargets / requestState`。`ClientAction` 的自定义 `Encodable` 把 `action` 字符串与参数**平铺**在同一层 JSON（服务端 `const { action } = msg` 直接读同级字段）。
- **接收**：`receive()` 递归续收，每条消息 decode 成 `GameEvent`（先解 `event` 字符串，再解对应 payload；无法识别的归入 `.unknown`，绝不中断接收循环）。
- **归约**：`reduce(event)` 把异构事件写进各 `@Published`；`state_update` 是权威全量快照。
- **路由**：`AppRootView` 按 `connection → roomCode/myPlayerId → phase` 决定显示哪屏；`GameContainerView` 再按 `phase` 路由到拍卖 / 截拍 / 私盘 / 结束四个子视图。

### 已落实的五个协议易错点

1. **`create_room` 不入座**：`reduce` 收到 `room_created` 后**自动续发 `join_room{roomCode}`**，UI 无感；真正入座以 `joined_room`（含 `playerId`）为准。
2. **`opponents[].handCount` = 钞票总张数**（非古董数）：`OpponentBills` 只显示张数、不显示面值——这是诈唬的唯一信息来源。
3. **`deal_resolved` 两种形态**：`DealResolved` 把 `winnerId` 与 `tieForcedWinner` 都设为可选（`decodeIfPresent`），用 `effectiveWinnerId` / `wasTieFlip` 统一取值。
4. **`request_state` 仅游戏中有响应**：等待室阶段服务端不回，重连逻辑（`scenePhase == .active`）容忍「无响应＝还在等待室」，不报错。
5. **`playerId` = 入座下标 0..3**；`money`/`exposedMoney` 的 key 是**字符串面值**，集合固定 `["0","10","50","100","200","500"]`，`"0"` 是废钞（凑张数不值钱，用于诈唬）。`Money = [String:Int]`，逐个写 `CodingKeys`，**未用全局 keyDecodingStrategy**。

另外：**「轮到谁出价」不在 `state` 里**，只能靠 `bid_turn` 事件维护——`GameClient.currentBidderId` 专门记录它，并在回合切换 / 离开拍卖阶段时清空。

---

## 六、已知限制与可能需要微调的点（请在 Xcode 端留意）

- **已支持自动重连（保留座位）**：服务端在你入座 / 重连成功时下发 `reconnectToken`，并在游戏进行中掉线时**保留座位**（广播 `player_disconnected`），凭令牌可绑回原座位（广播 `player_reconnected`）。客户端机制：
  - **捕获并持久化令牌**：`joined_room` / `rejoined_room` 携带 `reconnectToken`，`GameClient` 把它存入内存并按 `roomCode` 写 `UserDefaults`（连同「最近房间码」），App 重启后仍可尝试原座位重连。
  - **重连时机**：`AppRootView` 监听 `scenePhase == .active` 且连接已断时，先 `connect()` 重建连接，再判断——若存有 `roomCode + reconnectToken` 则发 `rejoin_room` 绑回原座位（否则维持 `request_state` 兜底）。
  - **恢复渲染**：收到 `rejoined_room` 恢复 `myPlayerId` / `roomCode` 等身份信息，依赖服务端随后自动补发的 `state_update`（及未结束时的 `turn_changed`）重绘牌局；其他玩家掉线 / 重连通过横幅提示。
  - **失效与清理**：令牌无效（服务端回 `error`）时清除令牌并回退大厅；离开房间或 `game_over` 后清除已存的 `reconnectToken` 与房间码，避免下次误用。
  - **可选保活**：除服务器 30s 的协议级 PING（系统自动回 PONG）外，`GameClient` 另起一个轻量周期 `sendPing` 保活，失败即标记断开、交由上面的 `scenePhase` 重连兜底。
- **`URLSessionWebSocketTask` 无显式「已连接」回调**：`connect()` 在 `resume()` 后即把 `connection` 置为 `.connected` 并开始收发。若服务器地址错误 / 不可达，要等首次 `send`/`receive` 失败才会回落到 `.disconnected`（届时回到首屏）。如需更严谨，可在 `connect()` 后发一次 `URLSessionWebSocketTask.sendPing` 并据回调再切 `.connected`。
- **等待室名单维护**：玩家名单以 `joined_room`（自己入座时的全量名单）为基准，之后靠 `player_joined`（追加）/ `player_left`（移除）增量维护。服务端 `player_joined` 不带完整名单，故用 `playerCount` 做去重兜底；极端乱序下名单可能与服务端略有偏差，但一旦开局，`state_update` 会给出权威玩家信息。
- **出价金额无上限校验**：`AuctionView` 的出价 Stepper 不校验「是否真付得起」——竞拍出价本就可以虚高（诈唬），真正的支付校验发生在 `SNIPE` 阶段（截拍付款 / 出价者自动付款），付不起由服务端发 `payment_failed`（横幅会展示曝光的钞票）。这是规则使然，非 bug。
- **横幅自动 4 秒消失**：`BannerOverlay` 用 `DispatchQueue.main.asyncAfter` 做自动消除，多条提示快速到来时只保留最新一条。如需要消息队列可自行扩展。
- **`@AppStorage("playerName")`**：昵称存在 UserDefaults，跨启动保留。换昵称在首屏修改即可。
- **本项目无 `.xcodeproj`**：源码新增/重命名后，记得在 Xcode 里同步添加文件并确认 Target Membership，否则会报「找不到类型」。

---

## 七、与服务端协议的对应关系（速查）

| 客户端方法 (`GameClient`) | 发出的 action | 触发的主要 event |
|---|---|---|
| `listRooms()` | `list_rooms` | `room_list` |
| `createRoom(...)` | `create_room` → 自动 `join_room` | `room_created` → `joined_room` |
| `joinRoom(...)` | `join_room` | `joined_room` / `error` |
| `startGame()` | `start_game` | `game_started` → `turn_changed` → `state_update` |
| `startAuction()` | `start_auction` | `auction_started`(+`silver_bonus`) → `bid_turn` |
| `placeBid(_:)` / `passBid()` | `place_bid` / `pass_bid` | `bid_placed`/`bid_passed` → `bid_turn` 或 `snipe_prompt`/`no_bids` |
| `snipe(doSnipe:paid:)` | `action_snipe` | `snipe_success`/`snipe_declined`/`payment_failed` |
| `startDeal(targetId:setId:)` | `start_private_deal` | `private_deal_started` |
| `submitOffer(paid:)` | `submit_deal_offer` | `deal_offer_submitted` → `deal_tie` 或 `deal_resolved` |
| `getDealTargets()` | `get_deal_targets` | `deal_targets` |
| `requestState()` | `request_state` | `state_update`(+`turn_changed`)，**仅游戏中** |

协议权威定义见仓库根目录 `PROTOCOL.md`。
