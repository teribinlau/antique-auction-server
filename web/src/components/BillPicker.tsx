// 选钞器：按面值 +/- 选择要支付的钞票（截拍付款 / 私盘暗标共用）。
// 上限 = 我实际持有的张数;"0" 是废钞（凑张数不值钱，可用于诈唬性支付结构）。

import { DENOMS, moneyCount, moneyTotal, type Denom, type Money } from "../protocol";

export function BillPicker({
  owned, picked, onChange,
}: {
  owned: Money;
  picked: Money;
  onChange: (next: Money) => void;
}) {
  const setCount = (d: Denom, next: number) => {
    const max = owned[d] ?? 0;
    const clamped = Math.max(0, Math.min(max, next));
    onChange({ ...picked, [d]: clamped });
    if (navigator.vibrate) navigator.vibrate(8);
  };

  return (
    <div className="billpicker">
      {DENOMS.map((d) => {
        const have = owned[d] ?? 0;
        const sel = picked[d] ?? 0;
        return (
          <div className={`bill-row${have === 0 ? " bill-row-empty" : ""}`} key={d}>
            <span className="bill-denom">{d === "0" ? "废钞" : d}</span>
            <span className="bill-have">持有 {have}</span>
            <div className="bill-stepper">
              <button className="stepbtn" disabled={sel <= 0} onClick={() => setCount(d, sel - 1)}>−</button>
              <span className="bill-sel">{sel}</span>
              <button className="stepbtn" disabled={sel >= have} onClick={() => setCount(d, sel + 1)}>＋</button>
            </div>
          </div>
        );
      })}
      <div className="bill-total">
        <span>合计金额 <b>{moneyTotal(picked)}</b></span>
        <span>合计张数 <b>{moneyCount(picked)}</b></span>
      </div>
    </div>
  );
}
