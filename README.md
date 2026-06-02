# 古董拍卖 (Antique Auction)

一个 2–4 人的多人在线拍卖博弈游戏的服务器 + iOS 客户端。

## 玩法简介

玩家轮流当「拍卖人」翻开古董牌，其余人按顺位竞价；最高价产生后，拍卖人可选择「截拍」（自己付钱抢下）或「放手」（让出价者付钱拿走）。也可发起「私盘」与他人就某套古董暗标交易，价高者拿走整套。起始资金含面值 0 的「废钞」，且对手只能看到你手里钞票的**张数**、看不到面值——可用于虚张声势。最终按「现金 + 集齐套牌(每套4张)的分值」排名。

## 技术栈

- **后端**：Node.js + `ws`（WebSocket），纯内存状态
- **iOS 客户端**：SwiftUI + 系统内置 `URLSessionWebSocketTask`（见 `ios/` 目录）

## 仓库结构

- `server.js` — WebSocket 服务器与消息路由（HTTP `/` 返回 ok 作健康检查，绑定 `0.0.0.0:$PORT`）
- `game_logic.js` — 纯游戏逻辑 `GameState` 类 + 卡牌数据（零 I/O）
- `test/game_logic.test.js` — 游戏逻辑单元测试（Node 内置 `node:test`）
- `ios/` — iOS SwiftUI 客户端源码（在 Xcode 中打开，详见 `ios/README.md`）
- `PROTOCOL.md` — WebSocket 通信协议契约（前后端共同依据）

## 本地运行后端

```bash
npm install
npm start        # 监听 ws://localhost:3000（PORT 可由环境变量覆盖）
```

## 运行测试

```bash
node --test      # game_logic 无外部依赖，无需先安装
```

## 部署（Railway）

本服务是**有状态、内存、单实例**的 WebSocket 服务，部署要点：

1. **副本固定 1 个** — 状态在内存，不能横向扩容
2. **常驻不休眠** — 休眠 = 进程被杀 = 进行中房间全部丢失
3. **HTTPS/WSS** — Railway 自动为 `*.up.railway.app` 域名提供 HTTPS/WSS，iOS 端用 `wss://<你的应用>.up.railway.app` 连接（不带端口）

仓库已就绪（`package.json` 有 `start` 脚本，`ws` 为唯一依赖，已读 `process.env.PORT`），几乎零改动即可部署。

## iOS 客户端 / 分发

详见 `ios/README.md`。给好友测试建议用 TestFlight（需 Apple Developer Program $99/年）。
