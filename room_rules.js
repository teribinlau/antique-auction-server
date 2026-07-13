"use strict";

function validateStartGame(room, playerId) {
  if (!room) return "房间不存在";
  if (room.game) return "游戏已经开始";
  if (!room.players.some((p) => p.playerId === playerId)) return "你不在这个房间中";
  if (playerId !== 0) return "只有房主可以开始游戏";
  if (room.players.length < 2) return "至少需要2名玩家";
  return null;
}

module.exports = { validateStartGame };
