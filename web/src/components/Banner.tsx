// 顶部事件横幅：4 秒自动消失（client.ts 里控制），最多叠 3 条。

import type { BannerMsg } from "../client";

export function BannerStack({ banners }: { banners: BannerMsg[] }) {
  if (banners.length === 0) return null;
  return (
    <div className="banners">
      {banners.map((b) => (
        <div key={b.id} className={`banner banner-${b.kind}`}>{b.text}</div>
      ))}
    </div>
  );
}
