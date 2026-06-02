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
            content
            // 全局横幅覆盖层（error / payment_failed / silver_bonus）。
            BannerOverlay(client: client)
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhase(newPhase)
        }
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

    // ── 重连：scenePhase 回到 active 时 ──────────────────────
    private func handleScenePhase(_ phase: ScenePhase) {
        guard phase == .active else { return }
        // 未连接则尝试连接（昵称非空时）。
        if client.connection == .disconnected && !client.currentPlayerName.isEmpty {
            client.connect()
        }
        // 已在房间里则请求一次状态。等待室阶段服务端不回，属正常（容忍无响应）。
        if client.roomCode != nil {
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
