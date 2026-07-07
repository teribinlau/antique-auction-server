// 套系主题：与 iOS SetTheme.swift 保持同一套配色 / 稀有度阈值。
// 图标用单个汉字（跨设备渲染一致，比 emoji 稳）。

import type { Card } from "./protocol";

export type Rarity = "common" | "fine" | "treasure" | "legendary";

export interface SetStyle {
  primary: string;
  secondary: string;
  glyph: string;
  name: string;
}

export const SET_STYLES: Record<string, SetStyle> = {
  lost_paintings:     { primary: "#47382e", secondary: "#856e54", glyph: "画", name: "失传古画" },
  imperial_jade:      { primary: "#1a6652", secondary: "#52a885", glyph: "玉", name: "帝王玉器" },
  imperial_porcelain: { primary: "#294785", secondary: "#6b94d1", glyph: "瓷", name: "御窑瓷器" },
  silver_ingots:      { primary: "#57616b", secondary: "#9ea8b3", glyph: "银", name: "官库银锭" },
  silver_dollars:     { primary: "#4d5c75", secondary: "#8fa1bd", glyph: "洋", name: "龙洋银币" },
  copper_coins:       { primary: "#734d24", secondary: "#bd8a47", glyph: "钱", name: "镇库铜钱" },
  seals:              { primary: "#852929", secondary: "#c7574d", glyph: "印", name: "名家印玺" },
  stamps:             { primary: "#2e614d", secondary: "#669e80", glyph: "邮", name: "绝版邮票" },
  curios:             { primary: "#66523d", secondary: "#a38a6b", glyph: "珍", name: "老宅奇珍" },
  paper_money:        { primary: "#6b6138", secondary: "#ad9e66", glyph: "钞", name: "旧朝纸币" },
};

const FALLBACK_STYLE: SetStyle = { primary: "#4d5461", secondary: "#757c8a", glyph: "?", name: "未知" };

export function styleFor(setId: string): SetStyle {
  return SET_STYLES[setId] ?? FALLBACK_STYLE;
}

/** setScore → 稀有度。阈值与 iOS 一致：≥800 传世，≥350 珍品，≥160 精品。 */
export function rarityFor(score: number): Rarity {
  if (score >= 800) return "legendary";
  if (score >= 350) return "treasure";
  if (score >= 160) return "fine";
  return "common";
}

export const RARITY_LABEL: Record<Rarity, string> = {
  common: "普通",
  fine: "精品",
  treasure: "珍品",
  legendary: "传世",
};

export const RARITY_ACCENT: Record<Rarity, string> = {
  common: "#8c8c94",
  fine: "#338c9e",
  treasure: "#85529e",
  legendary: "#cc9e47",
};

export const GOLD = "#d4a957";

export function isElevated(r: Rarity): boolean {
  return r === "treasure" || r === "legendary";
}

export function cardRarity(card: Card): Rarity {
  return rarityFor(card.setScore);
}

/** 卡面插画地址（make_web_art.py 生成的压缩图；缺图时 CardView 自动回退渐变） */
export function cardArtUrl(cardId: string): string {
  return `/cards/${cardId}.webp`;
}
