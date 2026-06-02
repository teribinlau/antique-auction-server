import SwiftUI

/// 私盘阶段。发起人与目标各暗标一次 submit_deal_offer{paid}：
///  - 出价高者赢，按各自报价互付金钱，赢家拿走双方该套系可换的牌。
///  - 平局会重标；连续两次平局则掷币定赢家（deal_resolved.tieForcedWinner）。
/// 非当事人只看进度提示。
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

    var body: some View {
        VStack(spacing: 16) {
            header

            if iAmParticipant {
                if submitted {
                    waitingForCounterpart
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

    // ── 报价控件 ─────────────────────────────────────────────
    private var offerControls: some View {
        VStack(spacing: 14) {
            Text(iAmInitiator ? "你是发起人，请暗标报价" : "你是目标，请暗标报价")
                .font(.headline)
            Text("报价高者赢得该套系可换的古董；双方按各自报价互付金钱。报价对对方保密。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            BillPicker(money: state.me.money, selection: $paid)

            Button {
                client.submitOffer(paid: paid)
                submitted = true
            } label: {
                Text("提交暗标（合计 \(paid.totalValue)）")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: 2)
        )
    }

    private var waitingForCounterpart: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("已提交报价，等待对方暗标…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var bystanderView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("一场私盘正在进行：\(state.playerName(for: state.dealInitiator)) 与 \(state.playerName(for: state.dealTarget)) 暗标交易中…")
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
