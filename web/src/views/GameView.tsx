// 游戏主界面：按 phase 路由到 拍卖 / 截拍 / 私盘 / 结算。
// 布局(移动优先)：顶栏 → 对手区 → 主面板 → 我的手牌(钞票+古董)。

import { useEffect, useMemo, useState } from "react";
import { client, type Snapshot } from "../client";
import { DENOMS, moneyCount, moneyTotal, type GameStateView, type Money } from "../protocol";
import { GOLD, styleFor } from "../theme";
import { BillPicker } from "../components/BillPicker";
import { CardRow, CardView } from "../components/CardView";
import { OpponentPanel } from "../components/OpponentPanel";

const PHASE_LABEL: Record<string, string> = {
  AUCTION: "拍卖", SNIPE: "截拍", PRIVATE_DEAL: "私盘", GAME_OVER: "结算", WAITING: "等待",
};

function nameOf(state: GameStateView, id: number): string {
  if (id === state.me.playerId) return state.me.playerName;
  return state.opponents.find((o) => o.playerId === id)?.playerName ?? `玩家${id + 1}`;
}

export function GameView({ snap }: { snap: Snapshot }) {
  const state = snap.state!;
  const myTurn = state.currentPlayerId === state.me.playerId;

  return (
    <div className="page page-game">
      <header className="topbar topbar-game">
        <span className="chip chip-mini">🚩 {PHASE_LABEL[state.phase] ?? state.phase}</span>
        {snap.roomCode && (
          <button
            className="chip chip-mini chip-code"
            onClick={() => {
              navigator.clipboard?.writeText(snap.roomCode!).then(
                () => client.toast(`房号 ${snap.roomCode} 已复制`),
                () => client.toast(`房号:${snap.roomCode}`),
              );
            }}
          >
            🔑 {snap.roomCode}
          </button>
        )}
        <span className="chip chip-mini">🂠 牌堆 {state.deckSize}</span>
        {state.silverIngotCount > 0 && <span className="chip chip-mini">🥈 白银 {state.silverIngotCount}</span>}
        <span className="topbar-actor">
          {myTurn
            ? <span className="chip chip-gold">轮到你</span>
            : <>行动:{nameOf(state, state.currentPlayerId)}</>}
        </span>
      </header>

      <section className="sect">
        <h3>对手</h3>
        {state.opponents.map((o) => (
          <OpponentPanel
            key={o.playerId}
            opponent={o}
            highlighted={snap.currentBidderId === o.playerId}
            disconnected={snap.disconnectedIds.includes(o.playerId)}
          />
        ))}
      </section>

      <MainPanel snap={snap} />

      <MyHand snap={snap} />

      {(snap.conn !== "connected") && state.phase !== "GAME_OVER" && (
        <div className="overlay">
          <div className="overlay-box">
            <div className="spin" />
            <p>连接断开,自动重连中…</p>
          </div>
        </div>
      )}
    </div>
  );
}

// ── 主面板(按阶段) ─────────────────────────────────────────
function MainPanel({ snap }: { snap: Snapshot }) {
  const state = snap.state!;
  switch (state.phase) {
    case "AUCTION": return <AuctionPanel snap={snap} />;
    case "SNIPE": return <SnipePanel snap={snap} />;
    case "PRIVATE_DEAL": return <DealPanel snap={snap} />;
    case "GAME_OVER": return <GameOverPanel snap={snap} />;
    default: return null;
  }
}

// ── 拍卖阶段 ────────────────────────────────────────────────
function AuctionPanel({ snap }: { snap: Snapshot }) {
  const state = snap.state!;
  const me = state.me.playerId;
  const myTurn = state.currentPlayerId === me;
  const card = state.auctionCard;

  // 出价额:最低 = 最高价+10,步进 10
  const minBid = state.highestBid + 10;
  const [amount, setAmount] = useState(minBid);
  useEffect(() => { setAmount(state.highestBid + 10); }, [state.highestBid, card?.cardId]);

  const [showTargets, setShowTargets] = useState(false);

  if (!card) {
    // 未开拍:当前玩家选择行动
    if (!myTurn) {
      return (
        <section className="sect mainpanel">
          <div className="waiting"><div className="spin" /><p>等待 {nameOf(state, state.currentPlayerId)} 选择行动…</p></div>
        </section>
      );
    }
    const endgame = state.deckSize === 0;
    return (
      <section className="sect mainpanel actionbox">
        <h2 className="gold-title">{endgame ? "私盘决胜·轮到你" : "轮到你了·请选择行动"}</h2>
        <p className="hint">
          {endgame
            ? "牌堆已空:与持有相同套系的对手发起私盘。直到所有套系各归其主、无人可交易,游戏才结束。"
            : "开拍一张新古董,或与持有相同套系的对手发起私盘。"}
        </p>
        {!endgame && (
          <button className="btn btn-primary btn-big" onClick={() => client.startAuction()}>
            🔨 开拍下一张
          </button>
        )}
        <button
          className={`btn btn-big ${endgame ? "btn-primary" : "btn-gold"}`}
          onClick={() => { client.getDealTargets(); setShowTargets(true); }}
        >
          ⇄ 发起私盘
        </button>
        {showTargets && (
          <TargetSheet snap={snap} onClose={() => setShowTargets(false)} />
        )}
      </section>
    );
  }

  // 竞拍中
  const iAmAuctioneer = state.currentPlayerId === me;
  const myBidTurn = snap.currentBidderId === me && !iAmAuctioneer;
  return (
    <section className="sect mainpanel">
      <div className="auction-card"><CardView card={card} /></div>
      <div className="bidline">
        {state.highestBid > 0
          ? <>最高价 <b className="bid-amount">{state.highestBid}</b>({nameOf(state, state.highestBidder)})</>
          : <>尚无人出价</>}
      </div>
      {iAmAuctioneer && (
        <p className="hint">你是拍卖人——等待他人出价;竞价结束后你可以选择截拍。</p>
      )}
      {myBidTurn ? (
        <div className="bidbox">
          <div className="bid-stepper">
            <button className="stepbtn" disabled={amount - 10 < minBid} onClick={() => setAmount(amount - 10)}>−10</button>
            <span className="bid-now">{amount}</span>
            <button className="stepbtn" onClick={() => setAmount(amount + 10)}>+10</button>
            <button className="stepbtn" onClick={() => setAmount(amount + 100)}>+100</button>
          </div>
          <div className="btnrow">
            <button className="btn btn-primary" onClick={() => client.placeBid(amount)}>出价 {amount}</button>
            <button className="btn btn-ghost" onClick={() => client.passBid()}>退出竞拍</button>
          </div>
          <p className="hint">出价可以虚高(诈唬)——但若你最终成交,付不起会当众曝光你的全部家底。</p>
        </div>
      ) : (
        !iAmAuctioneer && (
          <div className="waiting-sm">
            {snap.currentBidderId !== null
              ? <>等待 {nameOf(state, snap.currentBidderId)} 出价…</>
              : <>等待竞价推进…</>}
          </div>
        )
      )}
    </section>
  );
}

// 私盘目标选择(半屏面板)
function TargetSheet({ snap, onClose }: { snap: Snapshot; onClose: () => void }) {
  const state = snap.state!;
  return (
    <div className="sheet-mask" onClick={onClose}>
      <div className="sheet" onClick={(e) => e.stopPropagation()}>
        <h3>发起私盘</h3>
        {snap.dealTargets.length === 0 ? (
          <p className="hint">你和对手没有相同套系的古董可换。</p>
        ) : (
          snap.dealTargets.map((t) => {
            const st = styleFor(t.setId);
            return (
              <button
                key={`${t.setId}-${t.targetId}`}
                className="roomrow"
                onClick={() => { client.startDeal(t.targetId, t.setId); onClose(); }}
              >
                <span className="setchip" style={{ background: st.primary }}><b>{st.glyph}</b> {st.name}</span>
                <span className="roomrow-name">对手:{nameOf(state, t.targetId)}</span>
                <span className="roomrow-count">可换 {t.tradeCount} 张</span>
              </button>
            );
          })
        )}
        <button className="btn btn-ghost" onClick={onClose}>取消</button>
      </div>
    </div>
  );
}

// ── 截拍阶段 ────────────────────────────────────────────────
function SnipePanel({ snap }: { snap: Snapshot }) {
  const state = snap.state!;
  const me = state.me.playerId;
  const iAmAuctioneer = state.currentPlayerId === me;
  const card = snap.snipePrompt?.card ?? state.auctionCard;
  const need = snap.snipePrompt?.highestBid ?? state.highestBid;
  const [paid, setPaid] = useState<Money>({});
  const total = moneyTotal(paid);

  if (!iAmAuctioneer) {
    return (
      <section className="sect mainpanel">
        {card && <div className="auction-card"><CardView card={card} /></div>}
        <div className="waiting"><div className="spin" /><p>成交价 {need} —— 等待拍卖人抉择:截拍付款,还是放手…</p></div>
      </section>
    );
  }
  return (
    <section className="sect mainpanel actionbox">
      <h2 className="gold-title">截拍抉择</h2>
      <p className="hint">
        最高出价 <b>{need}</b>({nameOf(state, snap.snipePrompt?.highestBidder ?? state.highestBidder)})。
        你可以按此价<b>自己买下</b>这张古董(钱付给出价者),或放手让其成交。
      </p>
      {card && <div className="auction-card auction-card-sm"><CardView card={card} /></div>}
      <BillPicker owned={state.me.money} picked={paid} onChange={setPaid} />
      <div className="btnrow">
        <button className="btn btn-primary" disabled={total < need} onClick={() => client.snipe(true, paid)}>
          💰 截拍付款({total})
        </button>
        <button className="btn btn-ghost" onClick={() => client.snipe(false)}>放手给出价者</button>
      </div>
      {total < need && <p className="hint">已选 {total},还差 {need - total}(可多付,不找零)。</p>}
    </section>
  );
}

// ── 私盘阶段(顺序流:发起人先押注 → 目标看到张数再暗标) ──────
function DealPanel({ snap }: { snap: Snapshot }) {
  const state = snap.state!;
  const me = state.me.playerId;
  const iAmInitiator = me === state.dealInitiator;
  const iAmTarget = me === state.dealTarget;
  const other = iAmInitiator ? state.dealTarget : state.dealInitiator;
  const st = styleFor(state.dealSetId);
  const [paid, setPaid] = useState<Money>({});
  const iniSubmitted = !!state.dealInitiatorSubmitted;
  const meSubmitted = snap.dealSubmittedByMe || (iAmInitiator ? iniSubmitted : !!state.dealTargetSubmitted);
  const billCount = state.dealOfferBillCount;

  // 围观者:显示进度
  if (!iAmInitiator && !iAmTarget) {
    return (
      <section className="sect mainpanel">
        <div className="waiting">
          <div className="spin" />
          <p>
            {nameOf(state, state.dealInitiator)} 与 {nameOf(state, state.dealTarget)} 正在
            「{st.name}」私盘中…
            {iniSubmitted
              ? `发起人已押 ${billCount ?? "?"} 张,等对方暗标`
              : "等发起人押注"}
          </p>
        </div>
      </section>
    );
  }

  // 我已提交 → 等待
  if (meSubmitted) {
    return (
      <section className="sect mainpanel">
        <div className="waiting">
          <div className="spin" />
          <p>
            {iAmInitiator && billCount != null && <>你已押 {billCount} 张(对方只看得到张数)。</>}
            等待 {nameOf(state, other)}…
          </p>
        </div>
      </section>
    );
  }

  // 目标方:发起人还没押 → 等
  if (iAmTarget && !iniSubmitted) {
    return (
      <section className="sect mainpanel">
        <div className="waiting"><div className="spin" /><p>等待 {nameOf(state, other)} 先押注…</p></div>
      </section>
    );
  }

  // 轮到我报价(发起人先手 / 目标看到张数后还价)
  return (
    <section className="sect mainpanel actionbox">
      <h2 className="gold-title">私盘暗标 ·「{st.name}」</h2>
      {iAmTarget && (
        <div className="deal-reveal">
          {nameOf(state, other)} 押了 <b>{billCount ?? 0} 张</b>钞票
          <span className="deal-reveal-sub">金额保密——可能全是废钞,也可能都是大钞</span>
        </div>
      )}
      <p className="hint">
        {iAmInitiator ? (
          <>
            你先押注,对方将看到你的<b>张数</b>(看不到金额)后再暗标。
            <b>报价高者赢得对方的「{st.name}」</b>,双方按各自报价互付金钱。废钞可凑张数虚张声势。
          </>
        ) : (
          <>
            暗中还价:<b>报价高者赢得对方的「{st.name}」</b>,双方按各自报价互付金钱。
            你的报价对方看不到。
          </>
        )}
      </p>
      <BillPicker owned={state.me.money} picked={paid} onChange={setPaid} />
      <button className="btn btn-primary btn-big" onClick={() => client.submitOffer(paid)}>
        🤝 {iAmInitiator ? "押注" : "提交暗标"}({moneyTotal(paid)} / {moneyCount(paid)} 张)
      </button>
    </section>
  );
}

// ── 结算 ────────────────────────────────────────────────────
function GameOverPanel({ snap }: { snap: Snapshot }) {
  const state = snap.state!;
  const scores = snap.gameOverScores ?? [];
  return (
    <section className="sect mainpanel actionbox">
      <h2 className="gold-title">🏆 游戏结束</h2>
      <div className="scores">
        {scores.map((s, i) => (
          <div key={s.playerId} className={`scorerow${i === 0 ? " scorerow-win" : ""}`}>
            <span className="score-rank">{["🥇", "🥈", "🥉"][i] ?? `${i + 1}.`}</span>
            <span className="score-name">
              {s.playerName}{s.playerId === state.me.playerId && "(你)"}
            </span>
            <b className="score-val">{s.score}</b>
          </div>
        ))}
      </div>
      <p className="hint">
        牌堆抽尽且所有套系已各归其主(无私盘可发)——对局结束。
        得分 =(各集齐套系分值之和)× 套数;现金不计分。
      </p>
      <button className="btn btn-primary btn-big" onClick={() => client.leaveRoom()}>返回大厅</button>
    </section>
  );
}

// ── 我的手牌 ────────────────────────────────────────────────
function MyHand({ snap }: { snap: Snapshot }) {
  const state = snap.state!;
  const m = state.me.money;
  const total = useMemo(() => moneyTotal(m), [m]);
  const count = useMemo(() => moneyCount(m), [m]);
  return (
    <>
      <section className="sect">
        <h3>我的手牌</h3>
        <div className="moneytable">
          {DENOMS.map((d) => (
            <div className={`moneyrow${(m[d] ?? 0) === 0 ? " moneyrow-zero" : ""}`} key={d}>
              <span>{d === "0" ? "废钞" : d}</span>
              <b>{m[d] ?? 0} 张</b>
            </div>
          ))}
          <div className="moneyrow moneyrow-total">
            <span>总计</span>
            <b style={{ color: GOLD }}>{total}({count} 张)</b>
          </div>
        </div>
      </section>
      <section className="sect">
        <h3>我的古董({state.me.antiques.length} 件)</h3>
        {state.me.antiques.length === 0 ? (
          <p className="hint">尚无古董</p>
        ) : (
          state.me.antiques.map((c, i) => (
            <CardRow key={`${c.cardId}-${i}`} card={c} inCompleteSet={state.me.completeSets.includes(c.setId)} />
          ))
        )}
      </section>
    </>
  );
}
