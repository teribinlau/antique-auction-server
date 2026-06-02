import Foundation

/// 服务端 → 客户端的事件。
///
/// 线上格式：扁平 JSON `{ "event": "...", ...payload }`（server.js 里所有推送都带 `event`，
/// 其余字段与 event 同级平铺）。因此自定义 Decodable 先解 `event` 字符串，再按分支解各自 payload。
///
/// 解码策略：未知/无法解析的 event 一律归入 `.unknown(String)`，绝不抛错——
/// 这样接收循环不会因为一条不认识的消息而中断（容错性优先）。
enum GameEvent: Decodable {
    // ── 大厅 / 房间 ────────────────────────────────────────
    case roomList(rooms: [RoomSummary])
    case roomCreated(roomCode: String, roomName: String)
    case joinedRoom(JoinedRoom)
    case playerJoined(playerName: String, playerCount: Int)
    case playerLeft(playerName: String)
    case error(message: String)
    case gameStarted(playerCount: Int)

    // ── 同步 ──────────────────────────────────────────────
    case stateUpdate(state: GameView)
    case turnChanged(playerId: Int, deckSize: Int?)

    // ── 拍卖 ──────────────────────────────────────────────
    case auctionStarted(card: Card, deckSize: Int, auctionerId: Int)
    case silverBonus(bonus: Int, count: Int)
    case bidTurn(playerId: Int, auctionerId: Int, highestBid: Int)
    case bidPlaced(playerId: Int, amount: Int)
    case bidPassed(playerId: Int)
    case noBids(winnerId: Int)

    // ── 截拍 ──────────────────────────────────────────────
    case snipePrompt(card: Card, highestBid: Int, highestBidder: Int, auctionerId: Int)
    case snipeSuccess(winnerId: Int)
    case snipeDeclined(winnerId: Int)
    case paymentFailed(playerId: Int, exposedMoney: [String: Int], card: Card?, currentPlayerId: Int)

    // ── 私盘 ──────────────────────────────────────────────
    case privateDealStarted(initiatorId: Int, targetId: Int, setId: String)
    case dealOfferSubmitted(targetId: Int, initiatorId: Int, offerCount: Int, setId: String)
    case dealTie(tieCount: Int, initiatorId: Int, targetId: Int, setId: String)
    case dealResolved(DealResolved)
    case dealTargets(targets: [DealTarget])

    // ── 结束 ──────────────────────────────────────────────
    case gameOver(scores: [Score])

    /// 无法识别的事件名（容错兜底，携带原始 event 字符串）。
    case unknown(String)

    /// 事件名字符串（用于日志与提示派发）。与服务端 `ev.event` 一一对应。
    var name: String {
        switch self {
        case .roomList: return "room_list"
        case .roomCreated: return "room_created"
        case .joinedRoom: return "joined_room"
        case .playerJoined: return "player_joined"
        case .playerLeft: return "player_left"
        case .error: return "error"
        case .gameStarted: return "game_started"
        case .stateUpdate: return "state_update"
        case .turnChanged: return "turn_changed"
        case .auctionStarted: return "auction_started"
        case .silverBonus: return "silver_bonus"
        case .bidTurn: return "bid_turn"
        case .bidPlaced: return "bid_placed"
        case .bidPassed: return "bid_passed"
        case .noBids: return "no_bids"
        case .snipePrompt: return "snipe_prompt"
        case .snipeSuccess: return "snipe_success"
        case .snipeDeclined: return "snipe_declined"
        case .paymentFailed: return "payment_failed"
        case .privateDealStarted: return "private_deal_started"
        case .dealOfferSubmitted: return "deal_offer_submitted"
        case .dealTie: return "deal_tie"
        case .dealResolved: return "deal_resolved"
        case .dealTargets: return "deal_targets"
        case .gameOver: return "game_over"
        case let .unknown(name): return name
        }
    }

    /// 平铺 payload 的动态 key。
    private struct DynamicKey: CodingKey {
        var stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
        static func key(_ s: String) -> DynamicKey { DynamicKey(stringValue: s) }
        static let event = DynamicKey(stringValue: "event")
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        let event = try c.decode(String.self, forKey: .event)

        switch event {
        case "room_list":
            let rooms = try c.decodeIfPresent([RoomSummary].self, forKey: .key("rooms")) ?? []
            self = .roomList(rooms: rooms)

        case "room_created":
            let code = try c.decode(String.self, forKey: .key("roomCode"))
            let name = try c.decodeIfPresent(String.self, forKey: .key("roomName")) ?? ""
            self = .roomCreated(roomCode: code, roomName: name)

        case "joined_room":
            // joined_room 的 payload 与 JoinedRoom 字段同层平铺，直接用同一个 decoder 解。
            let joined = try JoinedRoom(from: decoder)
            self = .joinedRoom(joined)

        case "player_joined":
            let pn = try c.decodeIfPresent(String.self, forKey: .key("playerName")) ?? ""
            let pc = try c.decodeIfPresent(Int.self, forKey: .key("playerCount")) ?? 0
            self = .playerJoined(playerName: pn, playerCount: pc)

        case "player_left":
            let pn = try c.decodeIfPresent(String.self, forKey: .key("playerName")) ?? ""
            self = .playerLeft(playerName: pn)

        case "error":
            let msg = try c.decodeIfPresent(String.self, forKey: .key("message")) ?? "未知错误"
            self = .error(message: msg)

        case "game_started":
            let pc = try c.decodeIfPresent(Int.self, forKey: .key("playerCount")) ?? 0
            self = .gameStarted(playerCount: pc)

        case "state_update":
            let state = try c.decode(GameView.self, forKey: .key("state"))
            self = .stateUpdate(state: state)

        case "turn_changed":
            let pid = try c.decode(Int.self, forKey: .key("playerId"))
            let ds = try c.decodeIfPresent(Int.self, forKey: .key("deckSize"))
            self = .turnChanged(playerId: pid, deckSize: ds)

        case "auction_started":
            let card = try c.decode(Card.self, forKey: .key("card"))
            let ds = try c.decodeIfPresent(Int.self, forKey: .key("deckSize")) ?? 0
            let aid = try c.decode(Int.self, forKey: .key("auctionerId"))
            self = .auctionStarted(card: card, deckSize: ds, auctionerId: aid)

        case "silver_bonus":
            let bonus = try c.decodeIfPresent(Int.self, forKey: .key("bonus")) ?? 0
            let count = try c.decodeIfPresent(Int.self, forKey: .key("count")) ?? 0
            self = .silverBonus(bonus: bonus, count: count)

        case "bid_turn":
            let pid = try c.decode(Int.self, forKey: .key("playerId"))
            let aid = try c.decode(Int.self, forKey: .key("auctionerId"))
            let hb = try c.decodeIfPresent(Int.self, forKey: .key("highestBid")) ?? 0
            self = .bidTurn(playerId: pid, auctionerId: aid, highestBid: hb)

        case "bid_placed":
            let pid = try c.decode(Int.self, forKey: .key("playerId"))
            let amount = try c.decodeIfPresent(Int.self, forKey: .key("amount")) ?? 0
            self = .bidPlaced(playerId: pid, amount: amount)

        case "bid_passed":
            let pid = try c.decode(Int.self, forKey: .key("playerId"))
            self = .bidPassed(playerId: pid)

        case "no_bids":
            let wid = try c.decode(Int.self, forKey: .key("winnerId"))
            self = .noBids(winnerId: wid)

        case "snipe_prompt":
            let card = try c.decode(Card.self, forKey: .key("card"))
            let hb = try c.decodeIfPresent(Int.self, forKey: .key("highestBid")) ?? 0
            let hbidder = try c.decodeIfPresent(Int.self, forKey: .key("highestBidder")) ?? -1
            let aid = try c.decode(Int.self, forKey: .key("auctionerId"))
            self = .snipePrompt(card: card, highestBid: hb, highestBidder: hbidder, auctionerId: aid)

        case "snipe_success":
            let wid = try c.decode(Int.self, forKey: .key("winnerId"))
            self = .snipeSuccess(winnerId: wid)

        case "snipe_declined":
            let wid = try c.decode(Int.self, forKey: .key("winnerId"))
            self = .snipeDeclined(winnerId: wid)

        case "payment_failed":
            let pid = try c.decode(Int.self, forKey: .key("playerId"))
            let exposed = try c.decodeIfPresent([String: Int].self, forKey: .key("exposedMoney")) ?? [:]
            let card = try c.decodeIfPresent(Card.self, forKey: .key("card"))
            let cur = try c.decodeIfPresent(Int.self, forKey: .key("currentPlayerId")) ?? -1
            self = .paymentFailed(playerId: pid, exposedMoney: exposed, card: card, currentPlayerId: cur)

        case "private_deal_started":
            let iid = try c.decode(Int.self, forKey: .key("initiatorId"))
            let tid = try c.decode(Int.self, forKey: .key("targetId"))
            let sid = try c.decodeIfPresent(String.self, forKey: .key("setId")) ?? ""
            self = .privateDealStarted(initiatorId: iid, targetId: tid, setId: sid)

        case "deal_offer_submitted":
            let tid = try c.decode(Int.self, forKey: .key("targetId"))
            let iid = try c.decode(Int.self, forKey: .key("initiatorId"))
            let oc = try c.decodeIfPresent(Int.self, forKey: .key("offerCount")) ?? 0
            let sid = try c.decodeIfPresent(String.self, forKey: .key("setId")) ?? ""
            self = .dealOfferSubmitted(targetId: tid, initiatorId: iid, offerCount: oc, setId: sid)

        case "deal_tie":
            let tc = try c.decodeIfPresent(Int.self, forKey: .key("tieCount")) ?? 0
            let iid = try c.decode(Int.self, forKey: .key("initiatorId"))
            let tid = try c.decode(Int.self, forKey: .key("targetId"))
            let sid = try c.decodeIfPresent(String.self, forKey: .key("setId")) ?? ""
            self = .dealTie(tieCount: tc, initiatorId: iid, targetId: tid, setId: sid)

        case "deal_resolved":
            // 两种形态共用 DealResolved（winnerId / tieForcedWinner 都是可选）。
            let resolved = try DealResolved(from: decoder)
            self = .dealResolved(resolved)

        case "deal_targets":
            let targets = try c.decodeIfPresent([DealTarget].self, forKey: .key("targets")) ?? []
            self = .dealTargets(targets: targets)

        case "game_over":
            let scores = try c.decodeIfPresent([Score].self, forKey: .key("scores")) ?? []
            self = .gameOver(scores: scores)

        default:
            self = .unknown(event)
        }
    }
}
