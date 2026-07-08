# H5 网页版 ·「古董拍卖」(微信发链接即玩)

`web/` 是一份 React + Vite 的移动端网页客户端,和 iOS 客户端连同一个服务器、走同一份
[`PROTOCOL.md`](../PROTOCOL.md)。**由 `server.js` 同域静态托管**——部署好后,
游戏地址就是服务器地址本身:

```
https://antique-auction-server.onrender.com/
```

把这个链接发到微信(群聊/私聊),对方点开就能玩,**不需要小程序审核、不需要版号、不需要装 App**。
iPhone / Android / 电脑浏览器通吃。

## 部署(其实就是合并到 main)

Render 配置(`render.yaml`)已改为部署时自动构建网页:`npm install && npm run build:web`。
所以只需把代码进 `main` 分支:

1. GitHub Desktop:Current Branch 切到 **main** → 菜单 Branch → **Merge into Current Branch…** → 选 `claude/gallant-newton-zpuqD` → Merge;
2. 点 **Push origin**;
3. Render 检测到 main 更新会自动重新部署(几分钟),完成后打开上面的链接即可。

> 版本确认:访问 `/version` 能看到当前部署的 commit。

## 卡牌插画上网页

网页默认走「渐变+套系字」兜底,不影响玩。想让网页也显示 AI 插画:

```bash
cd ios/tools/card-art
python3 make_web_art.py     # card_art_out/*.png → web/public/cards/*.webp(压缩到约 100KB/张)
```

然后用 GitHub Desktop 提交 `web/public/cards/` 推送、合并 main。页面按 `/cards/<cardId>.webp` 引用。

## 本地开发

```bash
npm start                   # 起服务器 :3000
cd web && npm install && npm run dev   # vite 开发服 :5173(自动连 :3000)
# 或者构建后由 server.js 托管:
npm run build:web && npm start         # 打开 http://localhost:3000
```

## 两套对局界面

连接页可选(游戏中也能随时切换,按 `🀄 牌桌版` / `📱 竖屏版`):

- **经典竖屏版**(默认):信息完整的列表式界面。
- **牌桌横屏版**:斗地主式牌桌——竖持手机自动旋转 90°;对手围坐上沿;底部两手扇形牌:
  上排**古董手牌**(点开大图)、下排**资金手牌**(每张钞票一张牌);
  截拍付款 / 私盘押注 = **点钞票牌弹起选中**,凑够按确认。

## 微信里的注意事项

- **免费档冷启动**:Render 免费档闲置 15 分钟休眠,第一个打开的人要等约 1 分钟。开局前群主先点一下链接把它叫醒。
- **断线重连**:切出微信/锁屏会断 WebSocket;页面回到前台(甚至被微信杀掉后重新打开链接)都会凭本地令牌自动连回原座位。游戏中座位始终保留;**就算全员同时掉线,房间也会保留 10 分钟**等人回来,超时才回收。
- **换设备/清缓存也能回局**:对局顶栏常驻**房号**(点击复制)。令牌丢了的玩家在大厅「输码加入」里填**房号 + 原来的昵称**,即可绑回自己的座位继续玩。
- **分享卡片**:微信里转发链接显示的标题来自页面 `<title>`(古董拍卖)。要自定义缩略图/描述需接微信 JS-SDK(要公众号),暂未做。
- 若以后要上**微信小程序**(非 H5),另有域名备案 + 主体资质等硬门槛,见团队讨论记录。

## 技术要点

- 无 UI 框架依赖,整站 gzip ≈ 55KB;暗色古董金主题与 iOS 端一致。
- 状态中枢 `web/src/client.ts` 对应 iOS 的 `GameClient`,五个协议易错点(create_room 不入座、
  handCount 语义、deal_resolved 双形态、request_state 仅游戏中、字符串面值 key)全部照搬。
- 断线重连:localStorage 按房号存 `reconnectToken`,断开后指数退避 `rejoin_room`;
  `game_over` / 离开房间清令牌。
- `server.js` 的静态托管无新增依赖;无 `web/dist` 时退回纯后端行为(`/` 返回 JSON,健康检查不受影响)。
