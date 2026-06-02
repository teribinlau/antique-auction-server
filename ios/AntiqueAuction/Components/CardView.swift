import SwiftUI

/// 展示一张古董卡：套系名 / 卡名 / 风味文字 / 套系分值。
struct CardView: View {
    let card: Card
    /// 是否紧凑模式（用于列表里成排显示）。
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack {
                Text(card.setName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
                Text("\(card.setScore) 分")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(card.cardName)
                .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.bold))

            if !compact {
                Text(card.flavorText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(compact ? 10 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }
}

#if DEBUG
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            CardView(card: .preview)
            CardView(card: .preview, compact: true)
        }
        .padding()
    }
}

extension Card {
    /// 预览 / 测试用样例卡。
    static let preview = Card(
        cardId: "lost_paintings_04",
        cardName: "富春山居图",
        flavorText: "残，不代表便宜；但太像了，反而更吓人。",
        setId: "lost_paintings",
        setName: "失传古画",
        setScore: 1000
    )
}
#endif
