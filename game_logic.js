// 游戏数据
const SET_SCORES = {
  lost_paintings: 1000,
  imperial_jade: 800,
  imperial_porcelain: 650,
  silver_ingots: 500,
  silver_dollars: 350,
  copper_coins: 250,
  seals: 160,
  stamps: 90,
  curios: 40,
  paper_money: 10,
};

const SILVER_INGOT_BONUS = [0, 50, 100, 200, 500];

const STARTING_MONEY = { 0: 2, 10: 4, 50: 1, 100: 0, 200: 0, 500: 0 };

const CARDS_RAW = [
  { setId: "paper_money", setName: "旧朝纸币", setScore: 10, cards: [
    { cardId: "paper_money_01", cardName: "全国粮票", flavorText: "那年那月的口粮凭证，如今只剩旧时代的烟火气。" },
    { cardId: "paper_money_02", cardName: "大黑十", flavorText: "确实是大黑十，因为它黑得有点过于彻底了。" },
    { cardId: "paper_money_03", cardName: "错版拾圆钞", flavorText: "这个错版比较离谱，硬是把十块印成了一块。" },
    { cardId: "paper_money_04", cardName: "绝版练功券", flavorText: "当年不值钱，不过传说摸过的人都会发财。" },
  ]},
  { setId: "curios", setName: "老宅奇珍", setScore: 40, cards: [
    { cardId: "curios_01", cardName: "黄铜手炉", flavorText: "旧宅深冬里捧过的暖意，如今成了案头小珍。" },
    { cardId: "curios_02", cardName: "旧木算盘", flavorText: "珠响已停，留下的是年月磨出来的包浆。" },
    { cardId: "curios_03", cardName: "紫铜墨盒", flavorText: "文房旧物不喧哗，细看才知道有味道。" },
    { cardId: "curios_04", cardName: "老宅座钟", flavorText: "钟针不走了，但它看起来比谁都像见过世面。" },
  ]},
  { setId: "stamps", setName: "绝版邮票", setScore: 90, cards: [
    { cardId: "stamps_01", cardName: "庚申猴票", flavorText: "这种邮票听说很赚钱，可惜先缺了一个角。" },
    { cardId: "stamps_02", cardName: "蓝军邮", flavorText: "颜色是蓝的，至于是不是原来就这么蓝，很难说。" },
    { cardId: "stamps_03", cardName: "梅兰芳小型张", flavorText: "戏里戏外，看到的都是哥哥的影子。" },
    { cardId: "stamps_04", cardName: "山河一片红", flavorText: "这是传世不超过一百张里的第101张。" },
  ]},
  { setId: "seals", setName: "名家印玺", setScore: 160, cards: [
    { cardId: "seals_01", cardName: "寿山石印", flavorText: "石质温润，可惜上面刻了个凹凸曼。" },
    { cardId: "seals_02", cardName: "田黄私印", flavorText: "确实是黄的，只不过更接近番薯黄。" },
    { cardId: "seals_03", cardName: "白文官印", flavorText: "章法倒是规整，细看像刻了「到此一游」。" },
    { cardId: "seals_04", cardName: "螭钮印章", flavorText: "钮工一立，牌面是上去了，来路却没那么稳。" },
  ]},
  { setId: "copper_coins", setName: "镇库铜钱", setScore: 250, cards: [
    { cardId: "copper_coins_01", cardName: "咸丰重宝", flavorText: "钱文厚重，一看就是能镇场子的硬货。" },
    { cardId: "copper_coins_02", cardName: "大观通宝", flavorText: "瘦金味是出来了，就是出得有点太整齐。" },
    { cardId: "copper_coins_03", cardName: "永乐通宝", flavorText: "名字很硬，底子看着也硬，只是硬得有点新。" },
    { cardId: "copper_coins_04", cardName: "太平天国钱", flavorText: "年号确实特殊，特殊到让人先想问一句哪来的。" },
  ]},
  { setId: "silver_dollars", setName: "龙洋银币", setScore: 350, cards: [
    { cardId: "silver_dollars_01", cardName: "袁大头", flavorText: "认的人太多，仿的人显然也没少。" },
    { cardId: "silver_dollars_02", cardName: "江南龙洋", flavorText: "龙纹一开，银光有了，包浆像是昨晚刚补的。" },
    { cardId: "silver_dollars_03", cardName: "北洋光绪元宝", flavorText: "版别很多，门道很深，深到卖家自己都说不明白。" },
    { cardId: "silver_dollars_04", cardName: "船洋银元", flavorText: "看着常见，真碰上好品相也照样有人抬价。" },
  ]},
  { setId: "silver_ingots", setName: "官库银锭", setScore: 500, cards: [
    { cardId: "silver_ingots_01", cardName: "五十两官锭", flavorText: "一上桌就是大货气势，前提是真有五十两。" },
    { cardId: "silver_ingots_02", cardName: "库平码银锭", flavorText: "铭文清楚得有点过分，像是生怕别人看不见。" },
    { cardId: "silver_ingots_03", cardName: "漕运税银", flavorText: "带着旧朝财政味道的真金白银，闻着倒像刚出土。" },
    { cardId: "silver_ingots_04", cardName: "船形官银", flavorText: "形制一出来就知道不是普通散银，就是新得有点扎眼。" },
  ]},
  { setId: "imperial_porcelain", setName: "御窑瓷器", setScore: 650, cards: [
    { cardId: "imperial_porcelain_01", cardName: "青花龙纹瓶", flavorText: "龙纹在身，气场先到，开门先看底。" },
    { cardId: "imperial_porcelain_02", cardName: "粉彩花卉碗", flavorText: "一眼富贵，第二眼就开始想哪儿不对。" },
    { cardId: "imperial_porcelain_03", cardName: "斗彩鸡缸杯", flavorText: "小器不小，越小越贵，也越容易离谱。" },
    { cardId: "imperial_porcelain_04", cardName: "祭红梅瓶", flavorText: "釉色压场，懂的人会先加价，不懂的人会先上头。" },
  ]},
  { setId: "imperial_jade", setName: "帝王玉器", setScore: 800, cards: [
    { cardId: "imperial_jade_01", cardName: "白玉龙佩", flavorText: "玉色一净，身价就上去了，风险也一起上去了。" },
    { cardId: "imperial_jade_02", cardName: "和田玉璧", flavorText: "圆璧无声，但每一道沁色都在讲故事。" },
    { cardId: "imperial_jade_03", cardName: "御制玉如意", flavorText: "名字里就带着贵气，真假里也带着运气。" },
    { cardId: "imperial_jade_04", cardName: "螭龙玉玺", flavorText: "像这种东西，天生就该放高位，也天生容易出事。" },
  ]},
  { setId: "lost_paintings", setName: "失传古画", setScore: 1000, cards: [
    { cardId: "lost_paintings_01", cardName: "山水长卷", flavorText: "长卷一展，压轴感立刻就出来了。" },
    { cardId: "lost_paintings_02", cardName: "宫廷仕女图", flavorText: "人物一立住，整场气氛都不一样。" },
    { cardId: "lost_paintings_03", cardName: "故宫鸟谱", flavorText: "落款处隐约写着蒋廷锡，隐约到需要先深吸一口气。" },
    { cardId: "lost_paintings_04", cardName: "富春山居图", flavorText: "残，不代表便宜；但太像了，反而更吓人。" },
  ]},
];

function buildDeck() {
  const deck = [];
  for (const set of CARDS_RAW) {
    for (const card of set.cards) {
      deck.push({ cardId: card.cardId, cardName: card.cardName, flavorText: card.flavorText, setId: set.setId, setName: set.setName, setScore: set.setScore });
    }
  }
  // shuffle
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

function addMoney(money, paid) {
  for (const face in paid) {
    const f = parseInt(face);
    money[f] = (money[f] || 0) + paid[face];
  }
}

function deductMoneyExact(money, paid) {
  for (const face in paid) {
    const f = parseInt(face);
    money[f] = Math.max(0, (money[f] || 0) - paid[face]);
  }
}

function getTotalMoney(money) {
  let total = 0;
  for (const face in money) total += parseInt(face) * money[face];
  return total;
}

function getAntiquesBySet(antiques, setId) {
  return antiques.filter(c => c.setId === setId);
}

function splitIntoBills(amount) {
  const faces = [500, 200, 100, 50, 10];
  const result = {};
  let remaining = amount;
  for (const face of faces) {
    const count = Math.floor(remaining / face);
    if (count > 0) { result[face] = count; remaining -= face * count; }
  }
  return result;
}

class GameState {
  constructor(playerNames) {
    this.players = playerNames.map((name, i) => ({
      playerId: i,
      playerName: name,
      money: { ...STARTING_MONEY },
      antiques: [],
      completeSets: [],
    }));
    this.deck = buildDeck();
    this.currentPlayerIndex = 0;
    this.phase = "WAITING"; // WAITING | AUCTION | SNIPE | PRIVATE_DEAL | GAME_OVER
    this.silverIngotCount = 0;

    // 竞拍状态
    this.auctionCard = null;
    this.bids = {};   // playerId -> amount
    this.passed = {}; // playerId -> bool
    this.highestBidder = -1;
    this.highestBid = 0;

    // 私盘状态
    this.dealInitiator = -1;
    this.dealTarget = -1;
    this.dealSetId = "";
    this.dealOffer = {};
    this.dealCounter = {};
    this.dealTieCount = 0;
  }

  getPlayer(id) { return this.players.find(p => p.playerId === id); }
  currentPlayer() { return this.players[this.currentPlayerIndex]; }

  // ── 回合推进 ──────────────────────────────────────────────
  nextTurn() {
    if (this.deck.length === 0 && !this._canAnyPrivateDeal()) {
      return this._endGame();
    }
    if (this.deck.length === 0 && this.getPrivateDealTargets(this.currentPlayer().playerId).length === 0) {
      return this._advanceTurn();
    }
    this.phase = "AUCTION";
    return { event: "turn_changed", playerId: this.currentPlayer().playerId, deckSize: this.deck.length };
  }

  _advanceTurn() {
    this.currentPlayerIndex = (this.currentPlayerIndex + 1) % this.players.length;
    return this.nextTurn();
  }

  _endGame() {
    this.phase = "GAME_OVER";
    const scores = this.players.map(p => ({
      playerId: p.playerId,
      playerName: p.playerName,
      score: this._getScore(p),
    })).sort((a, b) => b.score - a.score);
    return { event: "game_over", scores };
  }

  _getScore(p) {
    let score = getTotalMoney(p.money);
    for (const setId of p.completeSets) score += SET_SCORES[setId] || 0;
    return score;
  }

  // ── 行动 A：开拍 ──────────────────────────────────────────
  startAuction() {
    if (this.deck.length === 0) return { error: "牌堆已空" };
    this.auctionCard = this.deck.shift();
    this.bids = {};
    this.passed = {};
    this.highestBid = 0;
    this.highestBidder = -1;
    for (const p of this.players) {
      this.passed[p.playerId] = (p.playerId === this.currentPlayer().playerId);
    }

    const events = [];
    if (this.auctionCard.setId === "silver_ingots") {
      this.silverIngotCount++;
      const bonus = SILVER_INGOT_BONUS[this.silverIngotCount] || 0;
      for (const p of this.players) addMoney(p.money, splitIntoBills(bonus));
      events.push({ event: "silver_bonus", bonus, count: this.silverIngotCount });
    }
    events.push({ event: "auction_started", card: this.auctionCard, deckSize: this.deck.length });
    return events;
  }

  placeBid(playerId, amount) {
    this.bids[playerId] = amount;
    this.passed[playerId] = false;
    return { event: "bid_placed", playerId, amount };
  }

  passBid(playerId) {
    this.passed[playerId] = true;
    return { event: "bid_passed", playerId };
  }

  resolveBids() {
    this.highestBid = 0;
    this.highestBidder = -1;
    for (const pid in this.bids) {
      if (this.passed[pid]) continue;
      const amount = this.bids[pid];
      if (amount > this.highestBid) { this.highestBid = amount; this.highestBidder = parseInt(pid); }
    }
    if (this.highestBidder === -1) {
      this._giveCardTo(this.currentPlayer().playerId, this.auctionCard);
      this.auctionCard = null;
      return [{ event: "no_bids", winnerId: this.currentPlayer().playerId }, this._advanceTurn()].flat();
    }
    this.phase = "SNIPE";
    return { event: "snipe_prompt", card: this.auctionCard, highestBid: this.highestBid, highestBidder: this.highestBidder };
  }

  actionSnipe(doSnipe, paid) {
    const paidTotal = Object.entries(paid).reduce((s, [f, c]) => s + parseInt(f) * c, 0);
    if (doSnipe) {
      if (paidTotal < this.highestBid) return this._failPayment(this.currentPlayer().playerId);
      deductMoneyExact(this.currentPlayer().money, paid);
      addMoney(this.getPlayer(this.highestBidder).money, paid);
      this._giveCardTo(this.currentPlayer().playerId, this.auctionCard);
      this.auctionCard = null;
      return [{ event: "snipe_success", winnerId: this.currentPlayer().playerId }, this._advanceTurn()].flat();
    } else {
      const bidder = this.getPlayer(this.highestBidder);
      if (paidTotal < this.highestBid) return this._failPayment(bidder.playerId);
      deductMoneyExact(bidder.money, paid);
      addMoney(this.currentPlayer().money, paid);
      this._giveCardTo(this.highestBidder, this.auctionCard);
      this.auctionCard = null;
      return [{ event: "snipe_declined", winnerId: this.highestBidder }, this._advanceTurn()].flat();
    }
  }

  _failPayment(playerId) {
    const p = this.getPlayer(playerId);
    const exposed = { ...p.money };
    this.bids = {};
    this.passed = {};
    this.highestBid = 0;
    this.highestBidder = -1;
    for (const pl of this.players) this.passed[pl.playerId] = (pl.playerId === this.currentPlayer().playerId);
    return { event: "payment_failed", playerId, exposedMoney: exposed, card: this.auctionCard };
  }

  _giveCardTo(playerId, card) {
    this.getPlayer(playerId).antiques.push(card);
    this._checkCompleteSet(playerId);
  }

  // ── 行动 B：私盘 ──────────────────────────────────────────
  startPrivateDeal(initiatorId, targetId, setId) {
    this.dealInitiator = initiatorId;
    this.dealTarget = targetId;
    this.dealSetId = setId;
    this.dealTieCount = 0;
    this.phase = "PRIVATE_DEAL";
    return { event: "private_deal_started", initiatorId, targetId, setId };
  }

  submitDealOffer(playerId, paid) {
    if (playerId === this.dealInitiator) {
      this.dealOffer = paid;
      const offerCount = Object.values(paid).reduce((s, c) => s + c, 0);
      return { event: "deal_offer_submitted", targetId: this.dealTarget, offerCount, setId: this.dealSetId };
    } else {
      this.dealCounter = paid;
      return this._resolvePrivateDeal();
    }
  }

  _resolvePrivateDeal() {
    const initiator = this.getPlayer(this.dealInitiator);
    const target = this.getPlayer(this.dealTarget);
    const offerTotal = Object.entries(this.dealOffer).reduce((s, [f, c]) => s + parseInt(f) * c, 0);
    const counterTotal = Object.entries(this.dealCounter).reduce((s, [f, c]) => s + parseInt(f) * c, 0);
    const tradeCount = Math.min(getAntiquesBySet(initiator.antiques, this.dealSetId).length, getAntiquesBySet(target.antiques, this.dealSetId).length);

    if (offerTotal === counterTotal) {
      this.dealTieCount++;
      if (this.dealTieCount >= 2) {
        for (let i = 0; i < tradeCount; i++) {
          const card = getAntiquesBySet(target.antiques, this.dealSetId)[0];
          target.antiques = target.antiques.filter(c => c !== card);
          initiator.antiques.push(card);
        }
        this._checkCompleteSet(initiator.playerId);
        const result = { event: "deal_resolved", tieForcedWinner: initiator.playerId, tradeCount, offerTotal, counterTotal };
        return [result, this._advanceTurn()].flat();
      }
      return { event: "deal_tie", tieCount: this.dealTieCount, initiatorId: this.dealInitiator, targetId: this.dealTarget, setId: this.dealSetId };
    }

    let winnerId, loserId;
    if (offerTotal > counterTotal) {
      for (let i = 0; i < tradeCount; i++) {
        const card = getAntiquesBySet(target.antiques, this.dealSetId)[0];
        target.antiques = target.antiques.filter(c => c !== card);
        initiator.antiques.push(card);
      }
      addMoney(target.money, this.dealOffer);
      deductMoneyExact(initiator.money, this.dealOffer);
      addMoney(initiator.money, this.dealCounter);
      deductMoneyExact(target.money, this.dealCounter);
      winnerId = initiator.playerId; loserId = target.playerId;
    } else {
      for (let i = 0; i < tradeCount; i++) {
        const card = getAntiquesBySet(initiator.antiques, this.dealSetId)[0];
        initiator.antiques = initiator.antiques.filter(c => c !== card);
        target.antiques.push(card);
      }
      addMoney(initiator.money, this.dealCounter);
      deductMoneyExact(target.money, this.dealCounter);
      addMoney(target.money, this.dealOffer);
      deductMoneyExact(initiator.money, this.dealOffer);
      winnerId = target.playerId; loserId = initiator.playerId;
    }
    this._checkCompleteSet(winnerId);
    const result = { event: "deal_resolved", winnerId, loserId, tradeCount, offerTotal, counterTotal, initiatorId: this.dealInitiator };
    return [result, this._advanceTurn()].flat();
  }

  // ── 私盘目标 ──────────────────────────────────────────────
  getPrivateDealTargets(initiatorId) {
    const initiator = this.getPlayer(initiatorId);
    const result = [];
    for (const setId in SET_SCORES) {
      const myCards = getAntiquesBySet(initiator.antiques, setId);
      if (myCards.length === 0) continue;
      for (const p of this.players) {
        if (p.playerId === initiatorId) continue;
        const theirCards = getAntiquesBySet(p.antiques, setId);
        if (theirCards.length > 0) {
          result.push({ setId, targetId: p.playerId, tradeCount: Math.min(myCards.length, theirCards.length) });
        }
      }
    }
    return result;
  }

  _canAnyPrivateDeal() {
    for (const p of this.players) {
      if (this.getPrivateDealTargets(p.playerId).length > 0) return true;
    }
    return false;
  }

  _checkCompleteSet(playerId) {
    const p = this.getPlayer(playerId);
    for (const setId in SET_SCORES) {
      if (p.completeSets.includes(setId)) continue;
      if (getAntiquesBySet(p.antiques, setId).length === 4) p.completeSets.push(setId);
    }
  }

  // ── 给客户端的视图（隐藏其他玩家手牌） ───────────────────
  getViewFor(playerId) {
    return {
      myId: playerId,
      phase: this.phase,
      currentPlayerId: this.currentPlayer().playerId,
      deckSize: this.deck.length,
      silverIngotCount: this.silverIngotCount,
      me: this._fullPlayerView(this.getPlayer(playerId)),
      opponents: this.players.filter(p => p.playerId !== playerId).map(p => this._opponentView(p)),
      auctionCard: this.auctionCard,
      highestBid: this.highestBid,
      highestBidder: this.highestBidder,
      dealInitiator: this.dealInitiator,
      dealTarget: this.dealTarget,
      dealSetId: this.dealSetId,
    };
  }

  _fullPlayerView(p) {
    return { playerId: p.playerId, playerName: p.playerName, money: p.money, antiques: p.antiques, completeSets: p.completeSets };
  }

  _opponentView(p) {
    return { playerId: p.playerId, playerName: p.playerName, handCount: Object.values(p.money).reduce((s, c) => s + c, 0), antiques: p.antiques, completeSets: p.completeSets };
  }
}

module.exports = { GameState };
