// 等待室：大字房号(发给朋友) + 名单 + 开始按钮(≥2 人)。

import { useState } from "react";
import { client, type Snapshot } from "../client";
import { GuideView } from "./GuideView";

export function WaitingView({ snap }: { snap: Snapshot }) {
  const n = snap.waitingPlayers.length;
  const [showGuide, setShowGuide] = useState(false);
  if (showGuide) return <GuideView onClose={() => setShowGuide(false)} />;
  return (
    <div className="page page-center">
      <div className="panel panel-wait">
        <p className="wait-label">房号(发给朋友,输码加入)</p>
        <div className="wait-code">{snap.roomCode}</div>
        <p className="wait-room">{snap.roomName}</p>
        <ul className="wait-list">
          {snap.waitingPlayers.map((name, i) => (
            <li key={`${i}-${name}`}>
              <span className="wait-seat">{i + 1}号位</span>
              {name}
              {i === snap.myPlayerId && <span className="chip chip-gold chip-mini">你</span>}
            </li>
          ))}
          {Array.from({ length: Math.max(0, 2 - n) }).map((_, i) => (
            <li key={`empty-${i}`} className="wait-empty">等待玩家加入…</li>
          ))}
        </ul>
        <button className="btn btn-primary btn-big" disabled={n < 2} onClick={() => client.startGame()}>
          {n < 2 ? "至少需要 2 人" : `开始游戏(${n} 人)`}
        </button>
        <button className="btn btn-gold" onClick={() => setShowGuide(true)}>❓ 等人的空档,看看怎么玩</button>
        <button className="btn btn-ghost" onClick={() => client.leaveRoom()}>离开房间</button>
      </div>
    </div>
  );
}
