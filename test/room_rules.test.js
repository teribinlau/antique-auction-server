"use strict";

const { test } = require("node:test");
const assert = require("node:assert");
const { validateStartGame } = require("../room_rules");

function room(playerCount = 2) {
  return {
    game: null,
    players: Array.from({ length: playerCount }, (_, playerId) => ({ playerId })),
  };
}

test("只有 0 号房主可开局", () => {
  assert.strictEqual(validateStartGame(room(2), 0), null);
  assert.match(validateStartGame(room(2), 1), /房主/);
});

test("不足两人或游戏已开始时不能再次开局", () => {
  assert.match(validateStartGame(room(1), 0), /至少需要2名玩家/);
  const active = room(2);
  active.game = {};
  assert.match(validateStartGame(active, 0), /已经开始/);
});

test("非房间成员不能开局", () => {
  assert.match(validateStartGame(room(2), 99), /不在这个房间/);
});
