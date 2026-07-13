import Foundation
import Combine

/// 网络层 + 状态中枢。
///
/// 职责：
///  - 维护 `URLSessionWebSocketTask` 连接（仅用系统内置 API，无第三方）。
///  - `send(_:)` 把 `ClientAction` 编码成扁平 JSON 发出。
///  - 递归 `receive` 持续收消息，解码成 `GameEvent`，再 reduce 进各 `@Published`。
///  - 封装易错点 1：收到 `room_created` 后自动续发 `join_room`，UI 无感。
///  - 维护「轮到谁出价」`currentBidderId`（state 里没有，只能靠 `bid_turn` 事件）。
///
/// 全部标 `@MainActor`：所有状态修改都在主线程，SwiftUI 直接订阅。
@MainActor
final class GameClient: ObservableObject {

    // ── 对外发布的状态 ───────────────────────────────────────
    @Published private(set) var connection: ConnState = .disconnected
    @Published private(set) var rooms: [RoomSummary] = []
    @Published private(set) var myPlayerId: Int?
    @Published private(set) var roomCode: String?
    @Published private(set) var roomName: String?
    @Published private(set) var lobbyPlayers: [String] = []
    /// 游戏中权威全量快照（state_update.state）。等待室时为 nil。
    @Published private(set) var state: GameView?
    /// 当前阶段。未入局时为 .waiting；随 state_update / game_over 更新。
    @Published private(set) var phase: Phase = .waiting
    /// 仅靠 bid_turn 事件维护：当前轮到哪位出价（拍卖场景）。无人/已结束为 nil。
    @Published private(set) var currentBidderId: Int?
    /// 最近一条事件，驱动一次性提示 / 动画。
    @Published private(set) var lastEvent: GameEvent?
    /// 横幅文案（error / payment_failed / silver_bonus 等），nil 表示无横幅。
    @Published var banner: String?
    /// 最近一次私盘可选目标（get_deal_targets 的响应）。
    @Published private(set) var dealTargets: [DealTarget] = []
    /// 终局分数（game_over 携带，已降序）。单独存——因为 game_over 之后服务端还会再发一条
    /// state_update，会覆盖 lastEvent，故不能依赖 lastEvent 取分数。
    @Published private(set) var finalScores: [Score] = []

    /// 进入游戏后是否已收到首个 state_update。用于区分「等待室」与「游戏中」。
    @Published private(set) var gameStarted: Bool = false

    // ── 纯表现层信号（递增计数，仅用于驱动一次性动画；不参与任何游戏逻辑）──
    /// 银锭奖励金色闪光触发计数（silver_bonus 时 +1）。
    @Published private(set) var silverBonusPulse: Int = 0
    /// 银锭闪光文案（随计数更新）。
    @Published private(set) var silverBonusText: String = ""
    /// 庆祝礼花触发计数（截拍成功 / 私盘成交时 +1，仅当与「我」相关）。
    @Published private(set) var celebratePulse: Int = 0

    // ── 内部 ─────────────────────────────────────────────────
    private var task: URLSessionWebSocketTask?
    private var session: URLSession
    /// 本地保存的昵称（连接 / 建房 / 加入时复用）。
    private var playerName: String

    /// 断线重连令牌（内存副本）。joined_room / rejoined_room 时捕获；离开房间 / game_over 时清除。
    /// 同时按 roomCode 持久化到 UserDefaults，使 App 重启后仍可尝试原座位重连。
    private var reconnectToken: String?
    /// UserDefaults 中重连令牌的 key 前缀（按 roomCode 区分）。
    private static let tokenKeyPrefix = "reconnectToken."
    /// UserDefaults 中「最近一次房间码」的 key（App 重启后据此找回令牌发起 rejoin）。
    private static let lastRoomCodeKey = "reconnectLastRoomCode"
    /// 是否正处于一次重连尝试中（已发 rejoin_room，等待 rejoined_room / error）。
    /// 用于在收到 error 时判定「令牌失效」并回退大厅。
    private var isRejoining = false
    /// 可选的客户端保活定时器（周期 sendPing；失败即标记断开触发重连）。
    private var pingTimer: Timer?
    private static let pingIntervalSec: TimeInterval = 20

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // ⚠️ 不用全局 keyDecodingStrategy —— 各模型逐个写了 CodingKeys。
        return d
    }()

    init(playerName: String = "") {
        self.playerName = playerName
        self.session = URLSession(configuration: .default)
    }

    // ── 昵称 ─────────────────────────────────────────────────
    func setPlayerName(_ name: String) {
        playerName = name
    }

    var currentPlayerName: String { playerName }

    // ── 连接生命周期 ─────────────────────────────────────────
    func connect() {
        // 已连接 / 连接中则不重复连。
        if connection == .connected || connection == .connecting { return }
        connection = .connecting
        let t = session.webSocketTask(with: Endpoints.serverURL)
        task = t
        t.resume()
        // URLSessionWebSocketTask 没有显式「已连接」回调；resume 后即可收发。
        // 发送一次 ping 以尽快确认链路；成功则置 connected。
        connection = .connected
        receive()
        startPingTimer()
        // 进大厅后立即拉一次房间列表（若本就在大厅）。
        if roomCode == nil {
            send(.listRooms)
        }
    }

    func disconnect() {
        stopPingTimer()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        connection = .disconnected
    }

    /// 主动断开并清空一切房间 / 游戏状态，回到「未入房」初始态（用于返回大厅）。
    func leaveToLobby() {
        // 主动离开房间：清除已存的重连令牌与房间码，避免下次误用旧座位。
        clearReconnectToken()
        isRejoining = false
        roomCode = nil
        roomName = nil
        myPlayerId = nil
        lobbyPlayers = []
        state = nil
        phase = .waiting
        currentBidderId = nil
        gameStarted = false
        dealTargets = []
        finalScores = []
        // 断开重连以释放服务端旧座位（服务端 ws.close 会清理 room.players）。
        disconnect()
        connect()
    }

    // ── 发送 ─────────────────────────────────────────────────
    func send(_ action: ClientAction) {
        guard let task else { return }
        do {
            let data = try encoder.encode(action)
            let text = String(decoding: data, as: UTF8.self)
            task.send(.string(text)) { [weak self] error in
                guard let error else { return }
                Task { @MainActor in
                    self?.handleSocketError(error)
                }
            }
        } catch {
            // 编码失败（理论上不应发生）。仅记录，不崩溃。
            #if DEBUG
            print("[GameClient] encode action failed: \(error)")
            #endif
        }
    }

    // ── 递归接收循环 ─────────────────────────────────────────
    private func receive() {
        guard let task else { return }
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case let .success(message):
                    self.handle(message: message)
                    // 续收下一条（递归）。
                    self.receive()
                case let .failure(error):
                    self.handleSocketError(error)
                }
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case let .string(text):
            data = Data(text.utf8)
        case let .data(d):
            data = d
        @unknown default:
            return
        }
        do {
            let event = try decoder.decode(GameEvent.self, from: data)
            reduce(event)
        } catch {
            // 解码失败：容错，不中断接收循环。
            #if DEBUG
            print("[GameClient] decode event failed: \(error)  raw=\(String(decoding: data, as: UTF8.self))")
            #endif
        }
    }

    private func handleSocketError(_ error: Error) {
        #if DEBUG
        print("[GameClient] socket error: \(error)")
        #endif
        stopPingTimer()
        connection = .disconnected
        task = nil
    }

    // ── 事件归约（异构事件 → @Published） ────────────────────
    private func reduce(_ event: GameEvent) {
        lastEvent = event

        // 纯表现层副作用：按事件派发音效/触感。集中在此处接入，避免视图多处重复触发。
        // ⚠️ 只读不写状态，绝不影响下方的游戏/重连归约逻辑。
        emitFeedback(for: event)

        switch event {
        case let .roomList(rooms):
            self.rooms = rooms

        case let .roomCreated(code, name):
            // 易错点 1：create_room 不会入座。收到 room_created 后自动续发 join_room。
            self.roomCode = code
            self.roomName = name
            send(.joinRoom(roomCode: code, playerName: playerName.isEmpty ? nil : playerName, password: nil))

        case let .joinedRoom(joined):
            self.roomCode = joined.roomCode
            self.roomName = joined.roomName
            self.myPlayerId = joined.playerId
            self.lobbyPlayers = joined.players
            self.phase = .waiting
            self.gameStarted = false
            // 捕获并持久化重连令牌（内存 + 按 roomCode 存 UserDefaults）。
            storeReconnectToken(joined.reconnectToken, for: joined.roomCode)

        case let .rejoinedRoom(joined):
            // 重连成功：恢复座位，语义同 joined_room。其后服务端会补发 state_update（+turn_changed），
            // 真正的牌局渲染依赖随后的 state_update，这里只恢复身份与房间信息。
            isRejoining = false
            self.roomCode = joined.roomCode
            self.roomName = joined.roomName
            self.myPlayerId = joined.playerId
            self.lobbyPlayers = joined.players
            // 刷新令牌（服务端可能续发同一令牌，统一以最新为准）。
            storeReconnectToken(joined.reconnectToken, for: joined.roomCode)
            banner = "已重连，正在恢复牌局…"

        case let .playerDisconnected(name, _):
            // 某玩家游戏中掉线（座位保留，可能凭令牌重连回来）。仅提示。
            banner = "\(name) 掉线了"

        case let .playerReconnected(name, _):
            // 某玩家重连回座位。仅提示。
            banner = "\(name) 已重连"

        case let .playerJoined(name, playerCount):
            // 已在房间内的玩家会收到此事件（新人入座）。把名字补进名单。
            // 服务端 player_joined 不带完整名单，故按 playerCount 兜底去重追加。
            if !name.isEmpty, lobbyPlayers.count < playerCount {
                lobbyPlayers.append(name)
            }
            banner = "\(name) 加入了房间"

        case let .playerLeft(name):
            self.lobbyPlayers.removeAll { $0 == name }
            banner = "\(name) 离开了房间"

        case let .lobbyState(playerId, players):
            self.myPlayerId = playerId
            self.lobbyPlayers = players

        case let .error(message):
            banner = message
            // 若正处于重连尝试中收到 error（如「令牌无效」「房间不存在或已结束」），
            // 说明原座位已不可恢复：回退到大厅（leaveToLobby 内部会清除令牌），避免反复用废令牌重连。
            if isRejoining {
                isRejoining = false
                leaveToLobby()
            } else if myPlayerId == nil, roomCode != nil {
                // 入房/建房尚未落座时收到 error（如输错房间码、房间已不存在）：
                // 清掉乐观设置的房间码，退回大厅（保持连接），避免卡在「正在加入房间…」。
                roomCode = nil
                roomName = nil
                lobbyPlayers = []
                listRooms()
            }

        case .gameStarted:
            self.gameStarted = true
            // 真正的 phase / state 紧随其后的 state_update 到来。

        case let .stateUpdate(state):
            self.state = state
            self.phase = state.phase
            self.gameStarted = true
            // 离开拍卖/截拍阶段时清空出价者高亮。
            if state.phase != .auction {
                self.currentBidderId = nil
            }

        case let .turnChanged(_, _):
            // 回合切换：新一轮拍卖开始前，出价者未定。
            self.currentBidderId = nil

        case let .bidTurn(playerId, _, _):
            // 「轮到谁出价」只能靠这里维护。
            self.currentBidderId = playerId

        case .bidPlaced, .bidPassed:
            // 出价/放弃后，bid_turn 会紧接着指向下一位；此处无需改 currentBidderId。
            break

        case .noBids, .snipeSuccess, .snipeDeclined:
            self.currentBidderId = nil

        case .snipePrompt:
            // 出价轮结束，进入截拍。出价高亮清空；具体牌/价随后的 state_update 给出。
            self.currentBidderId = nil

        case let .silverBonus(bonus, count):
            banner = "白银加成！本轮全员 +\(bonus)（第 \(count) 次）"

        case let .paymentFailed(playerId, exposed, _, _):
            let name = state?.playerName(for: playerId) ?? "玩家\(playerId)"
            let detail = Self.describeExposed(exposed)
            banner = "\(name) 付款失败，钞票曝光：\(detail)"
            self.currentBidderId = nil

        case let .dealTargets(targets):
            self.dealTargets = targets

        case let .gameOver(scores):
            self.phase = .gameOver
            self.finalScores = scores
            self.currentBidderId = nil
            // 牌局结束：清除重连令牌与房间码，避免下次启动误用已结束的座位。
            clearReconnectToken()

        // 以下事件仅通过 lastEvent 驱动一次性 UI（提示/动画），无需改持久状态。
        case .auctionStarted, .privateDealStarted, .dealOfferSubmitted,
             .dealTie, .dealResolved, .unknown:
            break
        }
    }

    /// 按事件派发音效/触感（纯表现层副作用）。
    ///
    /// 只读取事件与 `myPlayerId` 做判断，**不修改任何状态**——与 reduce 的游戏/重连逻辑完全解耦，
    /// 单独成方法便于关停或替换。需要「区分是不是我」的事件（轮到你/截拍成功等）在这里据 myPlayerId 判定，
    /// 避免在视图层重复触发。
    private func emitFeedback(for event: GameEvent) {
        let fb = Feedback.shared
        switch event {
        case let .bidTurn(playerId, _, _):
            // 只有轮到「我」出价才强提示；轮到别人不打扰。
            if playerId == myPlayerId { fb.yourTurn() }
        case let .turnChanged(playerId, _):
            // 新一轮拍卖人是我（可开拍/发起私盘）时提示。
            if playerId == myPlayerId { fb.yourTurn() }
        case let .bidPlaced(playerId, _):
            // 我自己出价的手感已由按钮触发；这里只对「别人出价」发轻反馈。
            if playerId != myPlayerId { fb.bidPlaced() }
        case let .bidPassed(playerId):
            if playerId != myPlayerId { fb.bidPassed() }
        case .auctionStarted:
            fb.auctionStarted()
        case let .snipeSuccess(winnerId):
            fb.snipeSuccess()
            // 截拍成功的赢家若是我，放一次庆祝礼花。
            if winnerId == myPlayerId { celebratePulse &+= 1 }
        case .snipeDeclined, .noBids:
            fb.snipeDeclined()
        case let .dealResolved(resolved):
            fb.dealResolved()
            // 私盘我方胜出时庆祝。
            if resolved.effectiveWinnerId == myPlayerId { celebratePulse &+= 1 }
        case let .silverBonus(bonus, count):
            fb.silverBonus()
            // 触发全屏金色闪光（文案与横幅一致风格）。
            silverBonusText = "白银加成 +\(bonus)（第 \(count) 次）"
            silverBonusPulse &+= 1
        case .paymentFailed, .error:
            fb.error()
        case .gameOver:
            fb.gameOver()
        // 其余事件不发反馈（大厅/同步/中间态）。
        case .roomList, .roomCreated, .joinedRoom, .rejoinedRoom,
             .playerJoined, .playerLeft, .lobbyState, .playerDisconnected, .playerReconnected,
             .gameStarted, .stateUpdate, .snipePrompt,
             .privateDealStarted, .dealOfferSubmitted, .dealTie, .dealTargets,
             .unknown:
            break
        }
    }

    /// 把曝光的钞票字典格式化成「面值×张数」可读串（按面值升序，跳过 0 张）。
    static func describeExposed(_ money: [String: Int]) -> String {
        let parts: [String] = Denomination.keys.compactMap { key in
            guard let count = money[key], count > 0 else { return nil }
            return "\(key)×\(count)"
        }
        return parts.isEmpty ? "（空）" : parts.joined(separator: " ")
    }

    // ── 便利发送方法 ─────────────────────────────────────────
    func listRooms() { send(.listRooms) }

    func createRoom(roomName: String?, password: String? = nil) {
        let pn = playerName.isEmpty ? nil : playerName
        send(.createRoom(roomName: roomName, playerName: pn, password: password))
    }

    func joinRoom(roomCode: String, password: String? = nil) {
        let pn = playerName.isEmpty ? nil : playerName
        // 记下房间码，便于断线 / 重连判断（真正入座以 joined_room 为准）。
        self.roomCode = roomCode
        send(.joinRoom(roomCode: roomCode, playerName: pn, password: password))
    }

    func startGame() { send(.startGame) }
    func startAuction() { send(.startAuction) }
    func placeBid(_ amount: Int) { send(.placeBid(amount: amount)) }
    func passBid() { send(.passBid) }

    func snipe(doSnipe: Bool, paid: Money? = nil) {
        send(.actionSnipe(doSnipe: doSnipe, paid: paid))
    }

    func startDeal(targetId: Int, setId: String) {
        send(.startPrivateDeal(targetId: targetId, setId: setId))
    }

    func submitOffer(paid: Money) {
        send(.submitDealOffer(paid: paid))
    }

    func getDealTargets() {
        send(.getDealTargets)
    }

    /// 仅游戏中有响应；等待室阶段服务端不回，调用方需容忍「无响应」（不报错）。
    func requestState() {
        send(.requestState)
    }

    // ── 断线重连 ─────────────────────────────────────────────

    /// 是否具备凭令牌重连的条件（存有 roomCode 与对应令牌）。
    /// AppRootView 的 scenePhase 重连分支据此决定发 rejoin_room 还是 request_state。
    var canRejoin: Bool {
        guard let code = roomCode ?? persistedLastRoomCode else { return false }
        return (reconnectToken ?? persistedToken(for: code)) != nil
    }

    /// 用已存令牌把当前连接绑回原座位（替代 request_state）。
    /// 优先用内存令牌；内存没有则回退 UserDefaults（App 重启后的场景）。
    /// 调用前应确保已连接（connect() 完成）。
    func rejoin() {
        // 房间码优先内存，其次持久化的「最近房间码」。
        guard let code = roomCode ?? persistedLastRoomCode else { return }
        guard let token = reconnectToken ?? persistedToken(for: code) else { return }
        // 同步回内存，确保后续 reduce / 判断一致。
        self.roomCode = code
        self.reconnectToken = token
        isRejoining = true
        send(.rejoinRoom(roomCode: code, reconnectToken: token))
    }

    /// 捕获并持久化重连令牌（内存 + UserDefaults，按 roomCode 区分），并记下最近房间码。
    private func storeReconnectToken(_ token: String, for code: String) {
        reconnectToken = token
        let d = UserDefaults.standard
        d.set(token, forKey: Self.tokenKeyPrefix + code)
        d.set(code, forKey: Self.lastRoomCodeKey)
    }

    /// 清除内存与持久化的重连令牌（及最近房间码）。离开房间 / game_over / 令牌失效时调用。
    private func clearReconnectToken() {
        let d = UserDefaults.standard
        if let code = roomCode ?? persistedLastRoomCode {
            d.removeObject(forKey: Self.tokenKeyPrefix + code)
        }
        d.removeObject(forKey: Self.lastRoomCodeKey)
        reconnectToken = nil
    }

    /// 读取某 roomCode 对应的持久化令牌（无则 nil）。
    private func persistedToken(for code: String) -> String? {
        UserDefaults.standard.string(forKey: Self.tokenKeyPrefix + code)
    }

    /// 读取持久化的「最近房间码」（无则 nil）。
    private var persistedLastRoomCode: String? {
        UserDefaults.standard.string(forKey: Self.lastRoomCodeKey)
    }

    // ── 可选保活心跳 ─────────────────────────────────────────
    // 服务器每 30s 发协议级 PING，系统会自动回 PONG，无需必做的客户端代码。
    // 这里加一个轻量周期 sendPing 作额外保活：失败即标记断开，交由 scenePhase 触发重连。

    /// 启动客户端保活定时器（幂等）。connect() 成功后调用。
    private func startPingTimer() {
        stopPingTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: Self.pingIntervalSec, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendKeepAlivePing()
            }
        }
        pingTimer = timer
    }

    /// 停止保活定时器。
    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    /// 发一次 WebSocket PING；失败则视为链路已断，标记断开（由 scenePhase 重连兜底）。
    private func sendKeepAlivePing() {
        guard let task else { return }
        task.sendPing { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in
                self?.handleSocketError(NSError(domain: "GameClient", code: -1))
            }
        }
    }

    /// 清空横幅（用户手动消除提示时调用）。
    func clearBanner() { banner = nil }
}
