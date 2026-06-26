import SwiftUI

/// 游戏容器：按 phase 路由到四个子视图，顶部固定一条状态条 + 我方信息。
struct GameContainerView: View {
    @ObservedObject var client: GameClient

    var body: some View {
        Group {
            if let state = client.state {
                VStack(spacing: 0) {
                    GameStatusBar(state: state, client: client)
                    Divider().overlay(Color.white.opacity(0.08))
                    ScrollView {
                        VStack(spacing: 16) {
                            // 对手区（始终可见，展示张数 = 诈唬信息）。
                            opponentsSection(state)

                            // 按阶段路由。切阶段时做淡入+轻微上移过渡。
                            phaseContent(state)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .id(state.phase)            // phase 变化即重建并触发过渡

                            // 我方手牌与古董。
                            MyHandSection(me: state.me)
                        }
                        .padding()
                        .animation(.easeInOut(duration: 0.3), value: state.phase)
                    }
                    .scrollContentBackground(.hidden)   // 透出底层古董背景（iOS 16+）
                }
                // 截拍成功 / 私盘我方胜出时的庆祝礼花（覆盖整屏，不挡操作）。
                .overlay(CelebrationOverlay(trigger: client.celebratePulse))
            } else {
                ProgressView("正在同步牌局…")
                    .tint(.antiqueGold)
            }
        }
    }

    /// 按阶段路由子视图（抽出便于加统一过渡）。
    @ViewBuilder
    private func phaseContent(_ state: GameView) -> some View {
        switch state.phase {
        case .auction:
            AuctionView(client: client, state: state)
        case .snipe:
            SnipeView(client: client, state: state)
        case .privateDeal:
            PrivateDealView(client: client, state: state)
        case .gameOver:
            // game_over 通常由 GameOverView 全屏接管；这里兜底。
            Text("游戏结束")
                .font(.title2)
                .padding()
        case .waiting:
            ProgressView("等待开局…")
                .padding()
        }
    }

    @ViewBuilder
    private func opponentsSection(_ state: GameView) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("对手")
                .font(.headline)
            ForEach(state.opponents) { opp in
                OpponentBills(
                    opponent: opp,
                    highlighted: client.currentBidderId == opp.playerId
                )
            }
        }
    }
}

/// 顶部状态条：阶段、牌堆剩余、当前行动者、白银计数。
struct GameStatusBar: View {
    let state: GameView
    @ObservedObject var client: GameClient

    var body: some View {
        HStack(spacing: 14) {
            statusItem(icon: "flag.fill", text: phaseLabel)
            statusItem(icon: "rectangle.stack.fill", text: "牌堆 \(state.deckSize)")
            if state.silverIngotCount > 0 {
                statusItem(icon: "dollarsign.circle.fill", text: "白银 \(state.silverIngotCount)")
            }
            Spacer()
            // 当前行动玩家（拍卖人）。轮到我时金色 + 呼吸高亮。
            Text(state.isMyTurn ? "轮到你" : "行动：\(state.playerName(for: state.currentPlayerId))")
                .font(.caption.weight(.bold))
                .foregroundStyle(state.isMyTurn ? Color.antiqueGold : Color.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .pulseHighlight(active: state.isMyTurn, color: .antiqueGold, cornerRadius: 8)
                // currentPlayerId 变化时平滑过渡。
                .animation(.easeInOut(duration: 0.25), value: state.currentPlayerId)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var phaseLabel: String {
        switch state.phase {
        case .waiting: return "等待"
        case .auction: return "拍卖"
        case .snipe: return "截拍"
        case .privateDeal: return "私盘"
        case .gameOver: return "结束"
        }
    }

    private func statusItem(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// 我方手牌区：钞票明细（面值可见）+ 古董 + 完整套系。
struct MyHandSection: View {
    let me: MePlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("我的手牌")
                .font(.headline)

            // 钞票明细（自己可见面值）。
            VStack(spacing: 6) {
                ForEach(Denomination.all, id: \.self) { face in
                    let count = me.money[String(face)] ?? 0
                    HStack {
                        Text(face == 0 ? "废钞" : "\(face)")
                            .font(.subheadline.monospacedDigit())
                            .frame(width: 60, alignment: .leading)
                        Spacer()
                        Text("\(count) 张")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(count > 0 ? .primary : .tertiary)
                    }
                }
                Divider()
                HStack {
                    Text("总计")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(me.money.totalValue)（\(me.money.totalCount) 张）")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )

            // 古董收藏。
            if me.antiques.isEmpty {
                Text("尚无古董")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("我的古董（\(me.antiques.count) 件）")
                    .font(.subheadline.weight(.semibold))
                ForEach(me.antiques) { card in
                    // 属于已集齐套系的卡加金色「集齐」徽章。
                    CardView(card: card,
                             compact: true,
                             inCompleteSet: me.completeSets.contains(card.setId))
                }
            }

            if !me.completeSets.isEmpty {
                Label("已集齐 \(me.completeSets.count) 套", systemImage: "checkmark.seal.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.antiqueGold)
            }
        }
    }
}
