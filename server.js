const { WebSocketServer } = require("ws");
const { GameState } = require("./game_logic");

const PORT = process.env.PORT || 3000;
const wss = new WebSocketServer({ port: PORT });

// rooms: roomCode -> { players: [{ws, playerId, playerName}], game: GameState|null, bidsCollected: [] }
const rooms = {};

function genCode() {
  return Math.random().toString(36).slice(2, 6).toUpperCase();
}

function send(ws, msg) {
  if (ws.readyState === 1) ws.send(JSON.stringify(msg));
}

function broadcast(room, msg) {
  for (const p of room.players) send(p.ws, msg);
}

function broadcastState(room) {
  for (const p of room.players) {
    send(p.ws, { event: "state_update", state: room.game.getViewFor(p.playerId) });
  }
}

// 把 nextTurn/advanceTurn 返回的事件广播出去，并推送新状态
function dispatchEvents(room, events) {
  const arr = Array.isArray(events) ? events : [events];
  for (const ev of arr) {
    if (!ev || !ev.event) continue;
    broadcast(room, ev);
  }
  broadcastState(room);
}

wss.on("connection", (ws) => {
  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
    const { action } = msg;

    // ── 创建房间 ──────────────────────────────────────────
    if (action === "create_room") {
      const code = genCode();
      rooms[code] = { players: [], game: null, bidsCollected: [] };
      ws._roomCode = code;
      ws._playerName = msg.playerName || "玩家1";
      send(ws, { event: "room_created", roomCode: code });
      return;
    }

    // ── 加入房间 ──────────────────────────────────────────
    if (action === "join_room") {
      const room = rooms[msg.roomCode];
      if (!room) { send(ws, { event: "error", message: "房间不存在" }); return; }
      if (room.game) { send(ws, { event: "error", message: "游戏已开始" }); return; }
      if (room.players.length >= 4) { send(ws, { event: "error", message: "房间已满" }); return; }
      ws._roomCode = msg.roomCode;
      ws._playerName = msg.playerName || `玩家${room.players.length + 1}`;
      const playerId = room.players.length;
      ws._playerId = playerId;
      room.players.push({ ws, playerId, playerName: ws._playerName });
      send(ws, { event: "joined_room", roomCode: msg.roomCode, playerId, playerCount: room.players.length });
      broadcast(room, { event: "player_joined", playerName: ws._playerName, playerCount: room.players.length });
      return;
    }

    const room = rooms[ws._roomCode];
    if (!room) return;

    // ── 开始游戏 ──────────────────────────────────────────
    if (action === "start_game") {
      if (room.players.length < 2) { send(ws, { event: "error", message: "至少需要2名玩家" }); return; }
      room.game = new GameState(room.players.map(p => p.playerName));
      // 分配 playerId
      for (let i = 0; i < room.players.length; i++) {
        room.players[i].playerId = i;
        room.players[i].ws._playerId = i;
      }
      broadcast(room, { event: "game_started", playerCount: room.players.length });
      const ev = room.game.nextTurn();
      dispatchEvents(room, ev);
      return;
    }

    const game = room.game;
    if (!game) return;
    const playerId = ws._playerId;

    // ── 开拍 ──────────────────────────────────────────────
    if (action === "start_auction") {
      if (game.currentPlayer().playerId !== playerId) return;
      const ev = game.startAuction();
      dispatchEvents(room, ev);
      return;
    }

    // ── 出价 ──────────────────────────────────────────────
    if (action === "place_bid") {
      if (game.phase !== "AUCTION") return;
      const auctionerId = game.currentPlayer().playerId;
      if (playerId === auctionerId) return;
      const ev = game.placeBid(playerId, msg.amount);
      dispatchEvents(room, ev);
      // 所有非开拍玩家都已出价或放弃则结算
      const nonAuctioneers = game.players.filter(p => p.playerId !== auctionerId);
      const allDone = nonAuctioneers.every(p => game.bids[p.playerId] !== undefined || game.passed[p.playerId] === true);
      if (allDone) dispatchEvents(room, game.resolveBids());
      return;
    }

    // ── 放弃竞价 ──────────────────────────────────────────
    if (action === "pass_bid") {
      if (game.phase !== "AUCTION") return;
      const auctionerId = game.currentPlayer().playerId;
      if (playerId === auctionerId) return;
      const ev = game.passBid(playerId);
      dispatchEvents(room, ev);
      const nonAuctioneers = game.players.filter(p => p.playerId !== auctionerId);
      const allDone = nonAuctioneers.every(p => game.bids[p.playerId] !== undefined || game.passed[p.playerId] === true);
      if (allDone) dispatchEvents(room, game.resolveBids());
      return;
    }

    // ── 截拍 ──────────────────────────────────────────────
    if (action === "action_snipe") {
      if (game.currentPlayer().playerId !== playerId) return;
      const ev = game.actionSnipe(msg.doSnipe, msg.paid || {});
      dispatchEvents(room, ev);
      return;
    }

    // ── 发起私盘 ──────────────────────────────────────────
    if (action === "start_private_deal") {
      if (game.currentPlayer().playerId !== playerId) return;
      const ev = game.startPrivateDeal(playerId, msg.targetId, msg.setId);
      dispatchEvents(room, ev);
      return;
    }

    // ── 提交私盘报价 ──────────────────────────────────────
    if (action === "submit_deal_offer") {
      const ev = game.submitDealOffer(playerId, msg.paid || {});
      dispatchEvents(room, ev);
      return;
    }

    // ── 查询私盘目标 ──────────────────────────────────────
    if (action === "get_deal_targets") {
      const targets = game.getPrivateDealTargets(playerId);
      send(ws, { event: "deal_targets", targets });
      return;
    }
  });

  ws.on("close", () => {
    const room = rooms[ws._roomCode];
    if (!room) return;
    room.players = room.players.filter(p => p.ws !== ws);
    if (room.players.length === 0) {
      delete rooms[ws._roomCode];
    } else {
      broadcast(room, { event: "player_left", playerName: ws._playerName });
    }
  });
});

console.log(`服务器运行在 ws://localhost:${PORT}`);
