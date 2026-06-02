import Foundation

/// 一张古董卡。服务端 buildDeck 输出的结构（cardId/cardName/flavorText/setId/setName/setScore）。
/// 字段含驼峰 setId/setName/setScore，逐个写 CodingKeys（不用全局 keyDecodingStrategy）。
struct Card: Codable, Identifiable, Equatable, Hashable {
    let cardId: String
    let cardName: String
    let flavorText: String
    let setId: String
    let setName: String
    let setScore: Int

    /// Identifiable：用 cardId 作为稳定标识。
    var id: String { cardId }

    enum CodingKeys: String, CodingKey {
        case cardId
        case cardName
        case flavorText
        case setId
        case setName
        case setScore
    }
}
