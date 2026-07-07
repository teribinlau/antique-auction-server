// 连接页：昵称 + 服务器地址（默认同源，可改），持久化。

import { useState } from "react";
import { client, type Snapshot } from "../client";

export function ConnectView({ snap }: { snap: Snapshot }) {
  const [name, setName] = useState(snap.playerName);
  const [server, setServer] = useState(snap.serverUrl);
  const canGo = name.trim().length > 0 && snap.conn !== "connecting";

  return (
    <div className="page page-center">
      <div className="hero">
        <div className="hero-glyph">🏺</div>
        <h1>古董拍卖</h1>
        <p className="hero-sub">开拍 · 截拍 · 私盘暗标 —— 2~5 人在线竞拍</p>
      </div>
      <div className="panel">
        <label className="field">
          <span>昵称</span>
          <input
            value={name}
            maxLength={12}
            placeholder="怎么称呼?"
            onChange={(e) => setName(e.target.value)}
          />
        </label>
        <label className="field">
          <span>服务器地址</span>
          <input
            value={server}
            placeholder="wss://…"
            onChange={(e) => setServer(e.target.value)}
          />
        </label>
        <button
          className="btn btn-primary btn-big"
          disabled={!canGo}
          onClick={() => client.connect(server, name.trim())}
        >
          {snap.conn === "connecting" ? "连接中…" : "进入大厅"}
        </button>
        {snap.conn === "disconnected" && (
          <p className="hint hint-error">连接断开了——服务器冷启动约需 1 分钟,稍等后重试。</p>
        )}
      </div>
    </div>
  );
}
