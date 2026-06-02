import Foundation

/// 客户端 → 服务端的指令。
///
/// 服务端读取扁平 JSON：`{ "action": "...", ...参数 }`（server.js 里 `const { action } = msg;`，
/// 然后直接取 `msg.amount` / `msg.roomCode` / `msg.paid` 等同级字段）。
/// 因此自定义 Encodable 必须把 action 字符串与参数**平铺**在同一层，绝不能嵌套。
enum ClientAction: Encodable {
    case listRooms
    case createRoom(roomName: String?, playerName: String?, password: String?)
    case joinRoom(roomCode: String, playerName: String?, password: String?)
    case requestState
    case startGame
    case startAuction
    case placeBid(amount: Int)
    case passBid
    case actionSnipe(doSnipe: Bool, paid: Money?)
    case startPrivateDeal(targetId: Int, setId: String)
    case submitDealOffer(paid: Money)
    case getDealTargets

    /// 与服务端 if (action === "...") 分支一一对应。
    var actionString: String {
        switch self {
        case .listRooms: return "list_rooms"
        case .createRoom: return "create_room"
        case .joinRoom: return "join_room"
        case .requestState: return "request_state"
        case .startGame: return "start_game"
        case .startAuction: return "start_auction"
        case .placeBid: return "place_bid"
        case .passBid: return "pass_bid"
        case .actionSnipe: return "action_snipe"
        case .startPrivateDeal: return "start_private_deal"
        case .submitDealOffer: return "submit_deal_offer"
        case .getDealTargets: return "get_deal_targets"
        }
    }

    /// 动态 key，用于平铺输出任意参数名。
    private struct DynamicKey: CodingKey {
        var stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
        static let action = DynamicKey(stringValue: "action")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicKey.self)
        try c.encode(actionString, forKey: .action)

        switch self {
        case .listRooms, .requestState, .startGame, .startAuction, .passBid, .getDealTargets:
            break // 无额外参数

        case let .createRoom(roomName, playerName, password):
            try c.encodeIfPresent(roomName, forKey: DynamicKey(stringValue: "roomName"))
            try c.encodeIfPresent(playerName, forKey: DynamicKey(stringValue: "playerName"))
            try c.encodeIfPresent(password, forKey: DynamicKey(stringValue: "password"))

        case let .joinRoom(roomCode, playerName, password):
            try c.encode(roomCode, forKey: DynamicKey(stringValue: "roomCode"))
            try c.encodeIfPresent(playerName, forKey: DynamicKey(stringValue: "playerName"))
            try c.encodeIfPresent(password, forKey: DynamicKey(stringValue: "password"))

        case let .placeBid(amount):
            try c.encode(amount, forKey: DynamicKey(stringValue: "amount"))

        case let .actionSnipe(doSnipe, paid):
            try c.encode(doSnipe, forKey: DynamicKey(stringValue: "doSnipe"))
            // paid 为可选；放手时可不带，服务端 `msg.paid || {}` 兜底。
            try c.encodeIfPresent(paid, forKey: DynamicKey(stringValue: "paid"))

        case let .startPrivateDeal(targetId, setId):
            try c.encode(targetId, forKey: DynamicKey(stringValue: "targetId"))
            try c.encode(setId, forKey: DynamicKey(stringValue: "setId"))

        case let .submitDealOffer(paid):
            try c.encode(paid, forKey: DynamicKey(stringValue: "paid"))
        }
    }
}
