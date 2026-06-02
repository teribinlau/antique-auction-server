import SwiftUI

/// 游戏结束：排行榜（服务端已按分降序）+ 回大厅。
struct GameOverView: View {
    @ObservedObject var client: GameClient
    /// game_over 携带的分数（已降序）。
    let scores: [Score]

    private var myId: Int? { client.myPlayerId }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.yellow)
                Text("游戏结束")
                    .font(.largeTitle.weight(.bold))
                if let winner = scores.first {
                    Text("\(winner.playerName) 夺魁！")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(scores.enumerated()), id: \.element.id) { rank, score in
                    scoreRow(rank: rank, score: score)
                }
            }
            .padding(.horizontal)

            Spacer()

            Button {
                client.leaveToLobby()
            } label: {
                Label("返回大厅", systemImage: "house.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    private func scoreRow(rank: Int, score: Score) -> some View {
        let isMe = score.playerId == myId
        return HStack(spacing: 14) {
            Text(medal(for: rank))
                .font(.title2)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(score.playerName)
                    .font(.headline)
                if isMe {
                    Text("（你）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(score.score)")
                .font(.title3.weight(.bold).monospacedDigit())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMe ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isMe ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    private func medal(for rank: Int) -> String {
        switch rank {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(rank + 1)"
        }
    }
}
