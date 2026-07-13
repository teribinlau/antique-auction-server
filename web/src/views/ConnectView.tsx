// 连接页：昵称 + 服务器地址（默认同源，可改），持久化。

import { useState } from "react";
import { client, type Snapshot } from "../client";
import { GuideView } from "./GuideView";

export function ConnectView({ snap }: { snap: Snapshot }) {
  const [name, setName] = useState(snap.playerName);
  const [server, setServer] = useState(snap.serverUrl);
  const [showGuide, setShowGuide] = useState(false);
  const canGo = name.trim().length > 0 && snap.conn !== "connecting";

  if (showGuide) return <GuideView onClose={() => setShowGuide(false)} />;

  return (
    <div className="page pregame-page connect-page">
      <main className="connect-shell">
        <header className="hero">
          <p className="eyebrow">PRIVATE ANTIQUE SALON · 2—5 PLAYERS</p>
          <h1><span>古董</span><span>拍卖</span></h1>
          <p className="hero-sub">看得见的是筹码，猜不透的是底牌。</p>
          <div className="hero-rule" aria-hidden="true"><i /><span>开拍 · 截拍 · 私盘</span></div>
        </header>

        <section className="panel entry-panel" aria-label="进入拍卖大厅">
          <div className="panel-heading">
            <div><span>01</span><h2>入场登记</h2></div>
            <button className="text-action" onClick={() => setShowGuide(true)}>先看玩法</button>
          </div>

          <label className="field">
            <span>席位称呼</span>
            <input
              value={name}
              maxLength={12}
              autoComplete="nickname"
              placeholder="输入你的昵称"
              onChange={(e) => setName(e.target.value)}
            />
          </label>

          <div className="field">
            <span>对局视角</span>
            <div className="mode-seg" aria-label="选择对局界面">
              <button
                className={snap.uiMode === "table" ? "mode-on" : ""}
                aria-pressed={snap.uiMode === "table"}
                onClick={() => client.setUiMode("table")}
              ><b>牌桌</b><small>横屏沉浸</small></button>
              <button
                className={snap.uiMode === "classic" ? "mode-on" : ""}
                aria-pressed={snap.uiMode === "classic"}
                onClick={() => client.setUiMode("classic")}
              ><b>经典</b><small>竖屏清晰</small></button>
            </div>
          </div>

          <details className="advanced">
            <summary>连接设置</summary>
            <label className="field">
              <span>服务器地址</span>
              <input value={server} placeholder="wss://…" onChange={(e) => setServer(e.target.value)} />
            </label>
          </details>

          <button
            className="btn btn-primary btn-big"
            disabled={!canGo}
            onClick={() => client.connect(server, name.trim())}
          >
            <span>{snap.conn === "connecting" ? "正在为你留席…" : "进入拍卖厅"}</span>
            <i aria-hidden="true">→</i>
          </button>
          {snap.conn === "disconnected" && (
            <p className="hint hint-error">连接暂时中断。免费服务器冷启动可能需要约 1 分钟，请稍后重试。</p>
          )}
        </section>
      </main>
      <footer className="salon-footer">收藏成套，现金不计分 · 每一次加价都可以是虚张声势</footer>
    </div>
  );
}
