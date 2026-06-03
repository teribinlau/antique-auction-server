import SwiftUI

/// 展示一张古董卡（程序化牌面美术）。
///
/// 牌面由 `SetTheme` 驱动：套牌渐变背景 + SF Symbol 图标 + 名称/套系/分值徽章 +
/// 圆角/阴影/描边，并按稀有度档位增强（珍品+起金色描边与柔和高光；传世额外加克制流光）。
///
/// 对外接口保持稳定：原有 `CardView(card:)` 与 `CardView(card:, compact:)` 调用方无需改动；
/// 新增可选 `inCompleteSet`（默认 false），用于给「已集齐套系」的卡加一枚醒目徽章。
struct CardView: View {
    let card: Card
    /// 是否紧凑模式（用于列表里成排显示）。
    var compact: Bool = false
    /// 该卡是否属于已集齐的套系（completeSets 命中）。命中则加「集齐」徽章与额外高光。
    var inCompleteSet: Bool = false

    /// 当前卡的视觉定义（颜色/图标/稀有度）。
    private var style: SetTheme.Style { SetTheme.style(for: card) }
    /// 圆角半径（紧凑略小）。
    private var corner: CGFloat { compact ? 14 : 18 }

    var body: some View {
        content
            .padding(compact ? 12 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardBorder)
            .overlay(shimmerOverlay)          // 传世流光（克制；其余档位为空）
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(compact ? 0.18 : 0.28),
                    radius: compact ? 4 : 8, x: 0, y: compact ? 2 : 4)
    }

    // ── 卡面内容 ─────────────────────────────────────────────
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            // 顶部：套系徽章 + 稀有度档位 + 分值。
            HStack(spacing: 8) {
                Text(card.setName)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))

                rarityBadge

                Spacer(minLength: 0)

                Text("\(card.setScore) 分")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
            }

            // 主体：图标 + 卡名（+ 风味文字）。
            HStack(alignment: .top, spacing: compact ? 10 : 14) {
                iconBadge

                VStack(alignment: .leading, spacing: compact ? 2 : 6) {
                    Text(card.cardName)
                        .font(compact ? .subheadline.weight(.bold) : .title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if !compact {
                        Text(card.flavorText)
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            // 已集齐套系徽章（醒目）。
            if inCompleteSet {
                completeSetBadge
            }
        }
    }

    // ── 图标 ─────────────────────────────────────────────────
    private var iconBadge: some View {
        Image(systemName: style.symbol)
            .font(.system(size: compact ? 22 : 30, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: compact ? 40 : 54, height: compact ? 40 : 54)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))
            )
    }

    // ── 稀有度角标 ───────────────────────────────────────────
    private var rarityBadge: some View {
        Text(style.rarity.label)
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(style.rarity.accent.opacity(0.9), in: Capsule())
            .overlay(
                // 高档（珍品/传世）加一圈金边强调。
                Capsule().strokeBorder(
                    style.rarity.isElevated ? Color.antiqueGold.opacity(0.9) : .clear,
                    lineWidth: 1)
            )
    }

    // ── 已集齐徽章 ───────────────────────────────────────────
    private var completeSetBadge: some View {
        Label("集齐套系", systemImage: "checkmark.seal.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color(red: 0.16, green: 0.14, blue: 0.10))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.antiqueGold, in: Capsule())
            .shadow(color: Color.antiqueGold.opacity(0.6), radius: 4)
    }

    // ── 背景：套牌渐变 + 高档高光 ─────────────────────────────
    private var cardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [style.primary, style.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // 高档卡（珍品+）叠一层柔和高光，增加「质感」。
            if style.rarity.isElevated {
                RadialGradient(
                    colors: [.white.opacity(0.18), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: compact ? 90 : 160
                )
            }
        }
    }

    // ── 描边：高档金边，其余浅白边 ───────────────────────────
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .strokeBorder(
                style.rarity.isElevated
                    ? Color.antiqueGold.opacity(0.85)
                    : .white.opacity(0.16),
                lineWidth: style.rarity.isElevated ? 1.5 : 1
            )
    }

    // ── 流光：仅传世，克制（缓慢扫过的斜向高光带）─────────────
    @ViewBuilder
    private var shimmerOverlay: some View {
        if style.rarity.hasShimmer && !compact {
            ShimmerBand(corner: corner)
                .allowsHitTesting(false)
        }
    }
}

/// 缓慢扫过的斜向高光带——用 `TimelineView` 驱动相位，纯 SwiftUI、iOS 16 可用。
/// 仅最高档（传世）启用，整体很淡、节奏慢，避免晃眼。
private struct ShimmerBand: View {
    let corner: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            // 4 秒一个循环：相位 0→1。
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
                // 从左外侧扫到右外侧。
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
            VStack(spacing: 12) {
                CardView(card: .preview)                              // 传世（带流光）
                CardView(card: .preview, inCompleteSet: true)
                CardView(card: .previewPorcelain)                    // 珍品（金边高光）
                CardView(card: .previewStamps)                       // 普通
                CardView(card: .preview, compact: true)
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
