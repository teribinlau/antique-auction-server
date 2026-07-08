// 新手指南:图文讲解玩法。"图"全部用游戏真实组件/样式现场渲染,
// 与实际界面一致,还能边看边点(试选钞)。连接页与等待室都可打开。

import { useState } from "react";
import type { Card } from "../protocol";
import { styleFor } from "../theme";
import { CardView } from "../components/CardView";

const DEMO_CARD: Card = {
  cardId: "seals_02",
  cardName: "田黄私印",
  flavorText: "确实是黄的，只不过更接近番薯黄。",
  setId: "seals",
  setName: "名家印玺",
  setScore: 160,
};

/** 静态钞票牌(指南演示用,可点击弹起) */
function DemoBills() {
  const bills = [
    { v: "50", c: "#2f6fb3" }, { v: "10", c: "#3f8a4f" }, { v: "10", c: "#3f8a4f" },
    { v: "废", c: "#73737c" }, { v: "废", c: "#73737c" },
  ];
  const [up, setUp] = useState<boolean[]>(bills.map(() => false));
  return (
    <div className="g-fan">
      {bills.map((b, i) => (
        <button
          key={i}
          className={`t-bill${up[i] ? " t-bill-up" : ""}`}
          style={{ left: i * 44, zIndex: i, width: 58, height: 78, color: b.c, position: "absolute" }}
          onClick={() => setUp((u) => u.map((x, j) => (j === i ? !x : x)))}
        >
          <span className="t-bill-corner">{b.v}</span>
          <span className="t-bill-main">{b.v}</span>
        </button>
      ))}
      <span className="g-fan-tip">👆 点点看:选中的钞票会弹起</span>
    </div>
  );
}

/** 盖牌押注演示 */
function DemoStake() {
  return (
    <div className="g-pile">
      {[0, 1, 2].map((i) => (
        <span key={i} className="t-stake-card"
          style={{ left: i * 15, zIndex: i, transform: `rotate(${((i * 7) % 5) - 2}deg)` }}>押</span>
      ))}
      <span className="g-pile-label">对方只见 <b>3 张</b>·面值保密</span>
    </div>
  );
}

/** 套系徽章演示 */
function DemoChips() {
  const sets = [
    { id: "lost_paintings", n: 2, done: false },
    { id: "seals", n: 4, done: true },
    { id: "paper_money", n: 1, done: false },
  ];
  return (
    <div className="g-chips">
      {sets.map((s) => {
        const st = styleFor(s.id);
        return (
          <span key={s.id} className="setchip"
            style={{ background: st.primary, borderColor: s.done ? "#d4a957" : "rgba(255,255,255,.15)" }}>
            <b>{st.glyph}</b> {st.name}<i>{s.n}张</i>{s.done && <em style={{ color: "#d4a957" }}>✓集齐</em>}
          </span>
        );
      })}
    </div>
  );
}

export function GuideView({ onClose }: { onClose: () => void }) {
  return (
    <div className="guide">
      <header className="guide-top">
        <span className="guide-title">📜 玩法指南</span>
        <button className="btn btn-ghost" onClick={onClose}>✕ 返回</button>
      </header>

      <div className="guide-body">
        <p className="guide-lead">
          《古董拍卖》是 2~5 人的<b>拍卖 + 诈唬</b>桌游:抢拍古董、私盘换牌,
          <b>集齐整套</b>才算分,现金一文不值——敢花、会唬,才是赢家。
        </p>

        <section className="guide-sec">
          <h3>① 目标:集齐套系</h3>
          <p>40 张古董 = 10 个套系 × 每套 4 张。<b>只有集齐 4 张的套系才计分</b>:</p>
          <div className="g-demo"><DemoChips /></div>
          <p className="g-formula">总分 =(集齐套系分值之和)×(套数)<br />
            <span>例:集齐「失传古画1000」+「名家印玺160」→ (1000+160) × 2 = <b>2320 分</b></span></p>
          <p className="hint">套系分值从 10 到 1000 分档;高分套人人抢,低分套凑数也翻倍。</p>
        </section>

        <section className="guide-sec">
          <h3>② 你的钞票:张数公开,面值保密</h3>
          <p>开局每人 2 张<b>废钞</b>(0 元)+ 4 张 10 + 1 张 50。
            对手<b>只能看到你有几张</b>,看不到面值——废钞就是用来<b>虚张声势</b>的。</p>
          <div className="g-demo"><DemoBills /></div>
        </section>

        <section className="guide-sec">
          <h3>③ 轮到你:二选一</h3>
          <p><b>🔨 开拍下一张</b>——翻开牌堆顶的古董,其他人竞价;<br />
            <b>⇄ 发起私盘</b>——与持有相同套系的对手暗标换牌。</p>
        </section>

        <section className="guide-sec">
          <h3>④ 拍卖与截拍</h3>
          <div className="g-demo g-demo-card"><CardView card={DEMO_CARD} /></div>
          <p>其他玩家<b>轮流加价或退出</b>(退出不可再回来)。出价<b>可以虚高诈唬</b>——
            但若最终成交你付不起,会<b>当众曝光你的全部钞票</b>,该牌流拍重拍。</p>
          <p>竞价结束后,<b>拍卖人有截拍权</b>:按最高价<b>自己买下</b>(钱付给出价者),
            或放手让出价者成交(钱归拍卖人)。<b>没人出价?古董白送拍卖人。</b></p>
          <p className="hint">🥈 特殊:每次翻开「官库银锭」,全员发钱(依次 +50/+100/+200/+500)——牌越往后越肥。</p>
        </section>

        <section className="guide-sec">
          <h3>⑤ 私盘:盖牌暗标</h3>
          <div className="g-demo"><DemoStake /></div>
          <p><b>发起人先押注</b>:选好钞票<b>盖着打到桌面</b>——对方只看到<b>张数</b>。<br />
            <b>对方盖牌还价</b>(金额互相保密)→ <b>报价高者</b>赢走对方该套系的牌(按双方持有的较小数换),
            双方<b>互付各自押注</b>。</p>
          <p className="hint">平局重新暗标;再平掷币定胜负。3 张废钞可以吓走 200 真金——也可能被 0 元白嫖,这就是心理战。</p>
        </section>

        <section className="guide-sec">
          <h3>⑥ 终局</h3>
          <p>牌堆抽空后进入<b>私盘决胜</b>:轮到的人必须发起私盘,
            直到所有套系各归其主、无人可交易——游戏结束,按公式计分,分高者胜。</p>
        </section>

        <section className="guide-sec guide-tips">
          <h3>⑦ 三条心法</h3>
          <p>💡 <b>废钞是武器</b>:押注张数唬人,真钱留给关键截拍;<br />
            💡 <b>盯住对手的套系徽章</b>:他差 1 张集齐时,那张卡就是天价;<br />
            💡 <b>现金不计分</b>:终局前把钱花光才是会玩。</p>
        </section>

        <button className="btn btn-primary btn-big" onClick={onClose}>明白了,开玩!</button>
      </div>
    </div>
  );
}
