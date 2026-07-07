#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把已生成的卡牌插画压缩成 H5 网页版用的小图。

    python3 make_web_art.py                # card_art_out/*.png → ../../../web/public/cards/*.webp

- 尺寸 750×1050(够 2x 屏),WebP q82,单张约 60~150KB(原 PNG 约 2~3MB)。
- 输出进仓库后随代码一起部署,页面路径 /cards/<cardId>.webp。
- 没跑本脚本也不影响网页——CardView 缺图自动回退渐变。
"""
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("缺少依赖:pip install pillow")

HERE = Path(__file__).resolve().parent
SRC = HERE / "card_art_out"
DST = HERE.parent.parent.parent / "web" / "public" / "cards"
W, H = 750, 1050

def main() -> None:
    if not SRC.is_dir():
        sys.exit(f"找不到源目录 {SRC}(先跑 generate_card_art.py 生成卡图)")
    DST.mkdir(parents=True, exist_ok=True)
    pngs = sorted(SRC.glob("*.png"))
    if not pngs:
        sys.exit(f"{SRC} 里没有 PNG")
    total = 0
    for p in pngs:
        out = DST / f"{p.stem}.webp"
        img = Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS)
        img.save(out, "WEBP", quality=82, method=6)
        kb = out.stat().st_size // 1024
        total += kb
        print(f"  {p.stem}.webp  {kb}KB")
    print(f"\n完成:{len(pngs)} 张 → {DST}(共 {total // 1024}MB)")
    print("下一步:用 GitHub Desktop 提交 web/public/cards/ 并推送,合并到 main 后 Render 自动带上。")

if __name__ == "__main__":
    main()
