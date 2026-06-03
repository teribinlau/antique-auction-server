import SwiftUI
import UIKit
import AudioToolbox

/// 反馈中枢：把「关键时刻」集中映射到 **触感（UIKit）** + **系统音效（AudioToolbox）**。
///
/// 设计目标：
///  - **无外部资源**：触感用 `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`；
///    音效用 `AudioServicesPlaySystemSound`（系统内置 SoundID，无需打包 .wav/.mp3）。
///  - **可被偏好关闭**：`@AppStorage` 的「音效开关 / 触感开关」（默认开），UI 提供切换入口。
///  - **集中、避免重复触发**：视图通过 `.onChange(of:)` 监听 `GameClient` 暴露的事件流，
///    在此调用对应方法发反馈——只加副作用，不碰任何游戏/网络逻辑。
///  - **留扩展点**：`playCustomSound(named:)` 若 bundle 内存在对应音频则播放、否则回退系统音效；
///    日后放入真实 `.wav/.caf` 即可无缝替换（见 README「视觉与手感」）。
///
/// ⚠️ 纯表现层。所有 UIKit 反馈 API 须在主线程调用，故整体标 `@MainActor`。
@MainActor
final class Feedback: ObservableObject {

    /// 全局共享实例（视图与 GameClient 接法都引用同一份偏好）。
    static let shared = Feedback()

    // ── 偏好开关（与 @AppStorage 同 key，二者读写同一 UserDefaults）─────────
    /// UserDefaults key：音效开关。与 `FeedbackToggleButtons` 的 @AppStorage 一致。
    static let soundKey = "pref.soundEnabled"
    /// UserDefaults key：触感开关。
    static let hapticsKey = "pref.hapticsEnabled"

    private var soundEnabled: Bool {
        // 缺省视为开（首次启动无记录时返回 true）。
        UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true
    }
    private var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.hapticsKey) as? Bool ?? true
    }

    private init() {}

    // ── 关键时刻（供视图 / 接法调用）──────────────────────────────────────
    // 命名按「玩家感知到的事件」，而非协议事件名，便于在多处复用。

    /// 出价：轻快的一下。
    func bidPlaced() {
        impact(.light)
        sound(1104) // Tock
    }

    /// 放弃出价：很轻的一下（弱存在感）。
    func bidPassed() {
        impact(.soft)
        sound(1103) // Tink
    }

    /// 轮到你出价 / 行动：成功提示音 + 中等触感（要「叫得醒人」但不吵）。
    func yourTurn() {
        notify(.success)
        sound(1117) // 提示性「叮」
    }

    /// 截拍成功（你掏钱买下）：果断的成功反馈。
    func snipeSuccess() {
        notify(.success)
        sound(1054) // 较厚的确认音
    }

    /// 放手 / 截拍未发生（出价者拿牌）：中性确认。
    func snipeDeclined() {
        impact(.medium)
        sound(1105)
    }

    /// 私盘成交：成交的「敲槌」感。
    func dealResolved() {
        notify(.success)
        sound(1109) // 类似快门/敲击
    }

    /// 银锭奖励：连续两下「金币」感 + 成功触感（全员加成，值得强调）。
    func silverBonus() {
        notify(.success)
        sound(1407) // 较华丽的提示
    }

    /// 错误 / 付款失败：错误触感 + 警示音。
    func error() {
        notify(.error)
        sound(1073)
    }

    /// 游戏结束：庆祝性的成功反馈。
    func gameOver() {
        notify(.success)
        sound(1025) // 收尾「叮咚」
    }

    /// 拍卖开拍（新牌亮相）：一记利落的木槌感。
    func auctionStarted() {
        impact(.rigid)
        sound(1105)
    }

    /// 选钞加减：极轻的「选择」反馈（高频触发，必须克制）。
    func selectTick() {
        selection()
    }

    // ── 扩展点：自定义音频（bundle 内有则播，否则回退系统音效）────────────
    /// 若 App bundle 内存在 `named`（不含扩展名）对应的 `.caf/.wav/.aiff/.mp3`，则播放它；
    /// 否则回退到传入的系统 `fallbackSystemSoundID`。
    /// 用法：日后把真实音频拖进工程（勾选 target），调用 `playCustomSound(named: "bid", fallback: 1104)`。
    func playCustomSound(named name: String, fallback fallbackSystemSoundID: SystemSoundID) {
        guard soundEnabled else { return }
        let exts = ["caf", "wav", "aiff", "aif", "mp3"]
        for ext in exts {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                var soundID: SystemSoundID = 0
                if AudioServicesCreateSystemSoundID(url as CFURL, &soundID) == kAudioServicesNoError {
                    AudioServicesPlaySystemSound(soundID)
                    return
                }
            }
        }
        // 未找到资源：回退系统音效。
        sound(fallbackSystemSoundID)
    }

    // ── 底层封装（统一受开关控制）──────────────────────────────────────
    /// 播放一个系统 SoundID（受音效开关控制）。
    private func sound(_ id: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }

    /// 冲击触感（受触感开关控制）。
    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred()
    }

    /// 通知触感（成功/警告/错误，受触感开关控制）。
    private func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        g.notificationOccurred(type)
    }

    /// 选择触感（受触感开关控制）。
    private func selection() {
        guard hapticsEnabled else { return }
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        g.selectionChanged()
    }
}

// ── 偏好切换按钮（放进大厅 / 连接页工具栏的小设置入口）────────────────────

/// 音效 / 触感 / 减弱动画开关按钮组。图标按钮，点按即翻转对应 @AppStorage。
/// 放在工具栏（仅音效+触感）或设置区（`showMotion: true` 时附带减弱动画）皆可。
struct FeedbackToggleButtons: View {
    /// 是否额外显示「减弱动画」开关（工具栏空间紧张时传 false）。
    var showMotion: Bool = false

    @AppStorage(Feedback.soundKey) private var soundEnabled: Bool = true
    @AppStorage(Feedback.hapticsKey) private var hapticsEnabled: Bool = true
    @AppStorage(reduceMotionKey) private var reduceMotion: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Button {
                soundEnabled.toggle()
                // 翻到「开」时给一声反馈，确认生效。
                if soundEnabled { Feedback.shared.selectTick() }
            } label: {
                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .accessibilityLabel(soundEnabled ? "关闭音效" : "开启音效")

            Button {
                hapticsEnabled.toggle()
                if hapticsEnabled { Feedback.shared.selectTick() }
            } label: {
                Image(systemName: hapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone.slash")
            }
            .accessibilityLabel(hapticsEnabled ? "关闭触感" : "开启触感")

            if showMotion {
                Button {
                    reduceMotion.toggle()
                    if !reduceMotion { Feedback.shared.selectTick() }
                } label: {
                    // 开启动画用「光点」，减弱动画用「龟速」隐喻。
                    Image(systemName: reduceMotion ? "tortoise.fill" : "sparkles")
                }
                .accessibilityLabel(reduceMotion ? "开启动画" : "减弱动画")
            }
        }
        .foregroundStyle(.secondary)
    }
}
