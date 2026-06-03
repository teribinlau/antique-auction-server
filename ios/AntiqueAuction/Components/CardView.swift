import SwiftUI
import UIKit

/// 展示一张古董卡。
///
/// 牌面采用 **5:7 竖版**：满幅插画背景（`Image(card.cardId)`，来自 `CardArt.xcassets`）+ 顶/底渐变蒙版 +
/// 程序叠加的「套系 / 稀有度 / 分值 / 卡名 / 集齐」徽章；按稀有度增强（珍品+金边，传世加克制流光）。
///
/// **美术未就位时自动回退**到程序化渐变 + 套系 SF 图标，所以可以边画边加、不会出现空白卡。
/// 画布规格见 `ios/README.md`「视觉与手感」：1500×2100（5:7）满幅出血，文件名 = `cardId`。
///
/// 接口保持稳定：`CardView(card:)` / `CardView(card:, compact:)` / `CardView(card:, compact:, inCompleteSet:)`。
///  - `compact: false`（默认）：完整竖版卡（开拍 / 截拍的主牌）。
///  - `compact: true`：列表行式缩略（小竖版缩略图 + 文字），用于「我的古董」列表，省高度。
struct CardView: View {
    let card: Card
    /// 是否紧凑模式（列表行）。
    var compact: Bool = false
    /// 是否属于已集齐套系（completeSets 命中）：加金色「集齐」徽章。
    var inCompleteSet: Bool = false

    private var style: SetTheme.Style { SetTheme.style(for: card) }
    private var corner: CGFloat { compact ? 8 : 18 }

    var body: some View {
        if compact { compactRow } else { fullCard }
    }

    // ── 完整竖版卡（5:7）─────────────────────────────────────
    private var fullCard: some View {
        Color.clear
            .aspectRatio(5.0 / 7.0, contentMode: .fit)
            .overlay { artwork }            // 满幅插画 / 程序化兜底
            .overlay { scrim }              // 顶/底压暗，保证叠字可读
            .overlay { chrome }             // 套系 / 分值 / 卡名 等叠加
            .overlay { shimmerOverlay }     // 传世流光（其余档为空）
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: style.rarity.isElevated ? 1.5 : 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            topRow
            Spacer(minLength: 0)
            bottomPlate
        }
        .padding(14)
    }

    private var topRow: some View {
        HStack(spacing: 6) {
            Text(card.setName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))

            rarityBadge

            Spacer(minLength: 0)

            Text("\(card.setScore) 分")
                .font(.callout.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
        }
    }

    private var bottomPlate: some View {
        VStack(alignment: .leading, spacing: 6) {
            if inCompleteSet { completeSetBadge }
            Text(card.cardName)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 1)
            Text(card.flavorText)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ── 列表行式缩略（compact）────────────────────────────────
    private var compactRow: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 46, height: 64)
                .overlay { artwork }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(card.setName).font(.caption.weight(.semibold))
                    rarityBadge
                }
                Text(card.cardName)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                if inCompleteSet { completeSetBadge }
            }

            Spacer(minLength: 0)

            Text("\(card.setScore) 分")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style.rarity.isElevated ? Color.antiqueGold.opacity(0.5) : .clear, lineWidth: 1)
        )
    }

    // ── 美术层：有图用图，无图回退程序化渐变 + 套系图标 ────────
    @ViewBuilder
    private var artwork: some View {
        if let ui = UIImage(named: card.cardId) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [style.primary, style.secondary],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                if style.rarity.isElevated {
                    RadialGradient(colors: [.white.opacity(0.18), .clear],
                                   center: .topLeading, startRadius: 0,
                                   endRadius: compact ? 60 : 220)
                }
                Image(systemName: style.symbol)
                    .font(.system(size: compact ? 22 : 60, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
        }
    }

    // ── 顶/底压暗蒙版：保证叠加文字在任意插画上都清晰 ─────────
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.55), location: 0.0),
                .init(color: .clear,               location: 0.24),
                .init(color: .clear,               location: 0.66),
                .init(color: .black.opacity(0.72), location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // ── 描边 / 角标 ──────────────────────────────────────────
    private var borderColor: Color {
        style.rarity.isElevated ? Color.antiqueGold.opacity(0.85) : Color.white.opacity(0.18)
    }

    private var rarityBadge: some View {
        Text(style.rarity.label)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(style.rarity.accent.opacity(0.9), in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    style.rarity.isElevated ? Color.antiqueGold.opacity(0.9) : .clear,
                    lineWidth: 1)
            )
    }

    private var completeSetBadge: some View {
        Label("集齐套系", systemImage: "checkmark.seal.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.10))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.antiqueGold, in: Capsule())
            .shadow(color: Color.antiqueGold.opacity(0.6), radius: 4)
    }

    @ViewBuilder
    private var shimmerOverlay: some View {
        if style.rarity.hasShimmer {
            ShimmerBand(corner: corner).allowsHitTesting(false)
        }
    }
}

/// 缓慢扫过的斜向高光带——`TimelineView` 驱动相位，纯 SwiftUI、iOS 16 可用。仅传世启用，很淡、节奏慢。
private struct ShimmerBand: View {
    let corner: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: 4.0)) / 4.0
            GeometryReader { geo in
                let w = geo.size.width
                LinearGradient(
                    colors: [.clear, .white.opacity(0.16), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(width: w * 0.5)
                .offset(x: -w * 0.75 + phase * (w * 1.5))
                .rotationEffect(.degrees(18))
                .blendMode(.screen)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
    }
}

#if DEBUG
struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    CardView(card: .preview)                 // 传世（带流光，无图→兜底）
                    CardView(card: .previewStamps)           // 普通
                }
                .frame(height: 360)

                CardView(card: .previewPorcelain, inCompleteSet: true) // 珍品 + 集齐
                    .frame(maxWidth: 240)

                // 列表行（compact）
                CardView(card: .preview, compact: true, inCompleteSet: true)
                CardView(card: .previewStamps, compact: true)
            }
            .padding()
        }
        .background(AntiqueBackground())
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
    static let previewPorcelain = Card(
        cardId: "imperial_porcelain_02",
        cardName: "青花缠枝纹梅瓶",
        flavorText: "釉色温润，开片细如蛛网。",
        setId: "imperial_porcelain",
        setName: "御窑瓷器",
        setScore: 650
    )
    static let previewStamps = Card(
        cardId: "stamps_01",
        cardName: "大龙邮票",
        flavorText: "齿孔尚在，便已难得。",
        setId: "stamps",
        setName: "绝版邮票",
        setScore: 90
    )
}
#endif
