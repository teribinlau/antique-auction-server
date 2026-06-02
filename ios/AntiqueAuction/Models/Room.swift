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

/// joined_room / rejoined_room 事件的 payload（已入座，含分配到的 playerId 与当前名单）。
///
/// rejoined_room 与 joined_room 字段结构完全一致（重连恢复座位），故共用本模型。
/// `reconnectToken` 为断线重连令牌：入座 / 重连成功时服务端下发，客户端持久化后
/// 凭此发 `rejoin_room` 绑回原座位。
struct JoinedRoom: Codable, Equatable {
    let roomCode: String
    let roomName: String
    let playerId: Int
    let playerCount: Int
    let players: [String]
    /// 断线重连令牌（服务端为该座位分配；用于后续 rejoin_room）。
    let reconnectToken: String

    enum CodingKeys: String, CodingKey {
        case roomCode
        case roomName
        case playerId
        case playerCount
        case players
        case reconnectToken
    }
}
