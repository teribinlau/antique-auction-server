import SwiftUI

/// 拍卖阶段。
/// - 拍卖人（当前行动玩家）：若尚未开拍 → 「开拍 / 发起私盘」二选一；已开拍 → 看牌与最高价。
/// - 其他玩家：看拍卖牌；轮到自己（currentBidderId == myId）时可出价 / 放弃。
struct AuctionView: View {
    @ObservedObject var client: GameClient
    let state: GameView

    @State private var bidAmount: Int = 10
    @State private var showDealPicker = false
    /// 最高价数字弹动用的缩放（highestBid 变化时短暂放大再回弹）。
    @State private var bidBump = false

    /// 是否已开拍（auctionCard 非空即视为已开拍）。
    private var auctionInProgress: Bool { state.auctionCard != nil }
    /// 是否轮到我出价。
    private var isMyBidTurn: Bool { client.currentBidderId == state.myId }
    /// 最低可出价：英式拍卖只能加价，须高于当前最高价一档（最少 10）。
    private var minBid: Int { max(10, state.highestBid + 10) }

    var body: some View {
        VStack(spacing: 16) {
            if state.iAmAuctioner {
                auctioneerView
            } else {
                bidderView
            }
        }
        .sheet(isPresented: $showDealPicker) {
            DealStartSheet(client: client, state: state)
        }
    }

    // ── 拍卖人视角 ───────────────────────────────────────────
    @ViewBuilder
    private var auctioneerView: some View {
        if auctionInProgress, let card = state.auctionCard {
            VStack(spacing: 12) {
                Text("你是拍卖人 · 拍卖进行中")
                    .font(.headline)
                revealCard(card)
                bidStatusBox
                Text("等待其他玩家依次出价…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 16) {
                Text(state.deckSize == 0 ? "私盘决胜 · 轮到你" : "轮到你了 · 请选择行动")
                    .font(.headline)
                    .foregroundStyle(Color.antiqueGold)
                Text(state.deckSize == 0
                     ? "牌堆已空：与持有相同套系的对手发起私盘，直到所有套系各归其主、无人可交易，游戏才结束。"
                     : "开拍一张新古董，或与持有相同套系的对手发起私盘。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if state.deckSize > 0 {
                    Button {
                        client.startAuction()
                    } label: {
                        Label("开拍下一张", systemImage: "hammer.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button {
                    client.getDealTargets()
                    showDealPicker = true
                } label: {
                    Label("发起私盘", systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if state.deckSize == 0 {
                    Text("牌堆已空，只能发起私盘。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            // 轮到我做选择：呼吸高亮整块。
            .pulseHighlight(active: true, color: .antiqueGold, cornerRadius: 14)
        }
    }

    // ── 出价者视角 ───────────────────────────────────────────
    @ViewBuilder
    private var bidderView: some View {
        if let card = state.auctionCard {
            VStack(spacing: 12) {
                Text("\(state.playerName(for: state.currentPlayerId)) 正在拍卖")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                revealCard(card)
                bidStatusBox

                if isMyBidTurn {
                    bidControls
                } else if let bidder = client.currentBidderId {
                    Text("等待 \(state.playerName(for: bidder)) 出价…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("等待出价…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            // 拍卖人尚未开拍。
            VStack(spacing: 8) {
                ProgressView()
                Text("等待 \(state.playerName(for: state.currentPlayerId)) 选择行动…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    /// 拍卖牌「开拍」呈现：缩放淡入 + 翻牌感（3D 翻转）。auctionCard 变化（换牌）即重放。
    @ViewBuilder
    private func revealCard(_ card: Card) -> some View {
        CardView(card: card)
            .frame(maxWidth: 240)
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .opacity
                )
            )
            .id(card.id)   // 换牌时 id 变化 → 触发插入过渡（翻牌/缩放淡入）
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: card.id)
    }

    /// 最高价信息框。highestBid 变化时数字弹动。
    private var bidStatusBox: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("当前最高价")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(state.highestBid)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color.antiqueGold)
                    .scaleEffect(bidBump ? 1.25 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bidBump)
                    .onChange(of: state.highestBid) { _ in
                        // 数字弹一下再回弹。
                        bidBump = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            bidBump = false
                        }
                    }
            }
            Spacer()
            if state.highestBidder >= 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("最高出价者")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(state.playerName(for: state.highestBidder))
                        .font(.subheadline.weight(.semibold))
                }
            } else {
                Text("暂无人出价")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// 出价控件（仅轮到我时显示）。
    private var bidControls: some View {
        VStack(spacing: 12) {
            Text("轮到你出价")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
            Text(state.highestBid > 0
                 ? "出价须高于当前最高价 \(state.highestBid)"
                 : "起拍价 \(minBid) 起，之后只能加价")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Stepper(value: $bidAmount, in: minBid...100000, step: 10) {
                HStack {
                    Text("出价金额")
                    Spacer()
                    Text("\(bidAmount)")
                        .font(.title3.weight(.bold).monospacedDigit())
                }
            }

            HStack(spacing: 12) {
                Button {
                    // 我方出价：本地即时手感（别人收到由事件流发反馈）。
                    Feedback.shared.bidPlaced()
                    client.placeBid(bidAmount)
                } label: {
                    Text("出价 \(bidAmount)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    Feedback.shared.bidPassed()
                    client.passBid()
                } label: {
                    Text("放弃")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: 2)
        )
        // 轮到我出价：呼吸高亮整框，强调「该你了」。
        .pulseHighlight(active: isMyBidTurn, color: .antiqueGold, cornerRadius: 12)
        .onAppear {
            // 默认起拍价 = 比当前最高价高一档（minBid）。
            bidAmount = minBid
        }
        .onChange(of: state.highestBid) { _ in
            // 别人加价后，把我的起拍价顶到新的最低线（避免选到已不合法的低价）。
            bidAmount = max(bidAmount, minBid)
        }
    }
}

/// 发起私盘弹窗：从 deal_targets 里选 (setId, targetId)。
private struct DealStartSheet: View {
    @ObservedObject var client: GameClient
    let state: GameView
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if client.dealTargets.isEmpty {
                    ContentUnavailableCompat(
                        title: "暂无可换的套系",
                        systemImage: "arrow.left.arrow.right",
                        description: "你和对手没有相同套系的古董可换。"
                    )
                } else {
                    List {
                        ForEach(client.dealTargets) { target in
                            Button {
                                client.startDeal(targetId: target.targetId, setId: target.setId)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(setDisplayName(target.setId))
                                            .font(.headline)
                                        Text("对手：\(state.playerName(for: target.targetId))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("可换 \(target.tradeCount) 张")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("发起私盘")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        client.getDealTargets()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear { client.getDealTargets() }
        .presentationDetents([.medium, .large])
    }

    /// 套系名优先取自己手牌里同 setId 的卡（拿到中文 setName）；否则回退 setId。
    private func setDisplayName(_ setId: String) -> String {
        if let card = state.me.antiques.first(where: { $0.setId == setId }) {
            return card.setName
        }
        return setId
    }
}
