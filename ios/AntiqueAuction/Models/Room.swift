import Foundation

/// 大厅房间摘要（room_list.rooms[] 的元素）。
struct RoomSummary: Codable, Identifiable, Equatable {
    let roomCode: String
    let roomName: String
    let playerCount: Int
    let hasPassword: Bool

    /// Identifiable：房间码唯一。
    var id: String { roomCode }

    enum CodingKeys: String, CodingKey {
        case roomCode
        case roomName
        case playerCount
        case hasPassword
    }
}

/// joined_room 事件的 payload（已入座，含分配到的 playerId 与当前名单）。
struct JoinedRoom: Codable, Equatable {
    let roomCode: String
    let roomName: String
    let playerId: Int
    let playerCount: Int
    let players: [String]

    enum CodingKeys: String, CodingKey {
        case roomCode
        case roomName
        case playerId
        case playerCount
        case players
    }
}
