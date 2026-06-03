import SwiftUI

/// 对手的钞票展示——只读，**只显示张数（handCount），不显示面值**。
/// 这是诈唬（bluffing）的信息来源：你只知道对方有几张，不知道值多少钱。
struct OpponentBills: View {
    let opponent: Opponent
    /// 是否高亮（如轮到该对手出价时）。
    var highlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(opponent.playerName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if highlighted {
                    Text("出价中…")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.antiqueGold)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "banknote")
                    .foregroundStyle(.green)
                // 只暴露张数，不暴露面值。
                Text("\(opponent.handCount) 张钞票")
                    .font(.callout.monospacedDigit())
                Spacer()
                if !opponent.completeSets.isEmpty {
                    Label("\(opponent.completeSets.count) 套", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(Color.antiqueGold)
                }
            }

            // 已亮明的古董数量（antiques 是公开信息）。
            if !opponent.antiques.isEmpty {
                Text("古董 \(opponent.antiques.count) 件")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        // 轮到该对手出价时呼吸高亮（脉冲），强化「现在是谁」。
        .pulseHighlight(active: highlighted, color: .antiqueGold, cornerRadius: 10)
    }
}

#if DEBUG
struct OpponentBills_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            OpponentBills(opponent: .preview, highlighted: true)
            OpponentBills(opponent: .preview)
        }
        .padding()
    }
}

extension Opponent {
    static let preview = Opponent(
        playerId: 1,
        playerName: "老王",
        handCount: 7,
        antiques: [.preview],
        completeSets: []
    )
}
#endif
