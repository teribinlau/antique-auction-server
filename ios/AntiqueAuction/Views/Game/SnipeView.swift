import SwiftUI

/// 截拍阶段。仅拍卖人（当前行动玩家）行动：
///  - 截拍：自己掏钱 ≥ highestBid 买下这张（用 BillPicker 选钞，付给最高出价者）。
///  - 放手：让最高出价者按其出价自动付款拿牌。
/// 其他玩家只看提示，等待结果。
struct SnipeView: View {
    @ObservedObject var client: GameClient
    let state: GameView

    @State private var paid: Money = [:]

    private var iAmAuctioner: Bool { state.iAmAuctioner }
    /// 选中合计是否达到底价（与 BillPicker 内部判定同口径）。
    private var paidIsValid: Bool { paid.totalValue >= state.highestBid }

    var body: some View {
        VStack(spacing: 16) {
            if let card = state.auctionCard {
                CardView(card: card)
                    .frame(maxWidth: 240)
            }

            HStack {
                Text("最高出价")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(state.highestBid) · \(state.playerName(for: state.highestBidder))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
            )

            if iAmAuctioner {
                auctioneerSnipeControls
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("拍卖人 \(state.playerName(for: state.currentPlayerId)) 正在决定是否截拍…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var auctioneerSnipeControls: some View {
        VStack(spacing: 14) {
            Text("是否截拍？")
                .font(.headline)
            Text("截拍：你支付不低于 \(state.highestBid) 买下此牌（付给出价者）；放手：让出价者拿牌。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // 选钞付款（仅截拍需要）。
            BillPicker(money: state.me.money, selection: $paid, minTotal: state.highestBid)

            HStack(spacing: 12) {
                Button {
                    client.snipe(doSnipe: true, paid: paid)
                } label: {
                    Text("截拍买下")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(paidIsValid ? Color.accentColor : Color.gray)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!paidIsValid)

                Button {
                    client.snipe(doSnipe: false, paid: nil)
                } label: {
                    Text("放手")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if state.me.money.totalValue < state.highestBid {
                Text("你的现金不足以截拍，建议放手。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: 2)
        )
        // 该你决定是否截拍：呼吸高亮强调。
        .pulseHighlight(active: true, color: .antiqueGold, cornerRadius: 12)
    }
}
