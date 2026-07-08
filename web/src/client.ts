// 网络层 + 状态中枢（对应 iOS 的 GameClient）。
// 通过 subscribe/getSnapshot 与 React 的 useSyncExternalStore 对接。
//
// 已落实的协议易错点（与 ios/README.md 一致）：
// 1. create_room 不入座：收到 room_created 后自动续发 join_room。
// 2. opponents[].handCount = 钞票总张数。
// 3. deal_resolved 两种形态：winnerId / tieForcedWinner 皆可选。
// 4. request_state 仅游戏中有响应：等待室阶段无响应不算错。
// 5. money 的 key 是字符串面值，"0" 是废钞。
// 另外「轮到谁出价」不在 state 里，靠 bid_turn 维护 currentBidderId。

import type {
  Card, DealResolved, DealTarget, GameStateView, Money, RoomSummary, Score, ServerEvent, SnipePrompt,
} from "./protocol";
import { effectiveWinnerId, moneyTotal } from "./protocol";
import { styleFor } from "./theme";

export type ConnState = "idle" | "connecting" | "connected" | "disconnected";

export interface BannerMsg {
  id: number;
  kind: "info" | "gold" | "error" | "win";
  text: string;
}

export interface Snapshot {
  conn: ConnState;
  serverUrl: string;
  playerName: string;
  roomCode: string | null;
  roomName: string | null;
  myPlayerId: number | null;
  lobbyRooms: RoomSummary[];
  waitingPlayers: string[];
  state: GameStateView | null;
  /** 轮到出价的玩家（bid_turn 维护；null=当前无人出价中） */
  currentBidderId: number | null;
  snipePrompt: SnipePrompt | null;
  dealTargets: DealTarget[];
  /** 私盘中我是否已提交报价（本地乐观 + 事件确认） */
  dealSubmittedByMe: boolean;
  gameOverScores: Score[] | null;
  banners: BannerMsg[];
  /** 游戏中掉线的玩家 id（player_disconnected/reconnected 维护） */
  disconnectedIds: number[];
}

const LS = {
  name: "aa.playerName",
  server: "aa.serverURL",
  lastRoom: "aa.lastRoom",
  token: (code: string) => `aa.token.${code}`,
};

/** 默认服务器：同源（页面由 server.js 托管时天然正确）。本地 vite dev 时退回 3000 端口。 */
export function defaultServerUrl(): string {
  const { protocol, host, port } = window.location;
  const wsProto = protocol === "https:" ? "wss:" : "ws:";
  if (port === "5173") return `${wsProto}//${window.location.hostname}:3000`; // vite dev
  return `${wsProto}//${host}`;
}

/** 宽松规范化：https→wss、http→ws、无协议补 wss:// */
export function normalizeServerUrl(raw: string): string | null {
  let s = raw.trim();
  if (!s) return null;
  const lower = s.toLowerCase();
  if (lower.startsWith("https://")) s = "wss://" + s.slice(8);
  else if (lower.startsWith("http://")) s = "ws://" + s.slice(7);
  else if (!lower.startsWith("wss://") && !lower.startsWith("ws://")) s = "wss://" + s;
  s = s.replace(/\/+$/, "");
  try {
    const u = new URL(s);
    return u.href.replace(/\/+$/, "");
  } catch {
    return null;
  }
}

let bannerSeq = 1;

export class GameClient {
  private ws: WebSocket | null = null;
  private listeners = new Set<() => void>();
  private snap: Snapshot;
  private reconnectTimer: number | null = null;
  private reconnectAttempt = 0;
  /** 断线时是否应尝试凭令牌重连（仅游戏进行中） */
  private wantRejoin = false;
  private pendingJoin: { playerName: string; password: string } | null = null;

  constructor() {
    this.snap = {
      conn: "idle",
      serverUrl: localStorage.getItem(LS.server) || defaultServerUrl(),
      playerName: localStorage.getItem(LS.name) || "",
      roomCode: null,
      roomName: null,
      myPlayerId: null,
      lobbyRooms: [],
      waitingPlayers: [],
      state: null,
      currentBidderId: null,
      snipePrompt: null,
      dealTargets: [],
      dealSubmittedByMe: false,
      gameOverScores: null,
      banners: [],
      disconnectedIds: [],
    };
    // 回到前台:探活/重连。微信/手机浏览器常把后台页面冻结——socket 可能已死但 close 迟迟不来。
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState !== "visible") return;
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.send({ action: "request_state" }); // 游戏中会刷新;等待室无响应,无害
        return;
      }
      if (this.ws && this.ws.readyState === WebSocket.CONNECTING) return; // 正在连,别打断
      // 假活/已断:立刻按掉线处理并快速重连
      if (this.snap.conn === "connected") this.patch({ conn: "disconnected" });
      try { this.ws?.close(); } catch { /* 忽略 */ }
      this.ws = null;
      if (this.reconnectTimer !== null) { clearTimeout(this.reconnectTimer); this.reconnectTimer = null; }
      this.reconnectAttempt = 0; // 用户人在,给最快的重试节奏
      this.tryRejoinAfterDrop();
    });
    // 页面(重新)加载:若存有名字+牌局令牌,自动连回去——微信杀掉网页再打开也能回牌局
    const lastRoom = localStorage.getItem(LS.lastRoom);
    const token = lastRoom ? localStorage.getItem(LS.token(lastRoom)) : null;
    if (this.snap.playerName && lastRoom && token) {
      this.wantRejoin = true;
      setTimeout(() => this.connect(this.snap.serverUrl, this.snap.playerName), 0);
    }
  }

  /** 是否存有可恢复的牌局(房号+令牌) */
  hasResumableGame(): boolean {
    const code = localStorage.getItem(LS.lastRoom);
    return !!(code && localStorage.getItem(LS.token(code)));
  }

  // ── store 对接 ────────────────────────────────────────────
  subscribe = (fn: () => void): (() => void) => {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  };
  getSnapshot = (): Snapshot => this.snap;
  private patch(p: Partial<Snapshot>) {
    this.snap = { ...this.snap, ...p };
    for (const fn of this.listeners) fn();
  }

  // ── 连接管理 ──────────────────────────────────────────────
  connect(serverUrl: string, playerName: string) {
    const url = normalizeServerUrl(serverUrl);
    if (!url) { this.banner("error", "服务器地址无效"); return; }
    localStorage.setItem(LS.server, url);
    localStorage.setItem(LS.name, playerName);
    this.patch({ serverUrl: url, playerName, conn: "connecting" });
    this.openSocket(url, () => {
      // 存有牌局令牌 → 优先绑回原座位(令牌失效时 error 归约会清令牌、退回大厅)
      const code = localStorage.getItem(LS.lastRoom);
      const token = code ? localStorage.getItem(LS.token(code)) : null;
      if (code && token) {
        this.wantRejoin = true;
        this.send({ action: "rejoin_room", roomCode: code, reconnectToken: token });
      } else {
        this.send({ action: "list_rooms" });
      }
    });
  }

  private openSocket(url: string, onOpen: () => void) {
    try { this.ws?.close(); } catch { /* 忽略 */ }
    let ws: WebSocket;
    try {
      ws = new WebSocket(url);
    } catch {
      this.patch({ conn: "disconnected" });
      this.banner("error", "无法连接服务器");
      return;
    }
    this.ws = ws;
    ws.onopen = () => {
      this.reconnectAttempt = 0;
      this.patch({ conn: "connected" });
      onOpen();
    };
    ws.onmessage = (e) => {
      let msg: ServerEvent;
      try { msg = JSON.parse(String(e.data)); } catch { return; }
      if (msg && typeof msg.event === "string") this.reduce(msg);
    };
    ws.onclose = () => {
      if (this.ws !== ws) return; // 旧连接迟到的 close
      this.ws = null;
      this.patch({ conn: "disconnected" });
      this.tryRejoinAfterDrop();
    };
    ws.onerror = () => { /* onclose 会跟着来 */ };
  }

  /** 游戏进行中掉线 → 指数退避自动重连并 rejoin_room */
  private tryRejoinAfterDrop() {
    if (!this.wantRejoin) return;
    const code = this.snap.roomCode ?? localStorage.getItem(LS.lastRoom);
    const token = code ? localStorage.getItem(LS.token(code)) : null;
    if (!code || !token) { this.wantRejoin = false; return; }
    if (this.reconnectTimer !== null) return;
    const delay = Math.min(1000 * 2 ** this.reconnectAttempt, 15000);
    this.reconnectAttempt++;
    this.reconnectTimer = window.setTimeout(() => {
      this.reconnectTimer = null;
      if (this.snap.conn === "connected") return;
      this.patch({ conn: "connecting" });
      this.openSocket(this.snap.serverUrl, () => {
        this.send({ action: "rejoin_room", roomCode: code, reconnectToken: token });
      });
    }, delay);
  }

  disconnect() {
    this.wantRejoin = false;
    if (this.reconnectTimer !== null) { clearTimeout(this.reconnectTimer); this.reconnectTimer = null; }
    try { this.ws?.close(); } catch { /* 忽略 */ }
    this.ws = null;
    this.patch({
      conn: "idle", roomCode: null, roomName: null, myPlayerId: null,
      state: null, waitingPlayers: [], currentBidderId: null, snipePrompt: null,
      gameOverScores: null, dealTargets: [], dealSubmittedByMe: false, disconnectedIds: [],
    });
  }

  /** 离开房间回大厅（协议无 leave_room：断开重连是最可靠的离开方式） */
  leaveRoom() {
    const { serverUrl, playerName, roomCode } = this.snap;
    if (roomCode) localStorage.removeItem(LS.token(roomCode));
    localStorage.removeItem(LS.lastRoom);
    this.wantRejoin = false;
    this.patch({
      roomCode: null, roomName: null, myPlayerId: null, state: null,
      waitingPlayers: [], currentBidderId: null, snipePrompt: null,
      gameOverScores: null, dealTargets: [], dealSubmittedByMe: false, disconnectedIds: [],
    });
    this.connect(serverUrl, playerName);
  }

  // ── 发送 ─────────────────────────────────────────────────
  send(msg: Record<string, unknown>) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(msg));
    }
  }
  listRooms() { this.send({ action: "list_rooms" }); }
  createRoom(roomName: string, password: string) {
    this.pendingJoin = { playerName: this.snap.playerName, password };
    this.send({ action: "create_room", roomName, playerName: this.snap.playerName, password });
  }
  joinRoom(roomCode: string, password: string) {
    this.send({ action: "join_room", roomCode, playerName: this.snap.playerName, password });
  }
  startGame() { this.send({ action: "start_game" }); }
  startAuction() { this.send({ action: "start_auction" }); }
  placeBid(amount: number) { this.send({ action: "place_bid", amount }); }
  passBid() { this.send({ action: "pass_bid" }); }
  snipe(doSnipe: boolean, paid?: Money) { this.send({ action: "action_snipe", doSnipe, paid: paid ?? {} }); }
  startDeal(targetId: number, setId: string) { this.send({ action: "start_private_deal", targetId, setId }); }
  submitOffer(paid: Money) {
    this.patch({ dealSubmittedByMe: true });
    this.send({ action: "submit_deal_offer", paid });
  }
  getDealTargets() { this.send({ action: "get_deal_targets" }); }
  requestState() { this.send({ action: "request_state" }); }

  // ── 横幅 ─────────────────────────────────────────────────
  /** 供视图层弹一条提示(如「房号已复制」) */
  toast(text: string) { this.banner("info", text); }

  private banner(kind: BannerMsg["kind"], text: string) {
    const b: BannerMsg = { id: bannerSeq++, kind, text };
    const banners = [...this.snap.banners, b].slice(-3);
    this.patch({ banners });
    window.setTimeout(() => {
      this.patch({ banners: this.snap.banners.filter((x) => x.id !== b.id) });
    }, 4200);
  }

  private nameOf(id: number): string {
    const s = this.snap.state;
    if (s) {
      if (s.me.playerId === id) return s.me.playerName;
      const o = s.opponents.find((p) => p.playerId === id);
      if (o) return o.playerName;
    }
    const w = this.snap.waitingPlayers[id];
    return w ?? `玩家${id + 1}`;
  }
  private isMe(id: number): boolean { return id === this.snap.myPlayerId; }

  // ── 事件归约 ──────────────────────────────────────────────
  private reduce(ev: ServerEvent) {
    switch (ev.event) {
      case "room_list":
        this.patch({ lobbyRooms: (ev.rooms as RoomSummary[]) ?? [] });
        break;

      case "room_created": {
        // 易错点①：创建不入座，自动续发 join_room
        const code = String(ev.roomCode ?? "");
        const pj = this.pendingJoin;
        this.pendingJoin = null;
        this.send({ action: "join_room", roomCode: code, playerName: pj?.playerName ?? this.snap.playerName, password: pj?.password ?? "" });
        break;
      }

      case "joined_room":
      case "rejoined_room": {
        const code = String(ev.roomCode ?? "");
        const token = typeof ev.reconnectToken === "string" ? ev.reconnectToken : null;
        if (token && code) {
          localStorage.setItem(LS.token(code), token);
          localStorage.setItem(LS.lastRoom, code);
        }
        this.patch({
          roomCode: code,
          roomName: String(ev.roomName ?? ""),
          myPlayerId: Number(ev.playerId),
          waitingPlayers: (ev.players as string[]) ?? [],
          gameOverScores: null,
        });
        if (ev.event === "rejoined_room") {
          this.banner("info", "已重连回原座位");
          this.patch({ disconnectedIds: this.snap.disconnectedIds.filter((i) => i !== Number(ev.playerId)) });
        }
        break;
      }

      case "player_joined": {
        // 服务端不带全量名单：按 playerCount 去重追加
        const name = String(ev.playerName ?? "");
        const count = Number(ev.playerCount ?? 0);
        let list = [...this.snap.waitingPlayers];
        if (list.length < count) list.push(name);
        this.patch({ waitingPlayers: list });
        if (name !== this.snap.playerName) this.banner("info", `${name} 加入了房间`);
        break;
      }

      case "player_left": {
        const name = String(ev.playerName ?? "");
        this.patch({ waitingPlayers: this.snap.waitingPlayers.filter((n) => n !== name) });
        this.banner("info", `${name} 离开了房间`);
        break;
      }

      case "player_disconnected": {
        const pid = Number(ev.playerId);
        this.patch({ disconnectedIds: [...new Set([...this.snap.disconnectedIds, pid])] });
        this.banner("info", `${String(ev.playerName ?? "")} 掉线了（座位保留）`);
        break;
      }
      case "player_reconnected": {
        const pid = Number(ev.playerId);
        this.patch({ disconnectedIds: this.snap.disconnectedIds.filter((i) => i !== pid) });
        this.banner("info", `${String(ev.playerName ?? "")} 重连回来了`);
        break;
      }

      case "error": {
        const msg = String(ev.message ?? "发生错误");
        this.banner("error", msg);
        // 重连令牌失效 → 清令牌回大厅
        if (msg.includes("令牌") || msg.includes("不存在或已结束")) {
          const code = this.snap.roomCode ?? localStorage.getItem(LS.lastRoom);
          if (code) localStorage.removeItem(LS.token(code));
          localStorage.removeItem(LS.lastRoom);
          this.wantRejoin = false;
          if (this.snap.conn === "connected") this.listRooms();
          this.patch({ roomCode: null, roomName: null, myPlayerId: null, state: null, waitingPlayers: [] });
        }
        break;
      }

      case "game_started":
        this.wantRejoin = true;
        this.banner("gold", "游戏开始!");
        break;

      case "state_update": {
        const state = ev.state as GameStateView;
        // 最后一张牌的拍卖刚结束、进入「私盘决胜」的那一刻,广而告之(只触发一次)
        const prev = this.snap.state;
        if (prev && prev.auctionCard && !state.auctionCard &&
            state.deckSize === 0 && state.phase === "AUCTION") {
          this.banner("gold", "牌堆已空!进入私盘决胜——直到无人可交易才结束");
        }
        const p: Partial<Snapshot> = { state };
        if (state.phase !== "AUCTION" || !state.auctionCard) p.currentBidderId = null;
        if (state.phase !== "SNIPE") p.snipePrompt = null;
        if (state.phase !== "PRIVATE_DEAL") p.dealSubmittedByMe = false;
        if (state.phase === "GAME_OVER") {
          this.wantRejoin = false;
          const code = this.snap.roomCode;
          if (code) localStorage.removeItem(LS.token(code));
          localStorage.removeItem(LS.lastRoom);
        } else if (state.phase !== "WAITING") {
          this.wantRejoin = true;
        }
        this.patch(p);
        break;
      }

      case "turn_changed": {
        const pid = Number(ev.playerId);
        this.patch({ currentBidderId: null });
        if (this.isMe(pid)) this.banner("gold", "轮到你了·请选择行动");
        break;
      }

      case "auction_started": {
        const card = ev.card as Card;
        this.patch({ currentBidderId: null });
        this.banner("info", `开拍:「${card.cardName}」(${styleFor(card.setId).name} · ${card.setScore}分)`);
        break;
      }

      case "silver_bonus":
        this.banner("gold", `白银加成!本轮全员 +${Number(ev.bonus)}(第 ${Number(ev.count)} 次)`);
        break;

      case "bid_turn":
        this.patch({ currentBidderId: Number(ev.playerId) });
        break;

      case "bid_placed": {
        const pid = Number(ev.playerId);
        if (!this.isMe(pid)) this.banner("info", `${this.nameOf(pid)} 出价 ${Number(ev.amount)}`);
        break;
      }
      case "bid_passed": {
        const pid = Number(ev.playerId);
        if (!this.isMe(pid)) this.banner("info", `${this.nameOf(pid)} 退出竞拍`);
        break;
      }

      case "no_bids": {
        const pid = Number(ev.winnerId);
        this.banner("info", this.isMe(pid) ? "无人出价,古董归你!" : `无人出价,古董归 ${this.nameOf(pid)}`);
        break;
      }

      case "snipe_prompt":
        this.patch({
          snipePrompt: {
            card: ev.card as Card,
            highestBid: Number(ev.highestBid),
            highestBidder: Number(ev.highestBidder),
            auctionerId: Number(ev.auctionerId),
          },
          currentBidderId: null,
        });
        break;

      case "snipe_success": {
        const pid = Number(ev.winnerId);
        this.patch({ snipePrompt: null });
        this.banner(this.isMe(pid) ? "win" : "info", this.isMe(pid) ? "截拍成功,古董归你!" : `${this.nameOf(pid)} 截拍成功`);
        break;
      }
      case "snipe_declined": {
        const pid = Number(ev.winnerId);
        this.patch({ snipePrompt: null });
        this.banner(this.isMe(pid) ? "win" : "info", this.isMe(pid) ? "拍卖人放手,古董归你!" : `拍卖人放手,古董归 ${this.nameOf(pid)}`);
        break;
      }

      case "payment_failed": {
        const pid = Number(ev.playerId);
        const exposed = (ev.exposedMoney ?? {}) as Money;
        this.patch({ snipePrompt: null });
        this.banner("error",
          `${this.isMe(pid) ? "你" : this.nameOf(pid)} 付款失败(仅有 ${moneyTotal(exposed)}),该牌流拍重来`);
        break;
      }

      case "private_deal_started": {
        const ini = Number(ev.initiatorId), tgt = Number(ev.targetId);
        const setName = styleFor(String(ev.setId)).name;
        this.patch({ dealSubmittedByMe: false });
        this.banner("info", `${this.nameOf(ini)} 向 ${this.nameOf(tgt)} 发起「${setName}」私盘`);
        break;
      }

      case "deal_offer_submitted": {
        const who = Number(ev.targetId); // 已提交的一方? 协议:targetId/initiatorId 都带
        void who;
        break; // 提交进度由本地 dealSubmittedByMe + 等待文案表达,不打横幅避免刷屏
      }

      case "deal_tie":
        this.patch({ dealSubmittedByMe: false });
        this.banner("info", `双方报价打平(第 ${Number(ev.tieCount)} 次),请重新暗标`);
        break;

      case "deal_resolved": {
        const d = ev as unknown as DealResolved;
        const win = effectiveWinnerId(d);
        if (win !== undefined) {
          const flip = d.tieForcedWinner !== undefined ? "(连平掷币)" : "";
          this.banner(this.isMe(win) ? "win" : "info",
            this.isMe(win)
              ? `私盘成交${flip}:你赢得 ${d.tradeCount} 张古董`
              : `私盘成交${flip}:${this.nameOf(win)} 赢得 ${d.tradeCount} 张古董`);
        }
        this.patch({ dealSubmittedByMe: false });
        break;
      }

      case "deal_targets":
        this.patch({ dealTargets: (ev.targets as DealTarget[]) ?? [] });
        break;

      case "game_over": {
        const scores = (ev.scores as Score[]) ?? [];
        this.wantRejoin = false;
        const code = this.snap.roomCode;
        if (code) localStorage.removeItem(LS.token(code));
        localStorage.removeItem(LS.lastRoom);
        this.patch({ gameOverScores: scores });
        const top = scores[0];
        if (top) this.banner(this.isMe(top.playerId) ? "win" : "gold", this.isMe(top.playerId) ? "🏆 你是第一名!" : `🏆 ${top.playerName} 获胜`);
        break;
      }

      default:
        break; // 未知事件忽略
    }
  }
}

export const client = new GameClient();
