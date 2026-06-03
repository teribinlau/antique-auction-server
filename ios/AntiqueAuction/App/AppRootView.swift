import SwiftUI

/// 顶层路由：持有唯一的 GameClient，按 connection / roomCode / phase 决定显示哪屏。
///
/// 路由优先级：
///  1. 未连接           → ConnectNameView
///  2. 已连接、未入房     → LobbyView
///  3. 已入房、phase=结束 → GameOverView（全屏）
///  4. 已入房、游戏进行中  → GameContainerView
///  5. 已入房、等待室     → RoomWaitingView
struct AppRootView: View {
    @StateObject private var client = GameClient()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .top) {
            // 全局雅致暗色背景（宣纸/檀木氛围），置于所有内容底层。
            AntiqueBackground()
            content
            // 银锭奖励：全屏金色闪光（由 silverBonusPulse 计数驱动）。
            GoldenFlashOverlay(trigger: client.silverBonusPulse, text: client.silverBonusText)
            // 全局横幅覆盖层（error / payment_failed / silver_bonus）。
            BannerOverlay(client: client)
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhase(newPhase)
        }
        // 统一强制深色：让所有系统色（secondary / secondarySystemBackground / 主文字）
        // 解析为深色变体，与 AntiqueBackground 的暗色氛围一致，避免浅色设备下色彩冲突。
        .preferredColorScheme(.dark)
        // 全局金色强调（按钮/高亮统一基调，呼应「古董金」）。
        .tint(.antiqueGold)
    }

    @ViewBuilder
    private var content: some View {
        switch client.connection {
        case .disconnected, .connecting:
            // 连接中也停留在首屏（按钮显示「连接中…」）。
            ConnectNameView(client: client)

        case .connected:
            // 真正入座的判据：roomCode 与 myPlayerId 都就绪（myPlayerId 要等 joined_room 才有）。
            if client.roomCode != nil, client.myPlayerId != nil {
                roomContent
            } else if client.roomCode != nil {
                // 入房过程中（已发 join/create，等 joined_room 回包）：轻量等待，避免闪烁。
                JoiningView()
            } else {
                LobbyView(client: client)
            }
        }
    }

    @ViewBuilder
    private var roomContent: some View {
        switch client.phase {
        case .gameOver:
            // 分数从 finalScores 取（game_over 之后还会到一条 state_update，故不依赖 lastEvent）。
            GameOverView(client: client, scores: client.finalScores)

        case .auction, .snipe, .privateDeal:
            GameContainerView(client: client)

        case .waiting:
            // 游戏尚未开始：等待室。若已 gameStarted 但 state 未到，显示同步中。
            if client.gameStarted && client.state == nil {
                ProgressView("正在同步牌局…")
            } else {
                RoomWaitingView(client: client)
            }
        }
    }

    // ── 重连：scenePhase 回到 active 且连接已断时 ──────────────
    private func handleScenePhase(_ phase: ScenePhase) {
        guard phase == .active else { return }
        // 仅在「连接已断」时才做重连恢复（连接仍健康则无需打扰，避免重复 rejoin / 横幅）。
        guard client.connection == .disconnected else { return }
        // 重建连接（昵称非空时）。connect() 同步置为 .connected 并开始收发。
        guard !client.currentPlayerName.isEmpty else { return }
        client.connect()
        // 恢复房间态：
        //  - 若存有 roomCode + reconnectToken（内存或持久化）→ 发 rejoin_room 绑回原座位；
        //    服务端随后会补发 rejoined_room + state_update(+turn_changed)。
        //  - 否则维持原 request_state 兜底（仅游戏中有响应，等待室无响应属正常）。
        if client.canRejoin {
            client.rejoin()
        } else if client.roomCode != nil {
            client.requestState()
        }
    }
}

/// 入房过程中的轻量过渡视图。
private struct JoiningView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("正在加入房间…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
