// 5:7 竖版古董卡：满幅插画(缺图自动回退渐变+套系字) + 顶/底蒙版 + 叠加徽章。
// 与 iOS CardView 同一套视觉规则。

import { useState } from "react";
import type { Card } from "../protocol";
import { GOLD, RARITY_ACCENT, RARITY_LABEL, cardArtUrl, cardRarity, isElevated, styleFor } from "../theme";

export function CardView({ card, inCompleteSet = false }: { card: Card; inCompleteSet?: boolean }) {
  const [imgOk, setImgOk] = useState(true);
  const st = styleFor(card.setId);
  const rarity = cardRarity(card);
  const elevated = isElevated(rarity);

  return (
    <div
      className={`card-face${rarity === "legendary" ? " card-legendary" : ""}`}
      style={{ borderColor: elevated ? GOLD : "rgba(255,255,255,.18)" }}
    >
      {imgOk ? (
        <img
          className="card-art"
          src={cardArtUrl(card.cardId)}
          alt=""
          draggable={false}
          onError={() => setImgOk(false)}
        />
      ) : (
        <div
          className="card-art card-art-fallback"
          style={{ background: `linear-gradient(135deg, ${st.primary}, ${st.secondary})` }}
        >
          <span className="card-glyph">{st.glyph}</span>
        </div>
      )}
      <div className="card-scrim" />
      <div className="card-chrome">
        <div className="card-top">
          <span className="chip chip-set">{card.setName}</span>
          <span className="chip" style={{ background: RARITY_ACCENT[rarity], border: elevated ? `1px solid ${GOLD}` : "none" }}>
            {RARITY_LABEL[rarity]}
          </span>
          <span className="card-score">{card.setScore} 分</span>
        </div>
        <div className="card-bottom">
          {inCompleteSet && <span className="chip chip-complete">✓ 集齐套系</span>}
          <div className="card-name">{card.cardName}</div>
          <div className="card-flavor">{card.flavorText}</div>
        </div>
      </div>
    </div>
  );
}

/** 列表行式缩略（我的古董列表用） */
export function CardRow({ card, inCompleteSet = false }: { card: Card; inCompleteSet?: boolean }) {
  const [imgOk, setImgOk] = useState(true);
  const st = styleFor(card.setId);
  const rarity = cardRarity(card);
  return (
    <div className="card-row" style={{ borderColor: isElevated(rarity) ? "rgba(212,169,87,.5)" : "transparent" }}>
      <div className="card-row-thumb" style={{ background: `linear-gradient(135deg, ${st.primary}, ${st.secondary})` }}>
        {imgOk ? (
          <img src={cardArtUrl(card.cardId)} alt="" draggable={false} onError={() => setImgOk(false)} />
        ) : (
          <span className="card-row-glyph">{st.glyph}</span>
        )}
      </div>
      <div className="card-row-mid">
        <div className="card-row-set">
          <span>{card.setName}</span>
          <span className="chip chip-mini" style={{ background: RARITY_ACCENT[rarity] }}>{RARITY_LABEL[rarity]}</span>
          {inCompleteSet && <span className="chip chip-mini chip-complete">集齐</span>}
        </div>
        <div className="card-row-name">{card.cardName}</div>
      </div>
      <div className="card-row-score">{card.setScore} 分</div>
    </div>
  );
}
