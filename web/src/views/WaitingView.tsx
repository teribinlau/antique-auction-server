// 等待室：大字房号(发给朋友) + 名单 + 开始按钮(≥2 人)。

import { useState } from "react";
import { client, type Snapshot } from "../client";
import { GuideView } from "./GuideView";

export function WaitingView({ snap }: { snap: Snapshot }) {
  const n = snap.waitingPlayers.length;
  const isHost = snap.myPlayerId === 0;
  const [showGuide, setShowGuide] = useState(false);
  if (showGuide) return <GuideView onClose={() => setShowGuide(false)} />;
  return (
    <div className="page pregame-page waiting-page">
      <main className="waiting-shell">
      <section className="panel panel-wait">
        <div className="panel-heading"><div><span>候场</span><h2>{snap.roomName}</h2></div><b>{n}/5</b></div>
        <p className="wait-label">把这组房号发给同桌玩家</p>
        <div className="wait-code">{snap.roomCode}</div>
        <button className="text-action wait-copy" onClick={() => {
          if (snap.roomCode) navigator.clipboard?.writeText(snap.roomCode);
          client.toast(`房号 ${snap.roomCode}`);
        }}>复制房号</button>
        <ul className="wait-list">
          {snap.waitingPlayers.map((name, i) => (
            <li key={`${i}-${name}`}>
              <span className="wait-seat">{String(i + 1).padStart(2, "0")}</span>
              <b>{name}</b>
              <span className="wait-role">{i === 0 ? "房主" : "藏家"}{i === snap.myPlayerId ? " · 你" : ""}</span>
            </li>
          ))}
          {Array.from({ length: Math.max(0, 2 - n) }).map((_, i) => (
            <li key={`empty-${i}`} className="wait-empty"><span className="wait-seat">—</span>等待玩家加入…</li>
          ))}
        </ul>
        {isHost ? (
          <button className="btn btn-primary btn-big" disabled={n < 2} onClick={() => client.startGame()}>
            {n < 2 ? "至少需要 2 人" : `开始游戏(${n} 人)`}
          </button>
        ) : (
          <p className="wait-host-note">房主准备好后会开始游戏</p>
        )}
        <div className="wait-actions">
          <button className="text-action" onClick={() => setShowGuide(true)}>查看玩法</button>
          <button className="text-action muted" onClick={() => client.leaveRoom()}>离开房间</button>
        </div>
      </section>
      </main>
    </div>
  );
}
