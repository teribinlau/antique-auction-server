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

    // ── 内部 ─────────────────────────────────────────────────
    private var task: URLSessionWebSocketTask?
    private var session: URLSession
    /// 本地保存的昵称（连接 / 建房 / 加入时复用）。
    private var playerName: String

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
        // 进大厅后立即拉一次房间列表（若本就在大厅）。
        if roomCode == nil {
            send(.listRooms)
        }
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        connection = .disconnected
    }

    /// 主动断开并清空一切房间 / 游戏状态，回到「未入房」初始态（用于返回大厅）。
    func leaveToLobby() {
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
        connection = .disconnected
        task = nil
    }

    // ── 事件归约（异构事件 → @Published） ────────────────────
    private func reduce(_ event: GameEvent) {
        lastEvent = event

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

        case let .error(message):
            banner = message

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

        // 以下事件仅通过 lastEvent 驱动一次性 UI（提示/动画），无需改持久状态。
        case .auctionStarted, .privateDealStarted, .dealOfferSubmitted,
             .dealTie, .dealResolved, .unknown:
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

    /// 清空横幅（用户手动消除提示时调用）。
    func clearBanner() { banner = nil }
}
