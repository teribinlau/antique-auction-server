// 牌桌横屏版(斗地主式)。与经典版共用同一个 GameClient/协议层,只换呈现:
//  - 手机竖持时整体旋转 90°(H5 棋牌standard做法),始终横屏体验;
//  - 对手围坐上沿(头像+钞票张数+套系徽章),中央是拍卖台;
//  - 底部两手扇形牌:上排【古董手牌】(点开大图),下排【资金手牌】(每张钞票=一张牌);
//  - 截拍付款/私盘押注 = 点钞票牌弹起选中(斗地主选牌交互),凑够按确认。

import { useEffect, useMemo, useRef, useState } from "react";
import { client, type Snapshot } from "../../client";
import {
  DENOMS, moneyCount, moneyTotal,
  type Card, type Denom, type GameStateView, type Money,
} from "../../protocol";
import { GOLD, RARITY_ACCENT, cardArtUrl, cardRarity, isElevated, styleFor } from "../../theme";
import { CardView } from "../../components/CardView";
import { BannerStack } from "../../components/Banner";

const PHASE_LABEL: Record<string, string> = {
  AUCTION: "拍卖", SNIPE: "截拍", PRIVATE_DEAL: "私盘", GAME_OVER: "结算", WAITING: "等待",
};
const BILL_COLOR: Record<Denom, string> = {
  "0": "#73737c", "10": "#3f8a4f", "50": "#2f6fb3", "100": "#7a4fb3", "200": "#c05a4a", "500": "#b8860b",
};
const SEAT_HUES = ["#7a4fb3", "#2f6fb3", "#3f8a4f", "#c05a4a", "#b8860b"];

function nameOf(state: GameStateView, id: number): string {
  if (id === state.me.playerId) return state.me.playerName;
  return state.opponents.find((o) => o.playerId === id)?.playerName ?? `玩家${id + 1}`;
}

function useViewport() {
  const [s, set] = useState({ w: window.innerWidth, h: window.innerHeight });
  useEffect(() => {
    const on = () => set({ w: window.innerWidth, h: window.innerHeight });
    window.addEventListener("resize", on);
    window.addEventListener("orientationchange", on);
    return () => { window.removeEventListener("resize", on); window.removeEventListener("orientationchange", on); };
  }, []);
  return s;
}

/** 扇形排布:测容器宽,算每张牌的步进(重叠),保证一行放得下 */
function useFanStep(count: number, cardW: number, maxStep: number) {
  const ref = useRef<HTMLDivElement>(null);
  const [step, setStep] = useState(maxStep);
  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const calc = () => {
      const avail = el.clientWidth;
      setStep(count <= 1 ? maxStep : Math.max(14, Math.min(maxStep, (avail - cardW) / (count - 1))));
    };
    calc();
    const ro = new ResizeObserver(calc);
    ro.observe(el);
    return () => ro.disconnect();
  }, [count, cardW, maxStep]);
  return { ref, step };
}

export function TableGameView({ snap }: { snap: Snapshot }) {
  const state = snap.state!;
  const { w, h } = useViewport();
  const portrait = h > w;
  const [preview, setPreview] = useState<Card | null>(null);
  const [picked, setPicked] = useState<Money>({});

  const me = state.me.playerId;
  const myTurn = state.currentPlayerId === me;
  const iAmInitiator = me === state.dealInitiator;
  const iAmTarget = me === state.dealTarget;
  const iniSubmitted = !!state.dealInitiatorSubmitted;
  const mySubmitted = snap.dealSubmittedByMe ||
    (iAmInitiator ? iniSubmitted : iAmTarget ? !!state.dealTargetSubmitted : false);

  // 什么时候允许「点钞票选牌」:截拍付款(我是拍卖人) / 私盘轮到我押注
  const selecting =
    (state.phase === "SNIPE" && myTurn) ||
    (state.phase === "PRIVATE_DEAL" && !mySubmitted &&
      (iAmInitiator || (iAmTarget && iniSubmitted)));

  // 场景切换时清空选牌;资金变动时钳位
  const ctxKey = `${state.phase}|${state.auctionCard?.cardId ?? ""}|${state.dealSetId}|${mySubmitted}`;
  useEffect(() => { setPicked({}); }, [ctxKey]);
  useEffect(() => {
    setPicked((p) => {
      const next: Money = {};
      for (const d of DENOMS) {
        const k = Math.min(p[d] ?? 0, state.me.money[d] ?? 0);
        if (k > 0) next[d] = k;
      }
      return next;
    });
  }, [state.me.money]);

  const toggleBill = (d: Denom, raised: boolean) => {
    if (!selecting) return;
    setPicked((p) => {
      const cur = p[d] ?? 0;
      const max = state.me.money[d] ?? 0;
      const k = raised ? cur - 1 : Math.min(max, cur + 1);
      const next = { ...p };
      if (k <= 0) delete next[d]; else next[d] = k;
      return next;
    });
    if (navigator.vibrate) navigator.vibrate(8);
  };

  const rootStyle = portrait
    ? { width: h, height: w }
    : undefined;

  return (
    <div className={`table-root${portrait ? " table-rotated" : ""}`} style={rootStyle}>
      <BannerStack banners={snap.banners} />

      {/* 顶栏 */}
      <header className="t-top">
        <span className="chip chip-mini">🚩 {PHASE_LABEL[state.phase] ?? state.phase}</span>
        {snap.roomCode && (
          <button
            className="chip chip-mini chip-code"
            onClick={() => navigator.clipboard?.writeText(snap.roomCode!).then(
              () => client.toast(`房号 ${snap.roomCode} 已复制`),
              () => client.toast(`房号:${snap.roomCode}`),
            )}
          >🔑 {snap.roomCode}</button>
        )}
        <span className="chip chip-mini">🂠 {state.deckSize}</span>
        {state.silverIngotCount > 0 && <span className="chip chip-mini">🥈 {state.silverIngotCount}</span>}
        <span className="t-top-space" />
        <button className="chip chip-mini" onClick={() => client.setUiMode("classic")}>📱 竖屏版</button>
      </header>

      {/* 对手席 */}
      <div className="t-seats">
        {state.opponents.map((o) => {
          const groups = new Map<string, { name: string; glyph: string; color: string; n: number; done: boolean; score: number }>();
          for (const c of o.antiques) {
            const st = styleFor(c.setId);
            const g = groups.get(c.setId) ?? { name: st.name, glyph: st.glyph, color: st.primary, n: 0, done: o.completeSets.includes(c.setId), score: c.setScore };
            g.n++; groups.set(c.setId, g);
          }
          const actor = state.currentPlayerId === o.playerId && state.phase !== "GAME_OVER";
          const bidding = snap.currentBidderId === o.playerId;
          const off = snap.disconnectedIds.includes(o.playerId);
          return (
            <div key={o.playerId} className={`t-seat${actor ? " t-seat-actor" : ""}${bidding ? " t-seat-bidding" : ""}`}>
              <div className="t-avatar" style={{ background: SEAT_HUES[o.playerId % SEAT_HUES.length] }}>
                {o.playerName.slice(0, 1)}
                {off && <span className="t-off">离</span>}
              </div>
              <div className="t-seat-info">
                <div className="t-seat-name">
                  {o.playerName}
                  {bidding && <em className="t-tag-bid">出价中</em>}
                  {actor && !bidding && <em className="t-tag-act">行动</em>}
                </div>
                <div className="t-seat-money">🂠×{o.handCount}</div>
                <div className="t-seat-sets">
                  {[...groups.values()].sort((a, b) => b.score - a.score).map((g) => (
                    <span key={g.name} className="t-setchip" style={{ background: g.color, borderColor: g.done ? GOLD : "transparent" }}>
                      {g.glyph}{g.n}{g.done ? "✓" : ""}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* 中央舞台 */}
      <CenterStage snap={snap} picked={picked} onClearPicked={() => setPicked({})} />

      {/* 我的区域:古董手牌 + 资金手牌 */}
      <div className="t-mine">
        <div className="t-mine-head">
          <span className="t-mine-name">
            {state.me.playerName}
            {myTurn && state.phase !== "GAME_OVER" && <em className="t-tag-act">轮到你</em>}
          </span>
          <span className="t-mine-total">
            💰 {moneyTotal(state.me.money)}({moneyCount(state.me.money)} 张)
            {selecting && moneyCount(picked) > 0 && (
              <b style={{ color: GOLD }}> 已选 {moneyTotal(picked)}·{moneyCount(picked)}张</b>
            )}
          </span>
        </div>
        <AntiqueFan state={state} onPreview={setPreview} />
        <MoneyFan money={state.me.money} picked={picked} selecting={selecting} onToggle={toggleBill} />
      </div>

      {/* 大图预览 */}
      {preview && (
        <div className="sheet-mask" onClick={() => setPreview(null)}>
          <div className="t-preview" onClick={(e) => e.stopPropagation()}>
            <CardView card={preview} inCompleteSet={state.me.completeSets.includes(preview.setId)} />
            <button className="btn btn-ghost" onClick={() => setPreview(null)}>收起</button>
          </div>
        </div>
      )}

      {/* 断线遮罩 */}
      {snap.conn !== "connected" && state.phase !== "GAME_OVER" && (
        <div className="overlay">
          <div className="overlay-box"><div className="spin" /><p>连接断开,自动重连中…</p></div>
        </div>
      )}
    </div>
  );
}

// ── 中央舞台(按阶段) ────────────────────────────────────────
function CenterStage({ snap, picked, onClearPicked }: {
  snap: Snapshot; picked: Money; onClearPicked: () => void;
}) {
  const state = snap.state!;
  const me = state.me.playerId;
  const myTurn = state.currentPlayerId === me;
  const card = state.auctionCard;
  const minBid = state.highestBid + 10;
  const [amount, setAmount] = useState(minBid);
  useEffect(() => { setAmount(state.highestBid + 10); }, [state.highestBid, card?.cardId]);
  const [showTargets, setShowTargets] = useState(false);

  // 结算
  if (state.phase === "GAME_OVER") {
    const scores = snap.gameOverScores ?? [];
    return (
      <div className="t-stage">
        <div className="t-gameover">
          <h2 className="gold-title">🏆 游戏结束</h2>
          {scores.map((s, i) => (
            <div key={s.playerId} className={`scorerow${i === 0 ? " scorerow-win" : ""}`}>
              <span className="score-rank">{["🥇", "🥈", "🥉"][i] ?? `${i + 1}.`}</span>
              <span className="score-name">{s.playerName}{s.playerId === me && "(你)"}</span>
              <b className="score-val">{s.score}</b>
            </div>
          ))}
          <button className="btn btn-primary" onClick={() => client.leaveRoom()}>返回大厅</button>
        </div>
      </div>
    );
  }

  // 私盘
  if (state.phase === "PRIVATE_DEAL") {
    const st = styleFor(state.dealSetId);
    const iAmInitiator = me === state.dealInitiator;
    const iAmTarget = me === state.dealTarget;
    const other = iAmInitiator ? state.dealTarget : state.dealInitiator;
    const iniSubmitted = !!state.dealInitiatorSubmitted;
    const mySubmitted = snap.dealSubmittedByMe ||
      (iAmInitiator ? iniSubmitted : iAmTarget ? !!state.dealTargetSubmitted : false);
    const count = state.dealOfferBillCount;

    let body: JSX.Element;
    if (!iAmInitiator && !iAmTarget) {
      body = <p className="t-wait">{nameOf(state, state.dealInitiator)} ⇄ {nameOf(state, state.dealTarget)}
        「{st.name}」私盘中…{iniSubmitted ? `发起人已押 ${count ?? "?"} 张` : "等发起人押注"}</p>;
    } else if (mySubmitted) {
      body = <p className="t-wait">已提交,等待 {nameOf(state, other)}…</p>;
    } else if (iAmTarget && !iniSubmitted) {
      body = <p className="t-wait">等待 {nameOf(state, other)} 先押注…</p>;
    } else {
      body = (
        <>
          {iAmTarget && (
            <p className="t-reveal">{nameOf(state, other)} 押了 <b>{count ?? 0} 张</b>(金额保密)</p>
          )}
          <p className="t-hint">👇 点下方钞票牌选择{iAmInitiator ? "押注" : "还价"}——报价高者赢「{st.name}」;废钞可凑张数虚张声势</p>
          <div className="t-btnrow">
            <button className="btn btn-primary" onClick={() => { client.submitOffer(picked); onClearPicked(); }}>
              🤝 {iAmInitiator ? "押注" : "提交暗标"}({moneyTotal(picked)}·{moneyCount(picked)}张)
            </button>
          </div>
        </>
      );
    }
    return <div className="t-stage"><div className="t-panel"><h3 className="t-title">私盘 ·「{st.name}」</h3>{body}</div></div>;
  }

  // 截拍
  if (state.phase === "SNIPE") {
    const need = snap.snipePrompt?.highestBid ?? state.highestBid;
    const bidderName = nameOf(state, snap.snipePrompt?.highestBidder ?? state.highestBidder);
    const total = moneyTotal(picked);
    return (
      <div className="t-stage t-stage-row">
        {card && <div className="t-card"><CardView card={card} /></div>}
        <div className="t-panel">
          {myTurn ? (
            <>
              <h3 className="t-title">截拍抉择 · 成交价 {need}({bidderName})</h3>
              <p className="t-hint">👇 点下方钞票牌凑 ≥{need} 可自己买下(付给出价者);或放手让其成交</p>
              <div className="t-btnrow">
                <button className="btn btn-primary" disabled={total < need}
                  onClick={() => { client.snipe(true, picked); onClearPicked(); }}>
                  💰 截拍付款({total})
                </button>
                <button className="btn btn-ghost" onClick={() => client.snipe(false)}>放手给出价者</button>
              </div>
            </>
          ) : (
            <p className="t-wait">成交价 {need}——等拍卖人抉择:截拍还是放手…</p>
          )}
        </div>
      </div>
    );
  }

  // 拍卖:未开拍(选择行动)
  if (!card) {
    if (!myTurn) {
      return <div className="t-stage"><p className="t-wait"><span className="spin" />等待 {nameOf(state, state.currentPlayerId)} 选择行动…</p></div>;
    }
    const endgame = state.deckSize === 0;
    return (
      <div className="t-stage">
        <div className="t-panel">
          <h3 className="t-title">{endgame ? "私盘决胜 · 轮到你" : "轮到你了 · 请选择行动"}</h3>
          <div className="t-btnrow">
            {!endgame && (
              <button className="btn btn-primary" onClick={() => client.startAuction()}>🔨 开拍下一张</button>
            )}
            <button className={`btn ${endgame ? "btn-primary" : "btn-gold"}`}
              onClick={() => { client.getDealTargets(); setShowTargets(true); }}>
              ⇄ 发起私盘
            </button>
          </div>
          {endgame && <p className="t-hint">牌堆已空:私盘打到无人可交易,游戏才结束</p>}
        </div>
        {showTargets && (
          <div className="sheet-mask" onClick={() => setShowTargets(false)}>
            <div className="sheet" onClick={(e) => e.stopPropagation()}>
              <h3>发起私盘</h3>
              {snap.dealTargets.length === 0
                ? <p className="hint">你和对手没有相同套系的古董可换。</p>
                : snap.dealTargets.map((t) => {
                    const st = styleFor(t.setId);
                    return (
                      <button key={`${t.setId}-${t.targetId}`} className="roomrow"
                        onClick={() => { client.startDeal(t.targetId, t.setId); setShowTargets(false); }}>
                        <span className="setchip" style={{ background: st.primary }}><b>{st.glyph}</b> {st.name}</span>
                        <span className="roomrow-name">对手:{nameOf(state, t.targetId)}</span>
                        <span className="roomrow-count">可换 {t.tradeCount} 张</span>
                      </button>
                    );
                  })}
              <button className="btn btn-ghost" onClick={() => setShowTargets(false)}>取消</button>
            </div>
          </div>
        )}
      </div>
    );
  }

  // 拍卖:竞价中
  const iAmAuctioneer = myTurn;
  const myBidTurn = snap.currentBidderId === me && !iAmAuctioneer;
  return (
    <div className="t-stage t-stage-row">
      <div className="t-card"><CardView card={card} /></div>
      <div className="t-panel">
        <div className="t-bidline">
          {state.highestBid > 0
            ? <>最高 <b className="t-bid-amount">{state.highestBid}</b>({nameOf(state, state.highestBidder)})</>
            : <>尚无人出价</>}
        </div>
        {myBidTurn ? (
          <>
            <div className="t-stepper">
              <button className="stepbtn" disabled={amount - 10 < minBid} onClick={() => setAmount(amount - 10)}>−10</button>
              <span className="t-bid-now">{amount}</span>
              <button className="stepbtn" onClick={() => setAmount(amount + 10)}>+10</button>
              <button className="stepbtn" onClick={() => setAmount(amount + 100)}>+100</button>
            </div>
            <div className="t-btnrow">
              <button className="btn btn-ghost" onClick={() => client.passBid()}>不跟</button>
              <button className="btn btn-primary" onClick={() => client.placeBid(amount)}>出价 {amount}</button>
            </div>
          </>
        ) : (
          <p className="t-wait">
            {iAmAuctioneer
              ? "你是拍卖人——竞价结束后可选择截拍"
              : snap.currentBidderId !== null
                ? `等 ${nameOf(state, snap.currentBidderId)} 出价…`
                : "等待竞价推进…"}
          </p>
        )}
      </div>
    </div>
  );
}

// ── 古董手牌(扇形) ──────────────────────────────────────────
function AntiqueFan({ state, onPreview }: { state: GameStateView; onPreview: (c: Card) => void }) {
  const cards = useMemo(
    () => [...state.me.antiques].sort((a, b) => b.setScore - a.setScore || a.setId.localeCompare(b.setId) || a.cardId.localeCompare(b.cardId)),
    [state.me.antiques],
  );
  const W = 56;
  const { ref, step } = useFanStep(cards.length, W, W * 0.72);
  if (cards.length === 0) {
    return <div className="t-fan t-fan-antique t-fan-empty" ref={ref}>尚无古董——去拍下第一件!</div>;
  }
  return (
    <div className="t-fan t-fan-antique" ref={ref}>
      <div className="t-fan-inner" style={{ width: W + step * (cards.length - 1) }}>
        {cards.map((c, i) => {
          const st = styleFor(c.setId);
          const done = state.me.completeSets.includes(c.setId);
          const rar = cardRarity(c);
          return (
            <button
              key={`${c.cardId}-${i}`}
              className="t-acard"
              style={{ left: i * step, zIndex: i, borderColor: done ? GOLD : isElevated(rar) ? RARITY_ACCENT[rar] : "rgba(255,255,255,.2)" }}
              onClick={() => onPreview(c)}
              title={c.cardName}
            >
              <ArtThumb card={c} glyph={st.glyph} p={st.primary} s={st.secondary} />
              <span className="t-acard-name">{c.cardName}</span>
              {done && <span className="t-acard-done">✓</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}

function ArtThumb({ card, glyph, p, s }: { card: Card; glyph: string; p: string; s: string }) {
  const [ok, setOk] = useState(true);
  return ok ? (
    <img className="t-acard-art" src={cardArtUrl(card.cardId)} alt="" draggable={false} onError={() => setOk(false)} />
  ) : (
    <span className="t-acard-art t-acard-fallback" style={{ background: `linear-gradient(135deg, ${p}, ${s})` }}>{glyph}</span>
  );
}

// ── 资金手牌(扇形,斗地主式选牌) ─────────────────────────────
function MoneyFan({ money, picked, selecting, onToggle }: {
  money: Money; picked: Money; selecting: boolean;
  onToggle: (d: Denom, raised: boolean) => void;
}) {
  const bills = useMemo(() => {
    const arr: { d: Denom; idx: number }[] = [];
    for (const d of [...DENOMS].reverse()) {
      const c = money[d] ?? 0;
      for (let i = 0; i < c; i++) arr.push({ d, idx: i });
    }
    return arr;
  }, [money]);
  const W = 62;
  const { ref, step } = useFanStep(bills.length, W, W * 0.62);
  if (bills.length === 0) {
    return <div className="t-fan t-fan-money t-fan-empty" ref={ref}>没钱了…等白银加成或私盘回血</div>;
  }
  return (
    <div className={`t-fan t-fan-money${selecting ? " t-fan-selecting" : ""}`} ref={ref}>
      <div className="t-fan-inner" style={{ width: W + step * (bills.length - 1) }}>
        {bills.map((b, i) => {
          const raised = b.idx < (picked[b.d] ?? 0);
          return (
            <button
              key={`${b.d}-${b.idx}`}
              className={`t-bill${raised ? " t-bill-up" : ""}`}
              style={{ left: i * step, zIndex: i, color: BILL_COLOR[b.d] }}
              onClick={() => onToggle(b.d, raised)}
            >
              <span className="t-bill-corner">{b.d === "0" ? "废" : b.d}</span>
              <span className="t-bill-main">{b.d === "0" ? "废" : b.d}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
