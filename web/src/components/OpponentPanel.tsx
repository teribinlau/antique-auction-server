// 对手面板：钞票只显示张数（诈唬来源）；古董按套系分组亮明（公开信息）。
// 与 iOS OpponentBills 同一套信息设计。

import type { Opponent } from "../protocol";
import { GOLD, styleFor } from "../theme";

interface SetGroup {
  setId: string;
  name: string;
  score: number;
  count: number;
  complete: boolean;
}

export function OpponentPanel({
  opponent, highlighted, disconnected,
}: {
  opponent: Opponent;
  highlighted: boolean;
  disconnected: boolean;
}) {
  const groups = new Map<string, SetGroup>();
  for (const c of opponent.antiques) {
    const g = groups.get(c.setId) ?? {
      setId: c.setId, name: c.setName, score: c.setScore, count: 0,
      complete: opponent.completeSets.includes(c.setId),
    };
    g.count++;
    groups.set(c.setId, g);
  }
  const sorted = [...groups.values()].sort((a, b) => b.score - a.score);

  return (
    <div className={`opp${highlighted ? " opp-hot" : ""}`}>
      <div className="opp-head">
        <span className="opp-name">
          {opponent.playerName}
          {disconnected && <span className="opp-off">掉线</span>}
        </span>
        {highlighted && <span className="chip chip-gold">出价中…</span>}
      </div>
      <div className="opp-money">
        💴 {opponent.handCount} 张钞票
        {opponent.completeSets.length > 0 && (
          <span style={{ color: GOLD, marginLeft: "auto" }}>✓ {opponent.completeSets.length} 套</span>
        )}
      </div>
      {sorted.length === 0 ? (
        <div className="opp-none">尚无亮明古董</div>
      ) : (
        <div className="opp-chips">
          {sorted.map((g) => {
            const st = styleFor(g.setId);
            return (
              <span
                key={g.setId}
                className="setchip"
                style={{
                  background: st.primary,
                  borderColor: g.complete ? GOLD : "rgba(255,255,255,.15)",
                }}
              >
                <b>{st.glyph}</b> {g.name}
                <i>{g.score}分·{g.count}张</i>
                {g.complete && <em style={{ color: GOLD }}>✓</em>}
              </span>
            );
          })}
        </div>
      )}
    </div>
  );
}
