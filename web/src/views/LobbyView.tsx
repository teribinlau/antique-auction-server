// 大厅：房间列表 / 创建房间 / 输码加入。

import { useEffect, useState } from "react";
import { client, type Snapshot } from "../client";

export function LobbyView({ snap }: { snap: Snapshot }) {
  const [tab, setTab] = useState<"list" | "create" | "join">("list");
  const [roomName, setRoomName] = useState("");
  const [password, setPassword] = useState("");
  const [joinCode, setJoinCode] = useState("");
  const [joinPwd, setJoinPwd] = useState("");

  useEffect(() => {
    const t = window.setInterval(() => client.listRooms(), 5000);
    return () => window.clearInterval(t);
  }, []);

  return (
    <div className="page pregame-page lobby-page">
      <main className="lobby-shell">
      <header className="topbar lobby-topbar">
        <div className="lobby-brand"><span>古董拍卖</span><small>PRIVATE SALON</small></div>
        <div className="topbar-me"><small>当前席位</small><b>{snap.playerName}</b></div>
      </header>

      <nav className="tabs" aria-label="大厅操作">
        <button className={tab === "list" ? "tab tab-on" : "tab"} onClick={() => setTab("list")}>房间列表</button>
        <button className={tab === "create" ? "tab tab-on" : "tab"} onClick={() => setTab("create")}>创建房间</button>
        <button className={tab === "join" ? "tab tab-on" : "tab"} onClick={() => setTab("join")}>输码加入</button>
      </nav>

      {tab === "list" && (
        <section className="panel lobby-panel">
          <div className="panel-heading">
            <div><span>01</span><h2>正在候场</h2></div>
            <button className="text-action" onClick={() => client.listRooms()}>刷新列表</button>
          </div>
          {snap.lobbyRooms.length === 0 ? (
            <div className="empty-state"><i>空</i><p>暂时没有等待中的房间</p><button className="text-action" onClick={() => setTab("create")}>创建第一间 →</button></div>
          ) : (
            <div className="room-list">{snap.lobbyRooms.map((r) => (
              <button
                key={r.roomCode}
                className="roomrow"
                onClick={() => {
                  if (r.hasPassword) {
                    setJoinCode(r.roomCode);
                    setTab("join");
                  } else {
                    client.joinRoom(r.roomCode, "");
                  }
                }}
              >
                <span className="roomrow-index">{String(r.playerCount).padStart(2, "0")}</span>
                <span className="roomrow-main"><b>{r.roomName}</b><small>{r.hasPassword ? "凭密码入场" : "开放席位"}</small></span>
                <span className="roomrow-code">{r.roomCode}</span>
                <span className={`roomrow-count${r.playerCount >= 5 ? " full" : ""}`}>{r.playerCount}/5 <i>→</i></span>
              </button>
            ))}</div>
          )}
        </section>
      )}

      {tab === "create" && (
        <section className="panel lobby-panel form-panel">
          <div className="panel-heading"><div><span>02</span><h2>开一间私人拍卖厅</h2></div></div>
          <label className="field">
            <span>房间名</span>
            <input value={roomName} maxLength={16} placeholder={`${snap.playerName}的房间`} onChange={(e) => setRoomName(e.target.value)} />
          </label>
          <label className="field">
            <span>密码(可选)</span>
            <input value={password} maxLength={12} placeholder="留空 = 无密码" onChange={(e) => setPassword(e.target.value)} />
          </label>
          <button className="btn btn-primary btn-big" onClick={() => client.createRoom(roomName.trim() || `${snap.playerName}的房间`, password)}>
            <span>创建并入座</span><i aria-hidden="true">→</i>
          </button>
        </section>
      )}

      {tab === "join" && (
        <section className="panel lobby-panel form-panel">
          <div className="panel-heading"><div><span>03</span><h2>凭房号赴约</h2></div></div>
          <label className="field">
            <span>房号(4 位)</span>
            <input
              value={joinCode}
              maxLength={4}
              placeholder="如 AB3F"
              style={{ textTransform: "uppercase", letterSpacing: "0.3em" }}
              onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
            />
          </label>
          <label className="field">
            <span>密码(如有)</span>
            <input value={joinPwd} maxLength={12} onChange={(e) => setJoinPwd(e.target.value)} />
          </label>
          <button
            className="btn btn-primary btn-big"
            disabled={joinCode.trim().length !== 4}
            onClick={() => client.joinRoom(joinCode.trim(), joinPwd)}
          >
            <span>加入房间</span><i aria-hidden="true">→</i>
          </button>
        </section>
      )}
      </main>
    </div>
  );
}
