/**
 * Unit tests for GameState in game_logic.js
 * Uses Node built-in test runner: node --test
 */
"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const { GameState } = require("../game_logic");

// ─── helpers ────────────────────────────────────────────────────────────────

function makeMoney(total) {
  // build a money bag with exact denomination breakdown
  const faces = [500, 200, 100, 50, 10, 0];
  const result = { 0: 2, 10: 0, 50: 0, 100: 0, 200: 0, 500: 0 };
  let rem = total;
  for (const f of [500, 200, 100, 50, 10]) {
    const cnt = Math.floor(rem / f);
    result[f] = cnt;
    rem -= f * cnt;
  }
  return result;
}

function totalMoney(money) {
  let t = 0;
  for (const f in money) t += parseInt(f) * money[f];
  return t;
}

// Build a minimal 2-player GameState with a pre-loaded auctionCard and
// SNIPE phase so actionSnipe() can be called immediately.
function makeSnipeState({ auctionCardSetId = "stamps", highestBid = 100 } = {}) {
  const game = new GameState(["Alice", "Bob"]);
  // Clear the deck so we can control things
  game.deck = [];
  game.phase = "SNIPE";
  game.currentPlayerIndex = 0; // Alice = auctioneer

  game.auctionCard = {
    cardId: `${auctionCardSetId}_01`,
    cardName: "Test Card",
    flavorText: "",
    setId: auctionCardSetId,
    setName: "Test Set",
    setScore: 90,
  };

  game.highestBid = highestBid;
  game.highestBidder = 1; // Bob is highest bidder
  game.bids = { 1: highestBid };
  game.passed = { 0: true, 1: false };

  // Give both players enough money using denominations that match test paid objects
  // Alice (auctioneer) gets 1000 in 100-yuan bills so paid={100:1} deducts correctly
  game.players[0].money = { 0: 0, 10: 0, 50: 0, 100: 10, 200: 0, 500: 0 }; // 1000
  // Bob gets 500 in 100-yuan bills so splitIntoBills(100)={100:1} deducts correctly
  game.players[1].money = { 0: 0, 10: 0, 50: 0, 100: 5,  200: 0, 500: 0 }; // 500

  return game;
}

// ─── Test 1: Snipe success ────────────────────────────────────────────────

test("截拍成功：拍卖人付款 >= highestBid，出价者收钱，牌归拍卖人", () => {
  const game = makeSnipeState({ highestBid: 100 });
  const aliceBefore = totalMoney(game.players[0].money);
  const bobBefore   = totalMoney(game.players[1].money);

  // Alice snipes by paying exactly 100 (one 100-yuan bill)
  const paid = { 100: 1 };
  const events = game.actionSnipe(true, paid);
  const evArr = Array.isArray(events) ? events : [events];

  const snipeEv = evArr.find(e => e.event === "snipe_success");
  assert.ok(snipeEv, "应有 snipe_success 事件");
  assert.strictEqual(snipeEv.winnerId, 0, "赢家应是 Alice(0)");

  // Alice paid 100, Bob received 100
  assert.strictEqual(totalMoney(game.players[0].money), aliceBefore - 100, "Alice 应少 100");
  assert.strictEqual(totalMoney(game.players[1].money), bobBefore + 100,   "Bob 应多 100");

  // Card went to Alice
  assert.ok(game.players[0].antiques.some(c => c.cardId === "stamps_01"), "牌应在 Alice 手中");
  assert.strictEqual(game.auctionCard, null, "auctionCard 应清空");
});

// ─── Test 2: Snipe declined (放手) ───────────────────────────────────────

test("放手：出价者按 highestBid 付款得牌，拍卖人收到钱", () => {
  const game = makeSnipeState({ highestBid: 100 });
  const aliceBefore = totalMoney(game.players[0].money);
  const bobBefore   = totalMoney(game.players[1].money);

  // Alice declines (doSnipe = false)
  const events = game.actionSnipe(false, {});
  const evArr = Array.isArray(events) ? events : [events];

  const declineEv = evArr.find(e => e.event === "snipe_declined");
  assert.ok(declineEv, "应有 snipe_declined 事件");
  assert.strictEqual(declineEv.winnerId, 1, "赢家应是 Bob(1)");

  // Bob paid 100, Alice received 100
  assert.strictEqual(totalMoney(game.players[1].money), bobBefore - 100,   "Bob 应少 100");
  assert.strictEqual(totalMoney(game.players[0].money), aliceBefore + 100, "Alice 应多 100");

  // Card went to Bob
  assert.ok(game.players[1].antiques.some(c => c.cardId === "stamps_01"), "牌应在 Bob 手中");
  assert.strictEqual(game.auctionCard, null, "auctionCard 应清空");
});

// ─── Test 3: Payment failure re-auctions the same card (not discarded) ────

test("付款失败重拍同一张：payment_failed + 重新开拍，不卡在 SNIPE，牌不丢弃", () => {
  const game = makeSnipeState({ highestBid: 300 });
  game.players[0].money = makeMoney(50); // Alice(拍卖人) 只有 50，付不起 300
  game.deck = [
    { cardId: "paper_money_01", cardName: "全国粮票", flavorText: "", setId: "paper_money", setName: "旧朝纸币", setScore: 10 },
    { cardId: "paper_money_02", cardName: "大黑十",   flavorText: "", setId: "paper_money", setName: "旧朝纸币", setScore: 10 },
  ];
  const failedCard = game.auctionCard;

  // Alice 试图截拍但只付 50 (< 300) → 付款失败
  const events = game.actionSnipe(true, { 50: 1 });
  const evArr = Array.isArray(events) ? events : [events];

  const failEv = evArr.find(e => e.event === "payment_failed");
  assert.ok(failEv, "应包含 payment_failed 事件");
  assert.strictEqual(failEv.playerId, 0, "失败者是 Alice(0)");
  assert.ok(failEv.exposedMoney, "应亮出失败者手牌");

  // 原版：同一张牌重新拍卖，不丢弃、不卡在 SNIPE
  assert.strictEqual(game.phase, "AUCTION", "phase 应回到 AUCTION（重拍），不卡在 SNIPE");
  assert.ok(game.auctionCard, "auctionCard 不应清空（同一张牌重拍）");
  assert.strictEqual(game.auctionCard.cardId, failedCard.cardId, "应是同一张牌");
  assert.ok(evArr.find(e => e.event === "auction_started"), "应重新开拍 (auction_started)");
  const bidTurn = evArr.find(e => e.event === "bid_turn");
  assert.ok(bidTurn, "应给出新的 bid_turn");
  assert.strictEqual(bidTurn.playerId, 1, "应轮到 Bob(1) 竞拍（拍卖人不竞拍）");
});

// ─── Test 4: Private deal normal win/loss ─────────────────────────────────

test("私盘普通胜负：出价高者赢得牌，双方按各自报价转移金钱", () => {
  const game = new GameState(["Alice", "Bob"]);
  game.deck = [];
  game.phase = "AUCTION";
  game.currentPlayerIndex = 0;

  const sharedCard = { cardId: "stamps_01", cardName: "庚申猴票", flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 };
  game.players[0].antiques = [sharedCard]; // Alice holds stamps_01
  game.players[1].antiques = [
    { cardId: "stamps_02", cardName: "蓝军邮", flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 },
  ]; // Bob holds stamps_02

  // Alice needs 200-yuan bills to offer {200:1}; Bob needs 100-yuan bills to counter {100:1}
  game.players[0].money = { 0: 0, 10: 0, 50: 0, 100: 1, 200: 2, 500: 0 }; // 400+100=500
  game.players[1].money = { 0: 0, 10: 0, 50: 0, 100: 5, 200: 0, 500: 0 }; // 500

  // Alice initiates private deal targeting Bob for stamps
  game.startPrivateDeal(0, 1, "stamps");
  assert.strictEqual(game.phase, "PRIVATE_DEAL");

  // Alice offers 200
  const aliceOffer = { 200: 1 };
  game.submitDealOffer(0, aliceOffer); // Alice submits offer

  const bobBefore   = totalMoney(game.players[1].money); // 500
  const aliceBefore = totalMoney(game.players[0].money); // 500

  // Bob counters with 100 (lower than 200, so Alice wins)
  const bobCounter  = { 100: 1 };
  const events      = game.submitDealOffer(1, bobCounter);
  const evArr       = Array.isArray(events) ? events : [events];

  const dealEv = evArr.find(e => e.event === "deal_resolved");
  assert.ok(dealEv, "应有 deal_resolved 事件");
  assert.strictEqual(dealEv.winnerId, 0, "Alice 应为赢家（出价更高）");
  assert.strictEqual(dealEv.loserId,  1, "Bob 应为输家");

  // Alice paid 200, received 100 net -100
  assert.strictEqual(totalMoney(game.players[0].money), aliceBefore - 200 + 100, "Alice 净损失 100");
  // Bob received 200, paid 100 net +100
  assert.strictEqual(totalMoney(game.players[1].money), bobBefore + 200 - 100, "Bob 净得 100");

  // Alice should now hold stamps_02 (taken from Bob)
  assert.ok(game.players[0].antiques.some(c => c.cardId === "stamps_02"), "Alice 应得到 Bob 的邮票");
});

// ─── Test 5: Private deal tie → re-bid (no coin flip) ─────────────────────

test("私盘平局重标：平局触发 deal_tie 并清空报价，重标后由高者胜（无掷币）", () => {
  const game = new GameState(["Alice", "Bob"]);
  game.deck = [];
  game.phase = "AUCTION";
  game.currentPlayerIndex = 0;

  const aliceCard = { cardId: "stamps_01", cardName: "庚申猴票", flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 };
  const bobCard   = { cardId: "stamps_02", cardName: "蓝军邮",   flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 };
  game.players[0].antiques = [aliceCard];
  game.players[1].antiques = [bobCard];
  game.players[0].money = { 0: 0, 10: 0, 50: 0, 100: 5, 200: 0, 500: 0 }; // 500
  game.players[1].money = { 0: 0, 10: 0, 50: 0, 100: 5, 200: 0, 500: 0 }; // 500

  game.startPrivateDeal(0, 1, "stamps");

  // 第一轮：双方都出 100 → 平局
  game.submitDealOffer(0, { 100: 1 });
  const tieRes = game.submitDealOffer(1, { 100: 1 });
  const tieArr = Array.isArray(tieRes) ? tieRes : [tieRes];
  assert.ok(tieArr.find(e => e.event === "deal_tie"), "平局应触发 deal_tie");
  assert.strictEqual(game.dealTieCount, 1);
  assert.deepStrictEqual(game.dealOffer, {}, "平局后发起方报价应清空（待重标）");
  assert.deepStrictEqual(game.dealCounter, {}, "平局后目标报价应清空（待重标）");
  // 平局本身不动钱、不动牌
  assert.strictEqual(totalMoney(game.players[0].money), 500);
  assert.strictEqual(totalMoney(game.players[1].money), 500);

  // 重标：Alice 出 200（两张 100），Bob 出 100 → Alice 胜（无掷币）
  const aliceBefore = totalMoney(game.players[0].money); // 500
  const bobBefore   = totalMoney(game.players[1].money); // 500
  game.submitDealOffer(0, { 100: 2 });
  const res2 = game.submitDealOffer(1, { 100: 1 });
  const arr2 = Array.isArray(res2) ? res2 : [res2];
  const dealEv = arr2.find(e => e.event === "deal_resolved");
  assert.ok(dealEv, "重标后应有 deal_resolved");
  assert.strictEqual(dealEv.winnerId, 0, "Alice 出价更高应获胜");
  assert.strictEqual(dealEv.tieForcedWinner, undefined, "不应再有掷币 tieForcedWinner 字段");

  // Alice −200 +100 = −100；Bob +200 −100 = +100
  assert.strictEqual(totalMoney(game.players[0].money), aliceBefore - 100, "Alice 净 −100");
  assert.strictEqual(totalMoney(game.players[1].money), bobBefore + 100, "Bob 净 +100");
  assert.ok(game.players[0].antiques.some(c => c.cardId === "stamps_02"), "Alice 应得到 Bob 的邮票");
});

// ─── Test 6: Complete set scoring ────────────────────────────────────────

test("集齐套牌计分：4 张牌进 completeSets，_getScore 计入套分", () => {
  const game = new GameState(["Alice", "Bob"]);
  const alice = game.players[0];

  const setId = "stamps";
  const setScore = 90;

  alice.antiques = [
    { cardId: "stamps_01", cardName: "庚申猴票",   flavorText: "", setId, setName: "绝版邮票", setScore },
    { cardId: "stamps_02", cardName: "蓝军邮",     flavorText: "", setId, setName: "绝版邮票", setScore },
    { cardId: "stamps_03", cardName: "梅兰芳小型张", flavorText: "", setId, setName: "绝版邮票", setScore },
    { cardId: "stamps_04", cardName: "山河一片红",  flavorText: "", setId, setName: "绝版邮票", setScore },
  ];

  // Trigger set-completion check
  game._checkCompleteSet(0);

  assert.ok(alice.completeSets.includes(setId), "completeSets 应包含 stamps");

  // 原版计分：(套分之和) × 套数；现金不计。单套 → setScore × 1，且无视现金。
  assert.ok(totalMoney(alice.money) > 0, "alice 应持有起始现金（用于验证现金不计分）");
  assert.strictEqual(game._getScore(alice), setScore, `单套得分应为 ${setScore}（现金不计入）`);
});

// ─── Test 7: Silver ingot bonus capped ───────────────────────────────────

test("银锭奖励不溢出：silverIngotCount 封顶在 SILVER_INGOT_BONUS.length-1，不越界", () => {
  // SILVER_INGOT_BONUS = [0, 50, 100, 200, 500], length = 5, max index = 4
  const SILVER_INGOT_BONUS = [0, 50, 100, 200, 500];
  const maxCount = SILVER_INGOT_BONUS.length - 1; // 4

  const game = new GameState(["Alice", "Bob"]);

  // Build a deck of extra silver_ingot cards beyond the max so we can trigger
  // startAuction many times
  const makeIngotCard = (n) => ({
    cardId: `silver_ingots_0${n}`,
    cardName: `银锭${n}`,
    flavorText: "",
    setId: "silver_ingots",
    setName: "官库银锭",
    setScore: 500,
  });
  // 10 silver ingot cards in the deck
  game.deck = Array.from({ length: 10 }, (_, i) => makeIngotCard(i + 1));
  game.phase = "AUCTION";

  let bonusEvents = [];

  for (let i = 0; i < 7; i++) {
    game.currentPlayerIndex = 0;
    const events = game.startAuction();
    const evArr  = Array.isArray(events) ? events : [events];
    const bonusEv = evArr.find(e => e.event === "silver_bonus");
    if (bonusEv) bonusEvents.push(bonusEv);

    // Reset SNIPE state to allow next startAuction without going through snipe
    game.auctionCard = null;
    game.phase = "AUCTION";
    game.deck.unshift(makeIngotCard(100 + i)); // put back something to draw
  }

  assert.ok(game.silverIngotCount <= maxCount,
    `silverIngotCount(${game.silverIngotCount}) 不应超过上限 ${maxCount}`);

  // All bonus events should have valid bonus values (not undefined/NaN)
  for (const ev of bonusEvents) {
    assert.ok(typeof ev.bonus === "number" && !isNaN(ev.bonus),
      `bonus 应为数字，got ${ev.bonus}`);
    assert.ok(ev.bonus >= 0, "bonus 不应为负数");
    // Verify it matches SILVER_INGOT_BONUS array
    const expectedBonus = SILVER_INGOT_BONUS[ev.count] !== undefined
      ? SILVER_INGOT_BONUS[ev.count]
      : 0;
    assert.strictEqual(ev.bonus, expectedBonus,
      `bonus(${ev.bonus}) 应对应 SILVER_INGOT_BONUS[${ev.count}]=${expectedBonus}`);
  }

  // Bonus should only trigger up to maxCount times (count 1..4)
  assert.ok(bonusEvents.length <= maxCount,
    `奖励事件数量(${bonusEvents.length}) 不应超过上限次数 ${maxCount}`);
});

// ─── Test 8: 放手·不找零自动付款（回归：曾错扣 0、凭空造钱）──────────────

test("放手·不找零：出价者无对应面值时用最小的更大面值付款（回归：曾扣 0 白拿牌）", () => {
  // Bob(出价者) 出价 10，但手里只有 废钞×2 与 50×2，没有 10 面值。
  // 不找零规则下，最小 ≥10 的真实钞票是一张 50，应扣 50（而非旧 bug 的扣 0）。
  const game = makeSnipeState({ highestBid: 10 });
  game.players[1].money = { 0: 2, 10: 0, 50: 2, 100: 0, 200: 0, 500: 0 }; // 值 100
  game.players[0].money = { 0: 0, 10: 0, 50: 0, 100: 0, 200: 0, 500: 0 }; // 值 0

  const bobBefore   = totalMoney(game.players[1].money); // 100
  const aliceBefore = totalMoney(game.players[0].money); // 0

  const events = game.actionSnipe(false, {}); // Alice 放手
  const evArr  = Array.isArray(events) ? events : [events];
  assert.ok(evArr.find(e => e.event === "snipe_declined"), "应有 snipe_declined 事件");

  // 扣的是一张 50（剩 1 张），废钞不参与支付（原样保留）。
  assert.strictEqual(game.players[1].money[50], 1, "Bob 应被扣一张 50（剩 1 张）");
  assert.strictEqual(game.players[1].money[0],  2, "废钞不参与支付，应原样保留 2 张");

  // 金额：Bob 净少 50，Alice 净得 50。
  assert.strictEqual(totalMoney(game.players[1].money), bobBefore - 50,   "Bob 应净少 50（而非 0）");
  assert.strictEqual(totalMoney(game.players[0].money), aliceBefore + 50, "Alice 应净得 50");

  // 守恒：系统内金钱总量不变（旧 bug 会凭空给拍卖人造一张 10，破坏守恒）。
  assert.strictEqual(
    totalMoney(game.players[0].money) + totalMoney(game.players[1].money),
    aliceBefore + bobBefore,
    "两人金钱总额应守恒（不凭空产生/消失）"
  );

  // 牌归 Bob。
  assert.ok(game.players[1].antiques.some(c => c.cardId === "stamps_01"), "牌应归 Bob");
});

// ─── Test 9: 私盘换牌·不均分（赢家拿走输家整套持有）────────────────────

test("私盘换牌·不均分：赢家拿走输家该套全部牌（1 vs 3 → 4‑0，曾只换 min=1）", () => {
  const game = new GameState(["Alice", "Bob"]);
  game.deck = [];
  game.phase = "AUCTION";
  game.currentPlayerIndex = 0;

  const mk = (n) => ({ cardId: `stamps_0${n}`, cardName: "x", flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 });
  game.players[0].antiques = [mk(1)];            // Alice 1 张
  game.players[1].antiques = [mk(2), mk(3), mk(4)]; // Bob 3 张（合计 4）
  game.players[0].money = { 0: 0, 10: 0, 50: 0, 100: 5, 200: 0, 500: 0 };
  game.players[1].money = { 0: 0, 10: 0, 50: 0, 100: 5, 200: 0, 500: 0 };

  const stamps = (p) => p.antiques.filter(c => c.setId === "stamps").length;

  game.startPrivateDeal(0, 1, "stamps");      // Alice 发起
  game.submitDealOffer(0, { 100: 2 });        // Alice 出 200
  const res = game.submitDealOffer(1, { 100: 1 }); // Bob 出 100 → Alice 胜
  const arr = Array.isArray(res) ? res : [res];
  const ev  = arr.find(e => e.event === "deal_resolved");
  assert.ok(ev, "应有 deal_resolved");
  assert.strictEqual(ev.winnerId, 0, "Alice 应获胜");

  // 关键：赢家拿走输家该套全部牌 → Alice 4 / Bob 0（旧 min 逻辑会停在 2‑2）。
  assert.strictEqual(stamps(game.players[0]), 4, "Alice 应集齐 4 张");
  assert.strictEqual(stamps(game.players[1]), 0, "Bob 应一张不剩");
  assert.strictEqual(ev.tradeCount, 3, "tradeCount 应为输家持有的 3 张");
  assert.ok(game.players[0].completeSets.includes("stamps"), "Alice 应集齐 stamps 套");
});

// ─── Test 10: 计分乘数（套分之和 × 套数）─────────────────────────────────

test("计分乘数：集齐 2 套时得分 =（套分之和）× 2，现金不计", () => {
  const game = new GameState(["Alice", "Bob"]);
  const alice = game.players[0];

  const mk = (setId, setName, setScore, n) => ({ cardId: `${setId}_0${n}`, cardName: "x", flavorText: "", setId, setName, setScore });
  alice.antiques = [
    mk("stamps", "绝版邮票", 90, 1), mk("stamps", "绝版邮票", 90, 2), mk("stamps", "绝版邮票", 90, 3), mk("stamps", "绝版邮票", 90, 4),
    mk("curios", "老宅奇珍", 40, 1), mk("curios", "老宅奇珍", 40, 2), mk("curios", "老宅奇珍", 40, 3), mk("curios", "老宅奇珍", 40, 4),
  ];
  game._checkCompleteSet(0);
  assert.strictEqual(alice.completeSets.length, 2, "应集齐 2 套");

  // (90 + 40) × 2 = 260；现金不计。
  assert.strictEqual(game._getScore(alice), (90 + 40) * 2, "两套得分应为 (90+40)×2 = 260");
});

// ─── Test 11: 英式拍卖（反复加价 / 退出即出局 / 必须加价）─────────────────

test("拍卖·英式：可反复加价、退出即出局，最高者进入截拍；不高于最高价被拒", () => {
  const game = new GameState(["A", "B", "C"]); // 0=拍卖人，1/2=竞拍者
  game.currentPlayerIndex = 0;
  game.phase = "AUCTION";
  game.deck = [
    { cardId: "stamps_01", cardName: "x", flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 },
    { cardId: "paper_money_01", cardName: "y", flavorText: "", setId: "paper_money", setName: "旧朝纸币", setScore: 10 },
  ];

  const started = game.startAuction();
  const firstTurn = started.find(e => e.event === "bid_turn");
  assert.ok(firstTurn, "开拍应给出第一个 bid_turn");
  const first = firstTurn.playerId;          // bidOrder[0]
  const second = first === 1 ? 2 : 1;

  // first 出 10 → 轮到 second
  let ev = game.placeBid(first, 10);
  assert.strictEqual(ev.find(e => e.event === "bid_turn").playerId, second, "应轮到另一位");

  // second 加到 20 → 轮回 first（关键：可再加价）
  ev = game.placeBid(second, 20);
  assert.strictEqual(ev.find(e => e.event === "bid_turn").playerId, first, "应回到 first，允许再加价");

  // first 出 20（不高于当前最高价 20）→ 被拒，最高价不变
  const rej = game.placeBid(first, 20);
  assert.ok(rej && rej.error, "不高于当前最高价的出价应被拒");
  assert.strictEqual(game.highestBid, 20, "被拒不应改变最高价");

  // first 加到 30 → 轮到 second
  ev = game.placeBid(first, 30);
  assert.strictEqual(ev.find(e => e.event === "bid_turn").playerId, second);

  // second 退出 → 无人再加价 → 进入截拍
  ev = game.passBid(second);
  assert.ok(ev.find(e => e.event === "snipe_prompt"), "无人再加价应进入 snipe_prompt");
  assert.strictEqual(game.highestBidder, first, "最高出价者应为 first");
  assert.strictEqual(game.highestBid, 30, "最高价应为 30");
  assert.strictEqual(game.phase, "SNIPE");

  // 结算后再出价应被拒（不再是任何人的回合）
  const rej2 = game.placeBid(second, 999);
  assert.ok(rej2 && rej2.error, "结算后出价应被拒");
});

// ─── Test 12: 全员放弃 → 流拍归拍卖人 ─────────────────────────────────────

test("拍卖·全员放弃：无人出价则流拍归拍卖人（no_bids）", () => {
  const game = new GameState(["A", "B", "C"]);
  game.currentPlayerIndex = 0;
  game.phase = "AUCTION";
  game.deck = [
    { cardId: "stamps_01", cardName: "x", flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 },
    { cardId: "paper_money_01", cardName: "y", flavorText: "", setId: "paper_money", setName: "旧朝纸币", setScore: 10 },
  ];

  game.startAuction();
  const order = game.bidOrder.slice(); // 两位竞拍者
  game.passBid(order[0]);
  const ev = game.passBid(order[1]);
  const noBids = ev.find(e => e.event === "no_bids");
  assert.ok(noBids, "全员放弃应触发 no_bids");
  assert.strictEqual(noBids.winnerId, 0, "牌应归拍卖人 A(0)");
  assert.ok(game.players[0].antiques.some(c => c.cardId === "stamps_01"), "拍卖人应得到该牌");
  assert.strictEqual(game.auctionCard, null, "auctionCard 应清空");
});

// ─── Test 13: 放手后出价者付不起（2 人局：重拍无人可买 → 牌归拍卖人）──────

test("放手·付不起：出价者超额诈唬付不起→亮钱；2 人局重拍无人可买→牌归拍卖人", () => {
  const game = makeSnipeState({ highestBid: 30 });
  // Bob(出价者, id 1) 只有 20，付不起 30（超额诈唬）
  game.players[1].money = { 0: 0, 10: 2, 50: 0, 100: 0, 200: 0, 500: 0 }; // 20
  game.players[0].money = { 0: 0, 10: 0, 50: 0, 100: 0, 200: 0, 500: 0 }; // Alice 0
  game.deck = [
    { cardId: "paper_money_01", cardName: "x", flavorText: "", setId: "paper_money", setName: "旧朝纸币", setScore: 10 },
  ];
  const card = game.auctionCard;

  // Alice 放手 → Bob 自动付款，但付不起
  const events = game.actionSnipe(false, {});
  const evArr = Array.isArray(events) ? events : [events];

  const failEv = evArr.find(e => e.event === "payment_failed");
  assert.ok(failEv, "应 payment_failed");
  assert.strictEqual(failEv.playerId, 1, "失败者是 Bob(1)");
  assert.ok(failEv.exposedMoney, "应亮出 Bob 手牌");

  // 2 人局：把失败者 Bob 排除后无人可竞拍 → 牌归拍卖人 Alice(0)
  const noBids = evArr.find(e => e.event === "no_bids");
  assert.ok(noBids, "无其他竞拍者 → no_bids");
  assert.strictEqual(noBids.winnerId, 0, "牌归拍卖人 Alice(0)");
  assert.ok(game.players[0].antiques.some(c => c.cardId === card.cardId), "Alice 应拿到该古董");
  assert.strictEqual(game.auctionCard, null, "auctionCard 应清空（已归属拍卖人）");
});
