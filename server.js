const http = require("http");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { WebSocketServer } = require("ws");
const { GameState } = require("./game_logic");

const PORT = process.env.PORT || 3000;
const MAX_PLAYERS = 5; // 房间人数上限(原版 Kuhhandel 支持 3-5 人;逻辑层按 players.length 自适应)
const ROOM_GRACE_MS = 10 * 60 * 1000; // 游戏中全员掉线后房间保留时长,期间可凭令牌重连

// 在线版本戳：访问 /version 即可看到当前部署的 commit（Render 注入 RENDER_GIT_COMMIT）。
const STARTED_AT = new Date().toISOString();
const GIT_COMMIT = process.env.RENDER_GIT_COMMIT || process.env.GIT_COMMIT || "unknown";

// ── H5 网页版静态托管 ─────────────────────────────────────────
// web/dist 由 Render 构建时生成（npm run build:web）。同域托管 → 页面里的 wss 自动同源。
// 没构建产物时（纯后端跑法）退回 JSON 健康响应，行为与旧版一致。
const WEB_DIST = path.join(__dirname, "web", "dist");
const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".webp": "image/webp",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
  ".map": "application/json",
  ".woff2": "font/woff2",
};

function sendJSONStatus(res) {
  res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify({ status: "ok", commit: GIT_COMMIT, startedAt: STARTED_AT }));
}

const httpServer = http.createServer((req, res) => {
  if (req.method !== "GET" && req.method !== "HEAD") { res.writeHead(405); res.end(); return; }
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, "http://x").pathname); }
  catch { res.writeHead(400); res.end(); return; }

  if (pathname === "/version") { sendJSONStatus(res); return; }

  // 解析到 web/dist 内的真实文件；目录穿越一律拒绝
  let filePath = path.normalize(path.join(WEB_DIST, pathname));
  if (!filePath.startsWith(WEB_DIST)) { res.writeHead(403); res.end(); return; }
  if (pathname === "/" || !path.extname(filePath)) filePath = path.join(WEB_DIST, "index.html"); // SPA 回退

  fs.readFile(filePath, (err, data) => {
    if (err) {
      // 无构建产物：/ 仍要 200（Render 健康检查）；其余 404
      if (pathname === "/") { sendJSONStatus(res); return; }
      res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("not found");
      return;
    }
    const ext = path.extname(filePath);
    const immutable = pathname.startsWith("/assets/"); // vite 产物带内容哈希
    res.writeHead(200, {
      "Content-Type": MIME[ext] || "application/octet-stream",
      "Cache-Control": immutable ? "public, max-age=31536000, immutable"
        : pathname.startsWith("/cards/") ? "public, max-age=604800"
        : "no-cache",
    });
    res.end(data);
  });
});

const wss = new WebSocketServer({ server: httpServer });
httpServer.listen(PORT, "0.0.0.0", () => console.log(`服务器运行在 ws://0.0.0.0:${PORT}`));

// rooms: roomCode -> { players: [{ws, playerId, playerName, reconnectToken, connected}], game: GameState|null, bidsCollected: [] }
const rooms = {};

function genCode() {
  return Math.random().toString(36).slice(2, 6).toUpperCase();
}

// 重连令牌：玩家入座时分配，断线后凭此把新连接绑回原座位
function genToken() {
  return crypto.randomBytes(16).toString("hex");
}

function send(ws, msg) {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(msg));
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

// 当前行动玩家掉线时,把回合推进到下一个在线玩家,避免全桌等一个回不来的人。
// close(掉线)与 rejoin_room(重连回来发现行动者还离线)两处共用。
function ensureActionableActor(room) {
  const game = room.game;
  if (!game || game.phase === "GAME_OVER") return;
  const onlineIds = new Set(room.players.filter(p => p.connected).map(p => p.playerId));
  if (onlineIds.size === 0) return;
  if (onlineIds.has(game.currentPlayer().playerId)) return;
  let steps = 0;
  do {
    game.currentPlayerIndex = (game.currentPlayerIndex + 1) % game.players.length;
    steps++;
  } while (!onlineIds.has(game.currentPlayer().playerId) && steps < game.players.length);
  const ev = game.nextTurn();
  dispatchEvents(room, ev);
}

// 自动替「掉线且轮到其出价」的玩家放弃竞价，避免拍卖卡在等一个回不来的人。
// 每次竞价推进后（开拍/出价/放弃/掉线）调用；会连续跳过多个掉线者，直至轮到在线玩家或竞价结束。
function autoResolveDisconnectedBids(room) {
  const game = room.game;
  if (!game) return;
  let guard = 0;
  while (
    game.phase === "AUCTION" &&
    game.auctionCard &&
    game.bidTurnId !== undefined &&
    game.bidTurnId !== -1 &&
    guard++ < game.players.length + 1
  ) {
    const bidderId = game.bidTurnId;
    const p = room.players.find(pp => pp.playerId === bidderId);
    if (p && p.connected) break;       // 轮到的是在线玩家，停止
    const ev = game.passBid(bidderId); // 掉线者自动放弃（退出本次竞拍）
    if (ev && ev.error) break;         // 异常兜底，避免死循环
    dispatchEvents(room, ev);
  }
}

// ── 心跳：定期 ping，剔除无响应的死连接（触发其 close → 保座或回收房间） ──
const HEARTBEAT_MS = 30000;
const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (ws.isAlive === false) { ws.terminate(); continue; }
    ws.isAlive = false;
    try { ws.ping(); } catch {}
  }
}, HEARTBEAT_MS);
wss.on("close", () => clearInterval(heartbeat));

wss.on("connection", (ws) => {
  ws.isAlive = true;
  ws.on("pong", () => { ws.isAlive = true; });

  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
    const { action } = msg;

    // ── 大厅列表 ──────────────────────────────────────────
    if (action === "list_rooms") {
      const list = Object.entries(rooms)
        .filter(([, r]) => !r.game && r.players.length < MAX_PLAYERS)
        .map(([code, r]) => ({
          roomCode: code,
          roomName: r.roomName,
          playerCount: r.players.length,
          hasPassword: !!r.password,
        }));
      send(ws, { event: "room_list", rooms: list });
      return;
    }

    // ── 创建房间 ──────────────────────────────────────────
    if (action === "create_room") {
      const code = genCode();
      rooms[code] = {
        players: [],
        game: null,
        bidsCollected: [],
        roomName: msg.roomName || `${msg.playerName || "玩家1"}的房间`,
        password: msg.password || "",
      };
      ws._roomCode = code;
      ws._playerName = msg.playerName || "玩家1";
      send(ws, { event: "room_created", roomCode: code, roomName: rooms[code].roomName });
      return;
    }

    // ── 加入房间 ──────────────────────────────────────────
    if (action === "join_room") {
      const room = rooms[msg.roomCode];
      if (!room) { send(ws, { event: "error", message: "房间不存在" }); return; }
      if (room.game) { send(ws, { event: "error", message: "游戏已开始" }); return; }
      if (room.players.length >= MAX_PLAYERS) { send(ws, { event: "error", message: "房间已满" }); return; }
      if (room.password && room.password !== msg.password) { send(ws, { event: "error", message: "密码错误" }); return; }
      ws._roomCode = msg.roomCode;
      ws._playerName = msg.playerName || `玩家${room.players.length + 1}`;
      const playerId = room.players.length;
      ws._playerId = playerId;
      const reconnectToken = genToken();
      room.players.push({ ws, playerId, playerName: ws._playerName, reconnectToken, connected: true });
      send(ws, { event: "joined_room", roomCode: msg.roomCode, roomName: room.roomName, playerId, playerCount: room.players.length, players: room.players.map(p => p.playerName), reconnectToken });
      broadcast(room, { event: "player_joined", playerName: ws._playerName, playerCount: room.players.length });
      return;
    }

    // ── 重连入座 ──────────────────────────────────────────
    if (action === "rejoin_room") {
      const room = rooms[msg.roomCode];
      if (!room) { send(ws, { event: "error", message: "房间不存在或已结束" }); return; }
      const player = room.players.find(p => p.reconnectToken && p.reconnectToken === msg.reconnectToken);
      if (!player) { send(ws, { event: "error", message: "重连失败：令牌无效" }); return; }
      // 有人回来了:取消「空房回收」倒计时
      clearTimeout(room.emptyTimer);
      room.emptyTimer = null;
      // 把新连接绑回原座位
      player.ws = ws;
      player.connected = true;
      ws._roomCode = msg.roomCode;
      ws._playerId = player.playerId;
      ws._playerName = player.playerName;
      ws.isAlive = true;
      send(ws, { event: "rejoined_room", roomCode: msg.roomCode, roomName: room.roomName, playerId: player.playerId, playerCount: room.players.length, players: room.players.map(p => p.playerName), reconnectToken: player.reconnectToken });
      broadcast(room, { event: "player_reconnected", playerName: player.playerName, playerId: player.playerId });
      // 重发当前游戏状态，让客户端恢复
      if (room.game) {
        send(ws, { event: "state_update", state: room.game.getViewFor(player.playerId) });
        if (room.game.phase !== "GAME_OVER") {
          send(ws, { event: "turn_changed", playerId: room.game.currentPlayer().playerId });
        }
        // 若当前行动者/出价者仍离线(如全员掉线后第一个回来的人),推进到在线玩家,别让他干等
        ensureActionableActor(room);
        autoResolveDisconnectedBids(room);
      }
      return;
    }

    const room = rooms[ws._roomCode];
    if (!room) return;

    // ── 状态同步 ──────────────────────────────────────────
    if (action === "request_state") {
      if (room.game) {
        send(ws, { event: "state_update", state: room.game.getViewFor(ws._playerId) });
        if (room.game.phase !== "GAME_OVER") {
          send(ws, { event: "turn_changed", playerId: room.game.currentPlayer().playerId });
        }
      }
      return;
    }

    // ── 开始游戏 ──────────────────────────────────────────
    if (action === "start_game") {
      if (room.players.length < 2) { send(ws, { event: "error", message: "至少需要2名玩家" }); return; }
      room.game = new GameState(room.players.map(p => p.playerName));
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
      autoResolveDisconnectedBids(room);
      return;
    }

    // ── 出价 ──────────────────────────────────────────────
    if (action === "place_bid") {
      if (game.phase !== "AUCTION") return;
      if (playerId === game.currentPlayer().playerId) return;
      const ev = game.placeBid(playerId, msg.amount);
      if (ev.error) return;
      dispatchEvents(room, ev);
      autoResolveDisconnectedBids(room);
      return;
    }

    // ── 放弃竞价 ──────────────────────────────────────────
    if (action === "pass_bid") {
      if (game.phase !== "AUCTION") return;
      if (playerId === game.currentPlayer().playerId) return;
      const ev = game.passBid(playerId);
      if (ev.error) return;
      dispatchEvents(room, ev);
      autoResolveDisconnectedBids(room);
      return;
    }

    // ── 截拍 ──────────────────────────────────────────────
    if (action === "action_snipe") {
      if (game.currentPlayer().playerId !== playerId) return;
      const ev = game.actionSnipe(msg.doSnipe, msg.paid || {});
      dispatchEvents(room, ev);
      autoResolveDisconnectedBids(room); // 付款失败会用同一张牌重拍，新 bid_turn 也需跳过掉线者
      return;
    }

    // ── 发起私盘 ──────────────────────────────────────────
    if (action === "start_private_deal") {
      if (game.currentPlayer().playerId !== playerId) return;
      const targetPlayer = game.getPlayer(msg.targetId);
      if (!targetPlayer) return;
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

    // 大厅阶段（未开局）：直接释放座位
    if (!room.game) {
      room.players = room.players.filter(p => p.ws !== ws);
      if (room.players.length === 0) { delete rooms[ws._roomCode]; return; }
      broadcast(room, { event: "player_left", playerName: ws._playerName });
      return;
    }

    // 游戏进行中：保留座位以便凭令牌重连，仅标记掉线。
    // 仅当这条连接仍是该座位的当前连接时才处理（避免旧连接迟到的 close 干扰已重连的玩家）。
    const player = room.players.find(p => p.ws === ws);
    if (!player) return;
    player.connected = false;
    player.ws = null;
    broadcast(room, { event: "player_disconnected", playerName: player.playerName, playerId: player.playerId });

    // 所有人都掉线:游戏已结束直接回收;进行中保留一段宽限期,期间任何人可凭令牌重连
    const connected = room.players.filter(p => p.connected);
    if (connected.length === 0) {
      if (room.game.phase === "GAME_OVER") { delete rooms[ws._roomCode]; return; }
      const code = ws._roomCode;
      clearTimeout(room.emptyTimer);
      room.emptyTimer = setTimeout(() => { delete rooms[code]; }, ROOM_GRACE_MS);
      return; // 状态冻结,等人回来(回来时 rejoin_room 会推进回合)
    }

    // 掉线者正是当前行动玩家 → 推进到下一个在线玩家，避免卡住
    ensureActionableActor(room);

    // 若掉线者正轮到出价，自动替其放弃，避免拍卖卡住
    autoResolveDisconnectedBids(room);
  });
});

