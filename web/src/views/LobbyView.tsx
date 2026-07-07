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
    <div className="page">
      <header className="topbar">
        <span className="topbar-title">大厅</span>
        <span className="topbar-me">{snap.playerName}</span>
      </header>

      <div className="tabs">
        <button className={tab === "list" ? "tab tab-on" : "tab"} onClick={() => setTab("list")}>房间列表</button>
        <button className={tab === "create" ? "tab tab-on" : "tab"} onClick={() => setTab("create")}>创建房间</button>
        <button className={tab === "join" ? "tab tab-on" : "tab"} onClick={() => setTab("join")}>输码加入</button>
      </div>

      {tab === "list" && (
        <div className="panel">
          {snap.lobbyRooms.length === 0 ? (
            <p className="hint">暂无等待中的房间——创建一个,把房号发给朋友吧。</p>
          ) : (
            snap.lobbyRooms.map((r) => (
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
                <span className="roomrow-name">{r.hasPassword ? "🔒 " : ""}{r.roomName}</span>
                <span className="roomrow-code">{r.roomCode}</span>
                <span className={`roomrow-count${r.playerCount >= 4 ? " full" : ""}`}>{r.playerCount}/4</span>
              </button>
            ))
          )}
          <button className="btn" onClick={() => client.listRooms()}>刷新</button>
        </div>
      )}

      {tab === "create" && (
        <div className="panel">
          <label className="field">
            <span>房间名</span>
            <input value={roomName} maxLength={16} placeholder={`${snap.playerName}的房间`} onChange={(e) => setRoomName(e.target.value)} />
          </label>
          <label className="field">
            <span>密码(可选)</span>
            <input value={password} maxLength={12} placeholder="留空 = 无密码" onChange={(e) => setPassword(e.target.value)} />
          </label>
          <button className="btn btn-primary btn-big" onClick={() => client.createRoom(roomName.trim() || `${snap.playerName}的房间`, password)}>
            创建并入座
          </button>
        </div>
      )}

      {tab === "join" && (
        <div className="panel">
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
            加入房间
          </button>
        </div>
      )}
    </div>
  );
}
