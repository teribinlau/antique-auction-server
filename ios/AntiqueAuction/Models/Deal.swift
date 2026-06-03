import Foundation

/// 私盘可选目标（deal_targets.targets[] 的元素）。
/// 一个 (setId, targetId) 组合代表「我和某对手都持有该套系，可换 tradeCount 张」。
struct DealTarget: Codable, Identifiable, Equatable {
    let setId: String
    let targetId: Int
    let tradeCount: Int

    /// 组合主键：setId + targetId 唯一。
    var id: String { "\(setId)#\(targetId)" }

    enum CodingKeys: String, CodingKey {
        case setId
        case targetId
        case tradeCount
    }
}

/// deal_resolved 事件 payload。
/// ⚠️ 两种形态：
///   普通：{ winnerId, loserId, tradeCount, offerTotal, counterTotal, initiatorId }
///   连平掷币：{ tieForcedWinner, loserId, setId, tradeCount, offerTotal, counterTotal, initiatorId }
/// 故 winnerId 与 tieForcedWinner 都用可选 decodeIfPresent。
struct DealResolved: Codable, Equatable {
    /// 普通结算的赢家（连平掷币时为 nil）。
    let winnerId: Int?
    /// 连平掷币强制赢家（普通结算时为 nil）。
    let tieForcedWinner: Int?
    let loserId: Int
    let tradeCount: Int
    let offerTotal: Int
    let counterTotal: Int
    let initiatorId: Int
    /// 普通形态不一定带 setId，故可选。
    let setId: String?

    enum CodingKeys: String, CodingKey {
        case winnerId
        case tieForcedWinner
        case loserId
        case tradeCount
        case offerTotal
        case counterTotal
        case initiatorId
        case setId
    }

    /// 统一取「实际赢家」：优先普通 winnerId，否则连平 tieForcedWinner。
    var effectiveWinnerId: Int? {
        winnerId ?? tieForcedWinner
    }

    /// 是否由连平掷币决出。
    var wasTieFlip: Bool { tieForcedWinner != nil && winnerId == nil }
}
