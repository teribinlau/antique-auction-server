# WebSocket 通信协议

所有消息为 JSON 字符串。客户端发送的消息带 `action` 字段，服务端推送的消息带 `event` 字段。本文档是前后端的单一事实源。

## 客户端 → 服务端（action）

| action | 字段 | 说明 |
|---|---|---|
| list_rooms | — | 返回 room_list |
| create_room | roomName?, playerName?, password? | **不会自动入座**，返回 room_created 后需再发 join_room |
| join_room | roomCode, playerName?, password? | 返回 joined_room（含你的 playerId 与 reconnectToken）。**游戏进行中**：若存在「已掉线且昵称相同」的座位，则绑回该座位并返回 rejoined_room（发新令牌，旧令牌作废）——令牌丢失（换设备/清缓存）时凭房号+原昵称回局的兜底通道；否则返回 error「游戏已开始」 |
| rejoin_room | roomCode, reconnectToken | 断线重连：用令牌把新连接绑回原座位（替代 join_room）。成功返回 rejoined_room，随后自动补发 state_update（及未结束时的 turn_changed）；令牌无效则返回 error |
| request_state | — | 仅游戏进行中有响应 |
| start_game | — | ≥2 人可开始 |
| start_auction | — | 仅当前回合玩家 |
| place_bid | amount(Int) | 仅 AUCTION、非拍卖人、轮到你时 |
| pass_bid | — | 同上 |
| action_snipe | doSnipe(Bool), paid?({面值:张数}) | 仅 SNIPE 且你是拍卖人；doSnipe=true 时 paid 总额须≥highestBid |
| start_private_deal | targetId(Int), setId(String) | 仅当前回合玩家 |
| submit_deal_offer | paid({面值:张数}) | 发起人与目标各提交一次 |
| get_deal_targets | — | 返回 deal_targets |

## 服务端 → 客户端（event）

| event | 字段 |
|---|---|
| room_list | rooms:[{roomCode,roomName,playerCount,hasPassword}] |
| room_created | roomCode, roomName |
| joined_room | roomCode, roomName, playerId, playerCount, players:[String], reconnectToken（断线重连令牌，客户端持久化后用于 rejoin_room） |
| rejoined_room | roomCode, roomName, playerId, playerCount, players:[String], reconnectToken（重连成功，语义同 joined_room=恢复座位；其后服务端自动补发 state_update 与未结束时的 turn_changed） |
| player_joined | playerName, playerCount |
| player_left | playerName |
| player_disconnected | playerName, playerId（某玩家游戏中掉线，座位保留以便凭令牌重连） |
| player_reconnected | playerName, playerId（某玩家凭令牌重连回座位） |
| error | message |
| game_started | playerCount |
| state_update | state（见下方 state 结构） |
| turn_changed | playerId, deckSize?(可选) |
| auction_started | card, deckSize, auctionerId |
| silver_bonus | bonus(Int), count(Int) |
| bid_turn | playerId, auctionerId, highestBid |
| bid_placed | playerId, amount |
| bid_passed | playerId |
| no_bids | winnerId（=拍卖人，无人出价则其自得该牌） |
| snipe_prompt | card, highestBid, highestBidder, auctionerId |
| snipe_success | winnerId（拍卖人截拍成功） |
| snipe_declined | winnerId（=出价者，拍卖人放手） |
| payment_failed | playerId, exposedMoney({String:Int}), card, currentPlayerId（付款失败=该牌流拍，随后会有 turn_changed） |
| private_deal_started | initiatorId, targetId, setId |
| deal_offer_submitted | targetId, initiatorId, offerCount, setId |
| deal_tie | tieCount, initiatorId, targetId, setId |
| deal_resolved | 普通：{winnerId,loserId,tradeCount,offerTotal,counterTotal,initiatorId}；连平掷币：{tieForcedWinner,loserId,setId,tradeCount,offerTotal,counterTotal,initiatorId} |
| deal_targets | targets:[{setId,targetId,tradeCount}] |
| game_over | scores:[{playerId,playerName,score}]（已按分降序） |

## state 结构（state_update.state）

```json
{
  "myId": 0,
  "phase": "WAITING|AUCTION|SNIPE|PRIVATE_DEAL|GAME_OVER",
  "currentPlayerId": 0,
  "deckSize": 24,
  "silverIngotCount": 0,
  "me": {
    "playerId": 0,
    "playerName": "Alice",
    "money": {
      "0": 0,
      "10": 2,
      "50": 1,
      "100": 1,
      "200": 0,
      "500": 0
    },
    "antiques": [
      {
        "cardId": "card_001",
        "cardName": "明清瓷碗",
        "flavorText": "一个蓝色的瓷碗",
        "setId": "dinnerware_01",
        "setName": "明清餐具",
        "setScore": 100
      }
    ],
    "completeSets": ["dinnerware_01"]
  },
  "opponents": [
    {
      "playerId": 1,
      "playerName": "Bob",
      "handCount": 5,
      "antiques": [
        {
          "cardId": "card_002",
          "cardName": "民国茶杯",
          "flavorText": "一个白色的茶杯",
          "setId": "dinnerware_01",
          "setName": "明清餐具",
          "setScore": 100
        }
      ],
      "completeSets": []
    }
  ],
  "auctionCard": {
    "cardId": "card_003",
    "cardName": "清代瓷盘",
    "flavorText": "一个红色的瓷盘",
    "setId": "dinnerware_01",
    "setName": "明清餐具",
    "setScore": 100
  },
  "highestBid": 150,
  "highestBidder": 1,
  "dealInitiator": -1,
  "dealTarget": -1,
  "dealSetId": ""
}
```

## 注意事项

1. **money/exposedMoney 的 key 是字符串面值**，固定集合 `["0","10","50","100","200","500"]`，`"0"` 为废钞
2. **playerId 是入座顺序下标** 0..4（房间上限 5 人，`server.js` 的 `MAX_PLAYERS`）
3. **「轮到谁出价」不在 state 里**，只能靠 `bid_turn` 事件维护
4. **断线重连**：服务器每 30s 发 WebSocket 协议级 PING（客户端由系统自动回 PONG，无需额外代码）。入座 / 重连成功时下发 `reconnectToken`，客户端应持久化（按 roomCode）；游戏进行中掉线服务端**保留座位**（广播 `player_disconnected`），凭 `rejoin_room{roomCode,reconnectToken}` 可绑回原座位（广播 `player_reconnected`）。离开房间或 `game_over` 后客户端应清除已存令牌
