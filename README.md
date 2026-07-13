# 古董拍卖 (Antique Auction)

一个 2–5 人的多人在线拍卖博弈游戏，包含 WebSocket 服务器、H5 网页版与 iOS 客户端。

## 玩法简介

玩家轮流当「拍卖人」翻开古董牌，其余人按顺位竞价；最高价产生后，拍卖人可选择「截拍」（自己付钱抢下）或「放手」（让出价者付钱拿走）。也可发起「私盘」与他人就某套古董暗标交易，价高者拿走相应数量的牌。起始资金含面值 0 的「废钞」，且对手只能看到你手里钞票的**张数**、看不到面值——可用于虚张声势。最终得分为「完整套牌分值之和 × 完整套牌数量」，现金不计分。

## 技术栈

- **后端**：Node.js + `ws`（WebSocket），纯内存状态
- **Web 客户端**：React + TypeScript + Vite（见 `web/` 目录）
- **iOS 客户端**：SwiftUI + 系统内置 `URLSessionWebSocketTask`（见 `ios/` 目录）

## 服务端权威校验

- 只有等待室的 0 号房主可以开始游戏，且进行中的游戏不能被重复初始化。
- 所有出价与钞票组合都由服务端校验：只接受固定面值、非负整数张数，并且不能超过玩家真实持有量。
- 私盘必须由当前行动玩家在可行动阶段发起，且双方都必须真实持有目标套系。
- 被篡改的客户端会收到 `error` 事件，服务端状态和资金不会发生变化。

## 仓库结构

- `server.js` — WebSocket 服务器与消息路由（HTTP `/` 返回 ok 作健康检查，绑定 `0.0.0.0:$PORT`）
- `game_logic.js` — 纯游戏逻辑 `GameState` 类 + 卡牌数据（零 I/O）
- `test/game_logic.test.js` — 游戏逻辑单元测试（Node 内置 `node:test`）
- `ios/` — iOS SwiftUI 客户端源码（在 Xcode 中打开，详见 `ios/README.md`）
- `PROTOCOL.md` — WebSocket 通信协议契约（前后端共同依据）
- `docs/deploy-guide.md` — 从零跑通与上线的图文指引（Xcode 跑通 + Railway/Render 部署，端到端）
- `render.yaml` — Render 一键部署蓝图（Railway 的免费替代）

## 本地运行后端

```bash
npm install
npm start        # 监听 ws://localhost:3000（PORT 可由环境变量覆盖）
```

## 运行测试

```bash
node --test      # game_logic 无外部依赖，无需先安装
```

## 部署（Railway / Render）

> 📖 手把手图文版（含 Xcode 跑通 + 端到端联调）见 [`docs/deploy-guide.md`](docs/deploy-guide.md)。下面是要点速览。
>
> 仓库已带 `render.yaml`，可在 [Render](https://render.com) 走 **New → Blueprint** 一键部署到免费档（Railway 的免费替代；免费档闲置会休眠，约局再玩够用）。

本服务是**有状态、内存、单实例**的 WebSocket 服务，部署要点：

1. **副本固定 1 个** — 状态在内存，不能横向扩容
2. **常驻不休眠** — 休眠 = 进程被杀 = 进行中房间全部丢失
3. **HTTPS/WSS** — Railway 自动为 `*.up.railway.app` 域名提供 HTTPS/WSS，iOS 端用 `wss://<你的应用>.up.railway.app` 连接（不带端口）

仓库已就绪（`package.json` 有 `start` 脚本，`ws` 为唯一依赖，已读 `process.env.PORT`），几乎零改动即可部署。

## iOS 客户端 / 分发

详见 `ios/README.md`。给好友测试建议用 TestFlight（需 Apple Developer Program $99/年）。
