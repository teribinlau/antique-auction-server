import SwiftUI

/// 纯 SwiftUI 表现层特效合集（iOS 16 可用，无第三方、无资源）。
///
/// 提供：
///  - `PulseHighlight`：循环呼吸高亮（用于「轮到你」「当前出价者」强调）。
///  - `CelebrationOverlay`：星标礼花式庆祝（胜利/成交强调）。
///  - `GoldenFlashOverlay`：全屏金色闪光（银锭奖励）。
///  - `减弱动画` 偏好：`@AppStorage(reduceMotionKey)`，所有特效统一尊重它（关时退化为静态）。

/// UserDefaults key：减弱动画（默认关，即「开启动画」）。各特效统一通过 `@AppStorage(reduceMotionKey)` 读取。
let reduceMotionKey = "pref.reduceMotion"

// ── 呼吸高亮 ─────────────────────────────────────────────────

/// 给视图套一圈循环「呼吸」描边 + 轻微缩放，用于强调「轮到你/当前出价者」。
/// `active` 为 false 时完全静止、无描边。减弱动画时只显示静态描边、不缩放不循环。
struct PulseHighlight: ViewModifier {
    var active: Bool
    var color: Color = .antiqueGold
    var cornerRadius: CGFloat = 12

    @State private var pulsing = false
    @AppStorage(reduceMotionKey) private var reduceMotion: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(active ? (pulsing ? 0.95 : 0.45) : 0),
                                  lineWidth: active ? 2 : 0)
            )
            .scaleEffect(active && pulsing && !reduceMotion ? 1.015 : 1.0)
            .animation(
                active && !reduceMotion
                    ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .onAppear { if active && !reduceMotion { pulsing = true } }
            .onChange(of: active) { newValue in
                pulsing = newValue && !reduceMotion
            }
    }
}

extension View {
    /// 便捷：套一圈呼吸高亮。
    func pulseHighlight(active: Bool, color: Color = .antiqueGold, cornerRadius: CGFloat = 12) -> some View {
        modifier(PulseHighlight(active: active, color: color, cornerRadius: cornerRadius))
    }
}

// ── 庆祝礼花（星标四散）──────────────────────────────────────

/// 一枚星标粒子的状态。
private struct Particle: Identifiable {
    let id = UUID()
    let angle: Double          // 飞散方向（弧度）
    let distance: CGFloat      // 飞散距离
    let size: CGFloat
    let symbol: String
    let color: Color
    let delay: Double
}

/// 一次性「礼花」庆祝：从中心向四周迸发星标/光点，渐隐上浮。
/// 纯 SwiftUI（无 SpriteKit/资源）。减弱动画时直接不显示。
/// 用法：作为 `.overlay`，由外部 `trigger`（递增计数或 Bool）控制重放。
struct CelebrationOverlay: View {
    /// 触发信号：值变化即重新播放一次（用 Int 计数最稳）。
    var trigger: Int
    /// 粒子数量。
    var count: Int = 14

    @State private var particles: [Particle] = []
    @State private var animateOut = false
    @AppStorage(reduceMotionKey) private var reduceMotion: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Image(systemName: p.symbol)
                        .font(.system(size: p.size, weight: .bold))
                        .foregroundStyle(p.color)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .offset(
                            x: animateOut ? CGFloat(cos(p.angle)) * p.distance : 0,
                            y: animateOut ? CGFloat(sin(p.angle)) * p.distance : 0
                        )
                        .opacity(animateOut ? 0 : 1)
                        .scaleEffect(animateOut ? 1.0 : 0.2)
                        .animation(.easeOut(duration: 1.1).delay(p.delay), value: animateOut)
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: trigger) { _ in
            guard !reduceMotion else { return }
            play()
        }
    }

    private func play() {
        // 生成一批朝四周的星标。
        let symbols = ["star.fill", "sparkle", "seal.fill"]
        let colors: [Color] = [.antiqueGold, .yellow, .orange, .white]
        particles = (0..<count).map { i in
            Particle(
                angle: Double(i) / Double(count) * 2 * .pi + Double.random(in: -0.3...0.3),
                distance: CGFloat.random(in: 80...170),
                size: CGFloat.random(in: 14...26),
                symbol: symbols.randomElement()!,
                color: colors.randomElement()!,
                delay: Double.random(in: 0...0.15)
            )
        }
        animateOut = false
        // 下一拍触发飞散（确保从初始态开始动画）。
        DispatchQueue.main.async {
            animateOut = true
        }
    }
}

// ── 银锭奖励：全屏金色闪光 ───────────────────────────────────

/// 全屏短暂金色闪光 + 文案，用于「银锭奖励 silver_bonus」。
/// 由外部 `trigger`（递增计数）控制；自动淡入淡出后消失。减弱动画时只一闪即逝（缩短）。
struct GoldenFlashOverlay: View {
    var trigger: Int
    /// 闪光时展示的文案。
    var text: String

    @State private var visible = false
    @State private var shownText: String = ""
    @AppStorage(reduceMotionKey) private var reduceMotion: Bool = false

    var body: some View {
        ZStack {
            if visible {
                Color.antiqueGold.opacity(0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                VStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Color.antiqueGold)
                    Text(shownText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .shadow(color: .black.opacity(0.4), radius: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.35), value: visible)
        .onChange(of: trigger) { _ in
            shownText = text
            withAnimation { visible = true }
            // 维持后自动消失（减弱动画时更快）。
            let hold = reduceMotion ? 0.6 : 1.3
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                withAnimation { visible = false }
            }
        }
    }
}
