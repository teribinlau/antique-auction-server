// 顶层路由(对应 iOS AppRootView):connection → roomCode → phase 三级决定显示哪屏。

import { useSyncExternalStore } from "react";
import { client } from "./client";
import { BannerStack } from "./components/Banner";
import { ConnectView } from "./views/ConnectView";
import { LobbyView } from "./views/LobbyView";
import { WaitingView } from "./views/WaitingView";
import { GameView } from "./views/GameView";
import { TableGameView } from "./views/table/TableGameView";

export default function App() {
  const snap = useSyncExternalStore(client.subscribe, client.getSnapshot);

  const inGame = snap.roomCode !== null && snap.state !== null && snap.state.phase !== "WAITING";

  // 牌桌版自带旋转与横幅,独立渲染
  if (inGame && snap.uiMode === "table") {
    return <TableGameView snap={snap} />;
  }

  let view: JSX.Element;
  if (inGame) {
    view = <GameView snap={snap} />;
  } else if (snap.roomCode !== null) {
    view = <WaitingView snap={snap} />;
  } else if (snap.conn === "connected") {
    view = <LobbyView snap={snap} />;
  } else {
    view = <ConnectView snap={snap} />;
  }

  return (
    <>
      {view}
      <BannerStack banners={snap.banners} />
    </>
  );
}
