import SwiftUI

/// 套牌主题：把每个 `setId` 映射到「主题色 + SF Symbol 图标 + 稀有度档位」。
///
/// 设计目标：
///  - **集中一处**，便于日后整体替换配色/图标，或换成真实美术（见 README「视觉与手感」）。
///  - 仅用 **iOS 16 已有的 SF Symbol**（拿不准的一律退回通用符号），避免高版本符号在 iOS 16 渲染成空白。
///  - 不依赖任何资源文件：纯程序化（颜色 + 系统符号）。
///
/// ⚠️ 只读表现层：不参与任何游戏逻辑/网络协议。`setId` 取值与服务端 `game_logic.js` 的
///    SET_SCORES 一致（lost_paintings / imperial_jade / … / paper_money 共 10 套）。
enum SetTheme {

    /// 稀有度档位（按 setScore 分四档）。仅用于表现层增强（描边/高光/流光强度）。
    enum Rarity: Int, Comparable {
        case common = 0     // 普通
        case fine           // 精品
        case treasure       // 珍品
        case legendary      // 传世

        static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }

        /// 中文档位名（用于角标）。
        var label: String {
            switch self {
            case .common: return "普通"
            case .fine: return "精品"
            case .treasure: return "珍品"
            case .legendary: return "传世"
            }
        }

        /// 档位强调色（角标底色 / 描边）。传世为金，珍品为紫，精品为青蓝，普通为灰。
        var accent: Color {
            switch self {
            case .common: return Color(red: 0.55, green: 0.55, blue: 0.58)
            case .fine: return Color(red: 0.20, green: 0.55, blue: 0.62)
            case .treasure: return Color(red: 0.52, green: 0.32, blue: 0.62)
            case .legendary: return Color(red: 0.80, green: 0.62, blue: 0.28)
            }
        }

        /// 是否启用「高档卡面增强」（金色/高光/流光）。珍品及以上启用。
        var isElevated: Bool { self >= .treasure }

        /// 是否启用流光（仅传世，最克制：只有最高档才晃）。
        var hasShimmer: Bool { self == .legendary }
    }

    /// 一套牌的视觉定义。
    struct Style {
        /// 主题主色（深，用作渐变底色起点 / 图标色）。
        let primary: Color
        /// 主题副色（浅，用作渐变底色终点）。
        let secondary: Color
        /// SF Symbol 图标名（iOS 16 可用）。
        let symbol: String
        /// 稀有度档位。
        let rarity: Rarity
    }

    /// setScore → 稀有度。阈值：≥800 传世，≥350 珍品，≥160 精品，其余普通。
    /// （对应：失传古画/帝王玉器=传世；御窑瓷器/官库银锭/龙洋银币=珍品；
    ///   镇库铜钱/名家印玺=精品；绝版邮票/老宅奇珍/旧朝纸币=普通。）
    static func rarity(forScore score: Int) -> Rarity {
        switch score {
        case 800...: return .legendary
        case 350...: return .treasure
        case 160...: return .fine
        default: return .common
        }
    }

    /// 按 setId 取视觉定义。未知 setId 退回中性默认样式（按传入分值定档），保证健壮。
    static func style(forSetId setId: String, score: Int) -> Style {
        if let preset = presets[setId] {
            // 预设里已带 rarity；但仍以 score 兜底校正（防止后端调分后不一致）。
            return Style(primary: preset.primary,
                         secondary: preset.secondary,
                         symbol: preset.symbol,
                         rarity: rarity(forScore: score))
        }
        // 未知套系：中性石青 + 通用符号。
        return Style(primary: Color(red: 0.30, green: 0.33, blue: 0.38),
                     secondary: Color(red: 0.46, green: 0.49, blue: 0.54),
                     symbol: "questionmark.circle",
                     rarity: rarity(forScore: score))
    }

    /// 便利重载：直接用一张卡取样式。
    static func style(for card: Card) -> Style {
        style(forSetId: card.setId, score: card.setScore)
    }

    // ── 10 套预设（颜色取自「古董拍卖」意象，偏典雅、克制） ─────────────
    // 备注：每条的 rarity 仅作占位文档用途，实际以 rarity(forScore:) 为准。
    private static let presets: [String: Style] = [
        // 失传古画 1000 —— 传世。水墨青褐，画框意象。
        "lost_paintings": Style(
            primary: Color(red: 0.28, green: 0.22, blue: 0.18),
            secondary: Color(red: 0.52, green: 0.43, blue: 0.33),
            symbol: "photo.artframe",
            rarity: .legendary),
        // 帝王玉器 800 —— 传世。帝王青绿玉色。
        "imperial_jade": Style(
            primary: Color(red: 0.10, green: 0.40, blue: 0.32),
            secondary: Color(red: 0.32, green: 0.66, blue: 0.52),
            symbol: "diamond.fill",
            rarity: .legendary),
        // 御窑瓷器 650 —— 珍品。青花瓷蓝白。
        "imperial_porcelain": Style(
            primary: Color(red: 0.16, green: 0.28, blue: 0.52),
            secondary: Color(red: 0.42, green: 0.58, blue: 0.82),
            symbol: "cup.and.saucer.fill",
            rarity: .treasure),
        // 官库银锭 500 —— 珍品。库银冷银灰。
        "silver_ingots": Style(
            primary: Color(red: 0.34, green: 0.38, blue: 0.42),
            secondary: Color(red: 0.62, green: 0.66, blue: 0.70),
            symbol: "dollarsign.circle.fill",
            rarity: .treasure),
        // 龙洋银币 350 —— 珍品。银币冷银带蓝。
        "silver_dollars": Style(
            primary: Color(red: 0.30, green: 0.36, blue: 0.46),
            secondary: Color(red: 0.56, green: 0.63, blue: 0.74),
            symbol: "centsign.circle.fill",
            rarity: .treasure),
        // 镇库铜钱 250 —— 精品。古铜黄褐。
        "copper_coins": Style(
            primary: Color(red: 0.45, green: 0.30, blue: 0.14),
            secondary: Color(red: 0.74, green: 0.54, blue: 0.28),
            symbol: "circle.circle.fill",
            rarity: .fine),
        // 名家印玺 160 —— 精品。印泥朱红。
        "seals": Style(
            primary: Color(red: 0.52, green: 0.16, blue: 0.16),
            secondary: Color(red: 0.78, green: 0.34, blue: 0.30),
            symbol: "seal.fill",
            rarity: .fine),
        // 绝版邮票 90 —— 普通。邮政墨绿。
        "stamps": Style(
            primary: Color(red: 0.18, green: 0.38, blue: 0.30),
            secondary: Color(red: 0.40, green: 0.62, blue: 0.50),
            symbol: "envelope.fill",
            rarity: .common),
        // 老宅奇珍 40 —— 普通。旧木暖棕。
        "curios": Style(
            primary: Color(red: 0.40, green: 0.32, blue: 0.24),
            secondary: Color(red: 0.64, green: 0.54, blue: 0.42),
            symbol: "shippingbox.fill",
            rarity: .common),
        // 旧朝纸币 10 —— 普通。旧钞土黄。
        "paper_money": Style(
            primary: Color(red: 0.42, green: 0.38, blue: 0.22),
            secondary: Color(red: 0.68, green: 0.62, blue: 0.40),
            symbol: "banknote.fill",
            rarity: .common),
    ]
}

// ── 共享背景 / 配色（整体氛围统一） ───────────────────────────────

/// App 级氛围背景：雅致暗色「宣纸/檀木」渐变，置于各主屏底层。
/// 纯程序化（无图片资源）。深色为主，保证文字可读性。
struct AntiqueBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.10, blue: 0.12),
                Color(red: 0.16, green: 0.14, blue: 0.13),
                Color(red: 0.09, green: 0.09, blue: 0.11)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            // 顶部一抹暖金弱光，营造「拍卖灯」的氛围。
            RadialGradient(
                colors: [Color(red: 0.85, green: 0.68, blue: 0.36).opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
        )
        .ignoresSafeArea()
    }
}

extension Color {
    /// 全局「古董金」强调色（角标/高光/胜利色统一引用此色）。
    static let antiqueGold = Color(red: 0.83, green: 0.66, blue: 0.34)
}
