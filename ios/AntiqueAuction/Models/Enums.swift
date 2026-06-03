import Foundation

/// 连接状态。GameClient 用它驱动 AppRootView 的路由。
enum ConnState: Equatable {
    case disconnected
    case connecting
    case connected
}

/// 游戏阶段。对应 state.phase 字符串：WAITING | AUCTION | SNIPE | PRIVATE_DEAL | GAME_OVER。
/// 用 rawValue 直接对应服务端字符串，decode 时 fallback 到 .waiting。
enum Phase: String, Codable, Equatable {
    case waiting = "WAITING"
    case auction = "AUCTION"
    case snipe = "SNIPE"
    case privateDeal = "PRIVATE_DEAL"
    case gameOver = "GAME_OVER"

    /// 服务端若发来未知字符串，安全降级为等待室。
    init(serverValue: String) {
        self = Phase(rawValue: serverValue) ?? .waiting
    }
}

/// 固定面值集合（与服务端 STARTING_MONEY / SILVER_INGOT_BONUS 拆分一致）。
/// 注意："0" 是废钞——凑张数不值钱，纯诈唬用。
enum Denomination {
    /// 面值数组，从小到大。BillPicker 按此顺序展示六行。
    static let all: [Int] = [0, 10, 50, 100, 200, 500]

    /// 字符串形式的 key，用于 money / paid 字典（[String: Int]）。
    static let keys: [String] = all.map { String($0) }
}
