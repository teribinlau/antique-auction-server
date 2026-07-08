import Foundation

/// 金钱字典：key 是字符串面值（"0","10","50","100","200","500"），value 是张数。
typealias Money = [String: Int]

extension Money {
    /// 折算总金额（面值 × 张数 之和）。"0" 面值不贡献金额。
    var totalValue: Int {
        reduce(0) { acc, kv in
            acc + (Int(kv.key) ?? 0) * kv.value
        }
    }

    /// 总张数（不看面值）。对手 handCount 即等价于此。
    var totalCount: Int {
        values.reduce(0, +)
    }
}

/// 自己（含完整手牌信息）。对应服务端 _fullPlayerView。
struct MePlayer: Codable, Equatable {
    let playerId: Int
    let playerName: String
    let money: Money
    let antiques: [Card]
    let completeSets: [String]

    enum CodingKeys: String, CodingKey {
        case playerId
        case playerName
        case money
        case antiques
        case completeSets
    }
}

/// 对手（隐藏面值，只暴露 handCount = 钞票总张数）。对应服务端 _opponentView。
/// ⚠️ handCount 是「钞票张数」，不是古董数——bluffing 全靠它。
struct Opponent: Codable, Equatable, Identifiable {
    let playerId: Int
    let playerName: String
    let handCount: Int
    let antiques: [Card]
    let completeSets: [String]

    var id: Int { playerId }

    enum CodingKeys: String, CodingKey {
        case playerId
        case playerName
        case handCount
        case antiques
        case completeSets
    }
}

/// state_update.state 的完整结构。这是游戏中权威的全量快照。
/// 注意：bidOrder/bids/passed 不在 state 里——「轮到谁出价」靠 bid_turn 事件在 GameClient 维护。
struct GameView: Codable, Equatable {
    let myId: Int
    let phase: Phase
    let currentPlayerId: Int
    let deckSize: Int
    let silverIngotCount: Int
    let me: MePlayer
    let opponents: [Opponent]
    let auctionCard: Card?
    let highestBid: Int
    /// -1 表示无人出价。
    let highestBidder: Int
    /// -1 表示无私盘发起者。
    let dealInitiator: Int
    /// -1 表示无私盘目标。
    let dealTarget: Int
    /// "" 表示无私盘套系。
    let dealSetId: String
    /// 私盘顺序流：发起人是否已押注 / 目标是否已暗标。
    let dealInitiatorSubmitted: Bool
    let dealTargetSubmitted: Bool
    /// 发起人押注的【张数】（金额保密）；未押注时为 nil。目标据此决定还价。
    let dealOfferBillCount: Int?

    enum CodingKeys: String, CodingKey {
        case myId
        case phase
        case currentPlayerId
        case deckSize
        case silverIngotCount
        case me
        case opponents
        case auctionCard
        case highestBid
        case highestBidder
        case dealInitiator
        case dealTarget
        case dealSetId
        case dealInitiatorSubmitted
        case dealTargetSubmitted
        case dealOfferBillCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        myId = try c.decode(Int.self, forKey: .myId)
        // phase 用字符串解，安全降级
        let phaseStr = try c.decode(String.self, forKey: .phase)
        phase = Phase(serverValue: phaseStr)
        currentPlayerId = try c.decode(Int.self, forKey: .currentPlayerId)
        deckSize = try c.decode(Int.self, forKey: .deckSize)
        silverIngotCount = try c.decode(Int.self, forKey: .silverIngotCount)
        me = try c.decode(MePlayer.self, forKey: .me)
        opponents = try c.decode([Opponent].self, forKey: .opponents)
        // auctionCard 可能为 null
        auctionCard = try c.decodeIfPresent(Card.self, forKey: .auctionCard)
        highestBid = try c.decodeIfPresent(Int.self, forKey: .highestBid) ?? 0
        highestBidder = try c.decodeIfPresent(Int.self, forKey: .highestBidder) ?? -1
        dealInitiator = try c.decodeIfPresent(Int.self, forKey: .dealInitiator) ?? -1
        dealTarget = try c.decodeIfPresent(Int.self, forKey: .dealTarget) ?? -1
        dealSetId = try c.decodeIfPresent(String.self, forKey: .dealSetId) ?? ""
        dealInitiatorSubmitted = try c.decodeIfPresent(Bool.self, forKey: .dealInitiatorSubmitted) ?? false
        dealTargetSubmitted = try c.decodeIfPresent(Bool.self, forKey: .dealTargetSubmitted) ?? false
        dealOfferBillCount = try c.decodeIfPresent(Int.self, forKey: .dealOfferBillCount)
    }

    /// 便于在视图/预览里手工构造（非 decode 路径）。
    init(myId: Int, phase: Phase, currentPlayerId: Int, deckSize: Int,
         silverIngotCount: Int, me: MePlayer, opponents: [Opponent],
         auctionCard: Card?, highestBid: Int, highestBidder: Int,
         dealInitiator: Int, dealTarget: Int, dealSetId: String,
         dealInitiatorSubmitted: Bool = false, dealTargetSubmitted: Bool = false,
         dealOfferBillCount: Int? = nil) {
        self.myId = myId
        self.phase = phase
        self.currentPlayerId = currentPlayerId
        self.deckSize = deckSize
        self.silverIngotCount = silverIngotCount
        self.me = me
        self.opponents = opponents
        self.auctionCard = auctionCard
        self.highestBid = highestBid
        self.highestBidder = highestBidder
        self.dealInitiator = dealInitiator
        self.dealTarget = dealTarget
        self.dealSetId = dealSetId
        self.dealInitiatorSubmitted = dealInitiatorSubmitted
        self.dealTargetSubmitted = dealTargetSubmitted
        self.dealOfferBillCount = dealOfferBillCount
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(myId, forKey: .myId)
        try c.encode(phase.rawValue, forKey: .phase)
        try c.encode(currentPlayerId, forKey: .currentPlayerId)
        try c.encode(deckSize, forKey: .deckSize)
        try c.encode(silverIngotCount, forKey: .silverIngotCount)
        try c.encode(me, forKey: .me)
        try c.encode(opponents, forKey: .opponents)
        try c.encodeIfPresent(auctionCard, forKey: .auctionCard)
        try c.encode(highestBid, forKey: .highestBid)
        try c.encode(highestBidder, forKey: .highestBidder)
        try c.encode(dealInitiator, forKey: .dealInitiator)
        try c.encode(dealTarget, forKey: .dealTarget)
        try c.encode(dealSetId, forKey: .dealSetId)
        try c.encode(dealInitiatorSubmitted, forKey: .dealInitiatorSubmitted)
        try c.encode(dealTargetSubmitted, forKey: .dealTargetSubmitted)
        try c.encodeIfPresent(dealOfferBillCount, forKey: .dealOfferBillCount)
    }

    // ── 便利计算属性（供视图使用） ──────────────────────────

    /// 当前是否轮到我行动（拍卖人 / 私盘当事人语境）。
    var isMyTurn: Bool { currentPlayerId == myId }

    /// 我是不是本次拍卖的拍卖人（= 当前行动玩家）。
    var iAmAuctioner: Bool { currentPlayerId == myId }

    /// 按 playerId 找名字（含自己与对手）。
    func playerName(for id: Int) -> String {
        if id == me.playerId { return me.playerName }
        return opponents.first { $0.playerId == id }?.playerName ?? "玩家\(id)"
    }
}
