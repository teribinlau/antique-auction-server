// 与 PROTOCOL.md 一一对应的类型定义。字段名不得改动。

export const DENOMS = ["0", "10", "50", "100", "200", "500"] as const;
export type Denom = (typeof DENOMS)[number];
/** money/exposedMoney/paid：key 是字符串面值，"0" 为废钞（凑张数不值钱） */
export type Money = Partial<Record<Denom, number>>;

export function moneyTotal(m: Money): number {
  return DENOMS.reduce((s, d) => s + Number(d) * (m[d] ?? 0), 0);
}
export function moneyCount(m: Money): number {
  return DENOMS.reduce((s, d) => s + (m[d] ?? 0), 0);
}

export interface Card {
  cardId: string;
  cardName: string;
  flavorText: string;
  setId: string;
  setName: string;
  setScore: number;
}

export interface MePlayer {
  playerId: number;
  playerName: string;
  money: Money;
  antiques: Card[];
  completeSets: string[];
}

export interface Opponent {
  playerId: number;
  playerName: string;
  /** 钞票总张数（非古董数）——诈唬的唯一信息来源 */
  handCount: number;
  antiques: Card[];
  completeSets: string[];
}

export type Phase = "WAITING" | "AUCTION" | "SNIPE" | "PRIVATE_DEAL" | "GAME_OVER";

/** state_update.state —— 游戏中权威全量快照 */
export interface GameStateView {
  myId: number;
  phase: Phase;
  currentPlayerId: number;
  deckSize: number;
  silverIngotCount: number;
  me: MePlayer;
  opponents: Opponent[];
  auctionCard: Card | null;
  highestBid: number;
  highestBidder: number;
  dealInitiator: number;
  dealTarget: number;
  dealSetId: string;
}

export interface RoomSummary {
  roomCode: string;
  roomName: string;
  playerCount: number;
  hasPassword: boolean;
}

export interface DealTarget {
  setId: string;
  targetId: number;
  tradeCount: number;
}

export interface Score {
  playerId: number;
  playerName: string;
  score: number;
}

export interface SnipePrompt {
  card: Card;
  highestBid: number;
  highestBidder: number;
  auctionerId: number;
}

/** deal_resolved 两种形态：普通 winnerId；连平掷币 tieForcedWinner */
export interface DealResolved {
  winnerId?: number;
  tieForcedWinner?: number;
  loserId: number;
  tradeCount: number;
  offerTotal: number;
  counterTotal: number;
  initiatorId: number;
  setId?: string;
}
export function effectiveWinnerId(d: DealResolved): number | undefined {
  return d.winnerId ?? d.tieForcedWinner;
}

/** 服务端事件（先看 event 字符串再取字段；未知事件忽略，绝不中断） */
export interface ServerEvent {
  event: string;
  [k: string]: unknown;
}
