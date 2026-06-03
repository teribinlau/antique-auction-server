import Foundation

/// game_over.scores[] 的元素。服务端已按 score 降序排好。
struct Score: Codable, Identifiable, Equatable {
    let playerId: Int
    let playerName: String
    let score: Int

    var id: Int { playerId }

    enum CodingKeys: String, CodingKey {
        case playerId
        case playerName
        case score
    }
}
