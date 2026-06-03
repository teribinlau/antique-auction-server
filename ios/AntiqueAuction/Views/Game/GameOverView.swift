import SwiftUI

/// 游戏结束：排行榜（服务端已按分降序）+ 回大厅。
struct GameOverView: View {
    @ObservedObject var client: GameClient
    /// game_over 携带的分数（已降序）。
    let scores: [Score]

    private var myId: Int? { client.myPlayerId }

    /// 庆祝礼花触发计数（onAppear 时 +1 放一次）。
    @State private var celebrate = 0
    /// 奖杯呼吸动画。
    @State private var trophyPulse = false
    @AppStorage(reduceMotionKey) private var reduceMotion: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.antiqueGold)
                    .shadow(color: Color.antiqueGold.opacity(0.6), radius: trophyPulse ? 18 : 6)
                    .scaleEffect(trophyPulse ? 1.08 : 1.0)
                    .animation(
                        reduceMotion ? .default
                            : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                        value: trophyPulse
                    )
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
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        // 终局庆祝礼花（覆盖整屏，不挡按钮）。
        .overlay(CelebrationOverlay(trigger: celebrate, count: 22))
        .onAppear {
            trophyPulse = true
            celebrate &+= 1   // 进入即放一次礼花
        }
    }

    private func scoreRow(rank: Int, score: Score) -> some View {
        let isMe = score.playerId == myId
        let isWinner = rank == 0
        return HStack(spacing: 14) {
            Text(medal(for: rank))
                .font(.title2)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(score.playerName)
                    .font(isWinner ? .headline.weight(.heavy) : .headline)
                    .foregroundStyle(isWinner ? Color.antiqueGold : .primary)
                if isMe {
                    Text("（你）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(score.score)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(isWinner ? Color.antiqueGold : .primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(rowFill(isMe: isMe, isWinner: isWinner))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(rowStroke(isMe: isMe, isWinner: isWinner),
                              lineWidth: isWinner ? 2 : 1.5)
        )
        // 第一名加金色光晕强调。
        .shadow(color: isWinner ? Color.antiqueGold.opacity(0.5) : .clear, radius: 8)
    }

    /// 行底色：冠军金、自己淡金、其余中性。
    private func rowFill(isMe: Bool, isWinner: Bool) -> Color {
        if isWinner { return Color.antiqueGold.opacity(0.18) }
        if isMe { return Color.antiqueGold.opacity(0.10) }
        return Color(.secondarySystemBackground)
    }

    /// 行描边：冠军金边、自己淡金边、其余无。
    private func rowStroke(isMe: Bool, isWinner: Bool) -> Color {
        if isWinner { return Color.antiqueGold }
        if isMe { return Color.antiqueGold.opacity(0.5) }
        return .clear
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
