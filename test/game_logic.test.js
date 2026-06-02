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

// ─── Test 3: Payment failure advances turn (regression for Task 1) ────────

test("付款失败推进回合：payment_failed + turn_changed，phase=AUCTION，auctionCard=null", () => {
  // Give Alice too little money so she can't pay highestBid=300
  const game = makeSnipeState({ highestBid: 300 });
  game.players[0].money = makeMoney(50); // Alice only has 50
  // Add more cards to deck so the game doesn't end immediately
  game.deck = [
    { cardId: "paper_money_01", cardName: "全国粮票", flavorText: "", setId: "paper_money", setName: "旧朝纸币", setScore: 10 },
    { cardId: "paper_money_02", cardName: "大黑十",   flavorText: "", setId: "paper_money", setName: "旧朝纸币", setScore: 10 },
  ];

  // Alice tries to snipe but only pays 50 (< 300)
  const paid = { 50: 1 };
  const events = game.actionSnipe(true, paid);
  const evArr = Array.isArray(events) ? events : [events];

  const failEv    = evArr.find(e => e.event === "payment_failed");
  const turnEv    = evArr.find(e => e.event === "turn_changed");

  assert.ok(failEv,  "应包含 payment_failed 事件");
  assert.ok(turnEv,  "应包含 turn_changed 事件（回合推进）");

  assert.strictEqual(game.auctionCard, null, "auctionCard 应为 null（流拍清空）");
  assert.strictEqual(game.phase, "AUCTION",  "phase 应回到 AUCTION，不应卡在 SNIPE");
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

// ─── Test 5: Private deal tie → coin flip ────────────────────────────────

test("私盘连平掷币：两次平局后 stub Math.random 决出赢家，双方各付各自报价", () => {
  const game = new GameState(["Alice", "Bob"]);
  game.deck = [];
  game.phase = "AUCTION";
  game.currentPlayerIndex = 0;

  const aliceCard = { cardId: "stamps_01", cardName: "庚申猴票", flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 };
  const bobCard   = { cardId: "stamps_02", cardName: "蓝军邮",   flavorText: "", setId: "stamps", setName: "绝版邮票", setScore: 90 };
  game.players[0].antiques = [aliceCard];
  game.players[1].antiques = [bobCard];

  // Both need 100-yuan bills to match equalOffer = {100:1}
  game.players[0].money = { 0: 0, 10: 0, 50: 0, 100: 5, 200: 0, 500: 0 }; // 500
  game.players[1].money = { 0: 0, 10: 0, 50: 0, 100: 5, 200: 0, 500: 0 }; // 500

  game.startPrivateDeal(0, 1, "stamps");

  const equalOffer = { 100: 1 }; // both offer 100 → tie

  // First tie
  game.submitDealOffer(0, equalOffer);
  const tieResult1 = game.submitDealOffer(1, equalOffer);
  const tieArr1 = Array.isArray(tieResult1) ? tieResult1 : [tieResult1];
  assert.ok(tieArr1.find(e => e.event === "deal_tie"), "第一次平局应触发 deal_tie");
  assert.strictEqual(game.dealTieCount, 1);

  // Second tie triggers coin flip — stub Math.random so Alice wins (< 0.5 → initiator wins)
  const origRandom = Math.random;
  Math.random = () => 0.3; // < 0.5 → coinFlip = true → winner = initiator = Alice

  game.submitDealOffer(0, equalOffer);
  const aliceBefore = totalMoney(game.players[0].money);
  const bobBefore   = totalMoney(game.players[1].money);

  const events2 = game.submitDealOffer(1, equalOffer);
  Math.random = origRandom; // restore

  const evArr2  = Array.isArray(events2) ? events2 : [events2];
  const dealEv2 = evArr2.find(e => e.event === "deal_resolved");

  assert.ok(dealEv2, "第二次平局应有 deal_resolved 事件");
  assert.ok(dealEv2.tieForcedWinner !== undefined, "应有 tieForcedWinner 字段");
  assert.strictEqual(dealEv2.tieForcedWinner, 0, "Math.random=0.3 时 Alice 应赢");

  // Both paid their own offer (100)
  // Alice: paid 100 (offer), received 100 (counter) → net 0
  assert.strictEqual(totalMoney(game.players[0].money), aliceBefore - 100 + 100, "Alice 净变动为 0");
  assert.strictEqual(totalMoney(game.players[1].money), bobBefore   - 100 + 100, "Bob 净变动为 0");

  // Alice wins so should now have Bob's card
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

  const moneyTotal = totalMoney(alice.money);
  const score      = game._getScore(alice);
  assert.strictEqual(score, moneyTotal + setScore, `得分应为 money(${moneyTotal}) + 套牌分(${setScore})`);
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
