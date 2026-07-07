// 顶层路由(对应 iOS AppRootView):connection → roomCode → phase 三级决定显示哪屏。

import { useSyncExternalStore } from "react";
import { client } from "./client";
import { BannerStack } from "./components/Banner";
import { ConnectView } from "./views/ConnectView";
import { LobbyView } from "./views/LobbyView";
import { WaitingView } from "./views/WaitingView";
import { GameView } from "./views/GameView";

export default function App() {
  const snap = useSyncExternalStore(client.subscribe, client.getSnapshot);

  let view: JSX.Element;
  if (snap.roomCode !== null && snap.state !== null && snap.state.phase !== "WAITING") {
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
