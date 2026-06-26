import SwiftUI

/// 对手面板（只读）。
/// - **钞票**：只显示张数（handCount），不显示面值——这是诈唬（bluffing）的信息来源。
/// - **古董**：是公开信息，按套系分组展示「套系名 + 分值 + 张数」，集齐的套系镶金边。
///   （谁在收哪套、几张、什么分值，是判断私盘 / 抢拍的关键。）
struct OpponentBills: View {
    let opponent: Opponent
    /// 是否高亮（如轮到该对手出价时）。
    var highlighted: Bool = false

    /// 把对手已亮明的古董按套系归并，按分值从高到低排。
    private var antiqueGroups: [SetGroup] {
        Dictionary(grouping: opponent.antiques, by: { $0.setId })
            .map { setId, cards in
                SetGroup(setId: setId,
                         setName: cards[0].setName,
                         setScore: cards[0].setScore,
                         count: cards.count,
                         complete: opponent.completeSets.contains(setId))
            }
            .sorted { $0.setScore > $1.setScore }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            // 已亮明的古董——按套系/分值分组（公开信息）。
            if antiqueGroups.isEmpty {
                Text("尚无亮明古董")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(antiqueGroups) { antiqueChip($0) }
                    }
                    .padding(.vertical, 1)
                }
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

    /// 单个套系标签：主题色底 + 套系名 + 「分值·张数」，集齐镶金边 + 印章。
    private func antiqueChip(_ g: SetGroup) -> some View {
        let style = SetTheme.style(forSetId: g.setId, score: g.setScore)
        return HStack(spacing: 5) {
            Image(systemName: style.symbol)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 1) {
                Text(g.setName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(g.setScore)分 · \(g.count)张")
                    .font(.system(size: 10).weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
            }
            if g.complete {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.antiqueGold)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(style.primary))
        .overlay(
            Capsule().strokeBorder(
                g.complete ? Color.antiqueGold : Color.white.opacity(0.15),
                lineWidth: g.complete ? 1.2 : 0.5)
        )
    }
}

/// 对手某一套系的归并结果。
private struct SetGroup: Identifiable {
    let setId: String
    let setName: String
    let setScore: Int
    let count: Int
    let complete: Bool
    var id: String { setId }
}

#if DEBUG
struct OpponentBills_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            OpponentBills(opponent: .preview, highlighted: true)
            OpponentBills(opponent: .preview)
        }
        .padding()
        .background(AntiqueBackground())
    }
}

extension Opponent {
    static let preview = Opponent(
        playerId: 1,
        playerName: "老王",
        handCount: 7,
        antiques: (1...4).map { i in
            Card(cardId: "paper_money_0\(i)", cardName: "纸币\(i)", flavorText: "",
                 setId: "paper_money", setName: "旧朝纸币", setScore: 10)
        } + [
            Card(cardId: "imperial_porcelain_04", cardName: "祭红梅瓶", flavorText: "",
                 setId: "imperial_porcelain", setName: "御窑瓷器", setScore: 650),
            .preview,
        ],
        completeSets: ["paper_money"]
    )
}
#endif
