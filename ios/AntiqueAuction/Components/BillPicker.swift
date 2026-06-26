import SwiftUI

/// 选钞器：从自己的 `money` 里挑选各面值张数，用于截拍付款与私盘暗标。
///
/// - 六个面值全部可见（含 "0" 废钞），每行显示「我有 N 张」并可加减。
/// - `selection` 是 `[String: Int]` 双向绑定（面值字符串 → 选中张数）。
/// - 可选 `minTotal`：当合计金额 < minTotal 时，调用方应禁用提交（`isValid` 计算出）。
/// - 实时显示合计金额与合计张数。
///
/// 注意："0" 面值不贡献金额（废钞），但贡献张数——用于诈唬时凑张数。
struct BillPicker: View {
    /// 我拥有的钞票（各面值上限）。
    let money: Money
    /// 选中结果（双向绑定）。
    @Binding var selection: Money
    /// 可选最小合计金额（如截拍须 ≥ highestBid）。nil 表示无下限。
    var minTotal: Int? = nil

    /// 当前选中合计金额。
    private var selectedTotal: Int { selection.totalValue }
    /// 当前选中合计张数。
    private var selectedCount: Int { selection.totalCount }

    /// 是否满足提交条件（达到 minTotal）。供调用方决定按钮可用性。
    var isValid: Bool {
        guard let minTotal else { return true }
        return selectedTotal >= minTotal
    }

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Denomination.all, id: \.self) { face in
                billRow(face: face)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("合计金额")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(selectedTotal)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(isValid ? Color.primary : Color.red)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("合计张数")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(selectedCount)")
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
            }

            if let minTotal, !isValid {
                Text("还需 \(minTotal - selectedTotal) 才能达到底价 \(minTotal)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func billRow(face: Int) -> some View {
        let key = String(face)
        let owned = money[key] ?? 0
        let picked = selection[key] ?? 0

        HStack(spacing: 12) {
            // 面值标签（0 标注为「废钞」）。
            VStack(alignment: .leading, spacing: 1) {
                Text(face == 0 ? "废钞" : "\(face)")
                    .font(.headline.monospacedDigit())
                Text("持有 \(owned)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 80, alignment: .leading)

            Spacer()

            Stepper(
                value: Binding(
                    get: { selection[key] ?? 0 },
                    set: { newValue in
                        // 夹在 [0, owned] 区间内。
                        let clamped = max(0, min(newValue, owned))
                        // 仅当实际发生变化时给一次轻触感（避免到达上下限仍触发）。
                        if clamped != picked { Feedback.shared.selectTick() }
                        if clamped == 0 {
                            selection[key] = nil
                        } else {
                            selection[key] = clamped
                        }
                    }
                ),
                in: 0...max(0, owned)
            ) {
                Text("\(picked) 张")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 56, alignment: .trailing)
            }
            .disabled(owned == 0)
            // 选钞行带轻微缩放反馈（picked 变化时）。
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: picked)
        }
        .opacity(owned == 0 ? 0.45 : 1)
    }
}

#if DEBUG
private struct BillPickerPreviewHost: View {
    @State private var sel: Money = [:]
    var body: some View {
        BillPicker(
            money: ["0": 2, "10": 4, "50": 1, "100": 1, "200": 0, "500": 1],
            selection: $sel,
            minTotal: 150
        )
        .padding()
    }
}

struct BillPicker_Previews: PreviewProvider {
    static var previews: some View {
        BillPickerPreviewHost()
    }
}
#endif
