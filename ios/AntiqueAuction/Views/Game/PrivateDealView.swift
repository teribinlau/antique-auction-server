import SwiftUI

/// 私盘阶段（顺序流，对齐原版牛市交易）：
///  1. 发起人先押注 submit_deal_offer{paid}；
///  2. 目标看到发起人的【张数】（state.dealOfferBillCount，金额保密）后再暗标；
///  3. 出价高者赢，按各自报价互付金钱，赢家拿走双方该套系可换的牌。
///  平局会重标（重新从发起人开始）；连平掷币（deal_resolved.tieForcedWinner）。
/// 非当事人只看进度提示。废钞可凑张数虚张声势——张数可见、面值保密正是诈唬空间。
struct PrivateDealView: View {
    @ObservedObject var client: GameClient
    let state: GameView

    @State private var paid: Money = [:]
    @State private var submitted = false

    /// 我是否为此私盘当事人（发起人或目标）。
    private var iAmParticipant: Bool {
        state.myId == state.dealInitiator || state.myId == state.dealTarget
    }
    private var iAmInitiator: Bool { state.myId == state.dealInitiator }
    /// 服务端视角我是否已提交（重连恢复时本地 submitted 会丢，以 state 兜底）。
    private var meSubmittedOnServer: Bool {
        iAmInitiator ? state.dealInitiatorSubmitted : state.dealTargetSubmitted
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            if iAmParticipant {
                if submitted || meSubmittedOnServer {
                    waitingForCounterpart
                } else if !iAmInitiator && !state.dealInitiatorSubmitted {
                    waitingForInitiator
                } else {
                    offerControls
                }
            } else {
                bystanderView
            }
        }
        // 私盘对象/套系变化时重置本地提交态（防串场）。
        .onChange(of: state.dealInitiator) { _ in resetLocal() }
        .onChange(of: state.dealTarget) { _ in resetLocal() }
        .onChange(of: state.dealSetId) { _ in resetLocal() }
        // 收到平局事件需要重新报价：清空提交态。
        .onChange(of: dealTieSignal) { _ in
            submitted = false
            paid = [:]
        }
    }

    /// 用 lastEvent 是否为 deal_tie 作为「需重标」信号源。
    private var dealTieSignal: Int {
        // lastEvent 为可选，需用 `?` 解可选再匹配 case（否则会报「必须先解包」编译错误）。
        if case let .dealTie(tieCount, _, _, _)? = client.lastEvent { return tieCount }
        return 0
    }

    private func resetLocal() {
        submitted = false
        paid = [:]
    }

    // ── 头部信息 ─────────────────────────────────────────────
    private var header: some View {
        VStack(spacing: 8) {
            Text("私盘交易")
                .font(.title3.weight(.bold))
            Text("\(state.playerName(for: state.dealInitiator)) ⇄ \(state.playerName(for: state.dealTarget))")
                .font(.headline)
            Text("套系：\(setDisplayName(state.dealSetId))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // ── 报价控件（发起人押注 / 目标看到张数后还价） ──────────
    private var offerControls: some View {
        VStack(spacing: 14) {
            // 目标方先看到发起人亮出的张数（金额保密）——还价的唯一线索。
            if !iAmInitiator, let count = state.dealOfferBillCount {
                VStack(spacing: 4) {
                    Text("\(state.playerName(for: state.dealInitiator)) 押了 \(count) 张钞票")
                        .font(.headline)
                        .foregroundStyle(Color.antiqueGold)
                    Text("金额保密——可能全是废钞，也可能都是大钞")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.antiqueGold.opacity(0.12))
                )
            }
            Text(iAmInitiator ? "你是发起人，请先押注" : "你是目标，请暗中还价")
                .font(.headline)
            Text(iAmInitiator
                 ? "对方将看到你押注的【张数】（看不到金额）后再还价。报价高者赢得该套系可换的古董；双方按各自报价互付金钱。废钞可凑张数虚张声势。"
                 : "报价高者赢得该套系可换的古董；双方按各自报价互付金钱。你的报价对方看不到。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            BillPicker(money: state.me.money, selection: $paid)

            Button {
                // 暗标提交：本地即时手感（成交结果由事件流发反馈）。
                Feedback.shared.bidPlaced()
                client.submitOffer(paid: paid)
                submitted = true
            } label: {
                Text("\(iAmInitiator ? "押注" : "提交暗标")（合计 \(paid.totalValue) · \(paid.totalCount) 张）")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: 2)
        )
        // 该你暗标：呼吸高亮强调。
        .pulseHighlight(active: true, color: .antiqueGold, cornerRadius: 12)
    }

    private var waitingForCounterpart: some View {
        VStack(spacing: 10) {
            ProgressView()
            if iAmInitiator, let count = state.dealOfferBillCount {
                Text("你已押 \(count) 张（对方只看得到张数）。等待对方还价…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("已提交报价，等待结算…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    /// 目标方等待发起人先押注。
    private var waitingForInitiator: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("等待 \(state.playerName(for: state.dealInitiator)) 先押注…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var bystanderView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text(state.dealInitiatorSubmitted
                 ? "一场私盘正在进行：\(state.playerName(for: state.dealInitiator)) 已押 \(state.dealOfferBillCount ?? 0) 张，等 \(state.playerName(for: state.dealTarget)) 还价…"
                 : "一场私盘正在进行：等 \(state.playerName(for: state.dealInitiator)) 先押注…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func setDisplayName(_ setId: String) -> String {
        if let card = state.me.antiques.first(where: { $0.setId == setId }) {
            return card.setName
        }
        for opp in state.opponents {
            if let card = opp.antiques.first(where: { $0.setId == setId }) {
                return card.setName
            }
        }
        return setId.isEmpty ? "—" : setId
    }
}
