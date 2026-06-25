#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批量生成「古董拍卖」卡牌插画（One Piece TCG 风格），输出 5:7 / 1500x2100 的 PNG。

用法：
    export OPENAI_API_KEY=sk-...
    pip install openai pillow
    python3 generate_card_art.py                 # 生成全部 41 张到 ./card_art_out
    python3 generate_card_art.py --only seals_02  # 只生成 / 重生成某一张
    python3 generate_card_art.py --quality medium # 省钱档（默认 high）
    python3 generate_card_art.py --force          # 覆盖已生成的图

完成后把图装进图集：
    ../install-card-art.sh ./card_art_out

说明：
- gpt-image-1 只能出固定尺寸，这里用 1024x1536 生成，再本地居中裁切 + 放大成 5:7 / 1500x2100。
- 已生成的 PNG 默认跳过，可随时中断后重跑续生成。
- 失败自动重试 4 次（指数退避）。
"""
import argparse
import base64
import io
import json
import os
import sys
import time
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    sys.exit("缺少依赖，请先运行：pip install openai pillow")
try:
    from PIL import Image
except ImportError:
    sys.exit("缺少依赖，请先运行：pip install openai pillow")

HERE = Path(__file__).resolve().parent
PROMPTS_FILE = HERE / "card_art_prompts.json"
TARGET_W, TARGET_H = 1500, 2100          # 5:7（仓库 README 规定的画布）
GEN_SIZE = "1024x1536"                    # gpt-image-1 的纵向尺寸
TARGET_RATIO = 5 / 7


def crop_to_5x7(img: "Image.Image") -> "Image.Image":
    """居中裁切到 5:7，再高质量放大到 1500x2100。"""
    img = img.convert("RGB")
    w, h = img.size
    if w / h > TARGET_RATIO:              # 太宽 → 裁左右
        nw = int(round(h * TARGET_RATIO))
        x = (w - nw) // 2
        img = img.crop((x, 0, x + nw, h))
    else:                                 # 太高 → 裁上下
        nh = int(round(w / TARGET_RATIO))
        y = (h - nh) // 2
        img = img.crop((0, y, w, y + nh))
    return img.resize((TARGET_W, TARGET_H), Image.LANCZOS)


def gen_one(client: "OpenAI", prompt: str, quality: str, model: str) -> bytes:
    last = None
    for attempt in range(4):
        try:
            r = client.images.generate(
                model=model, prompt=prompt, size=GEN_SIZE, quality=quality, n=1
            )
            return base64.b64decode(r.data[0].b64_json)
        except Exception as e:  # noqa: BLE001
            last = e
            wait = 2 ** attempt
            print(f"      ! {e}  (第 {attempt + 1}/4 次，{wait}s 后重试)", flush=True)
            time.sleep(wait)
    raise RuntimeError(f"重试 4 次仍失败：{last}")


def main() -> None:
    ap = argparse.ArgumentParser(description="批量生成古董卡牌插画")
    ap.add_argument("--out", default=str(HERE / "card_art_out"), help="输出文件夹")
    ap.add_argument("--quality", default="high", choices=["low", "medium", "high"])
    ap.add_argument("--model", default="gpt-image-1")
    ap.add_argument("--only", default=None, help="只生成某个 cardId")
    ap.add_argument("--force", action="store_true", help="覆盖已存在的图")
    args = ap.parse_args()

    if not os.environ.get("OPENAI_API_KEY"):
        sys.exit("请先设置：export OPENAI_API_KEY=sk-...")
    if not PROMPTS_FILE.exists():
        sys.exit(f"找不到提示词文件：{PROMPTS_FILE}")

    cards = json.loads(PROMPTS_FILE.read_text(encoding="utf-8"))
    if args.only:
        cards = [c for c in cards if c["cardId"] == args.only]
        if not cards:
            sys.exit(f"找不到 cardId={args.only}")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    client = OpenAI()

    total, done, skipped, failed = len(cards), 0, 0, []
    print(f"共 {total} 张  →  {out}   (quality={args.quality}, model={args.model})\n")
    for i, c in enumerate(cards, 1):
        cid = c["cardId"]
        dst = out / f"{cid}.png"
        if dst.exists() and not args.force:
            print(f"[{i}/{total}] {cid}  已存在，跳过")
            skipped += 1
            continue
        print(f"[{i}/{total}] {cid}  生成中…", flush=True)
        try:
            raw = gen_one(client, c["prompt"], args.quality, args.model)
            crop_to_5x7(Image.open(io.BytesIO(raw))).save(dst, "PNG")
            done += 1
            print(f"        ✓ {dst}")
        except Exception as e:  # noqa: BLE001
            failed.append(cid)
            print(f"        ✗ 失败：{cid} — {e}")

    print(f"\n完成：新生成 {done}，跳过 {skipped}，失败 {len(failed)}。")
    if failed:
        print("失败的 cardId：" + ", ".join(failed) + "（可重跑本脚本续生成）")
    print("\n下一步，把图装进 CardArt.xcassets：")
    print(f"  {HERE.parent / 'install-card-art.sh'} {out}")


if __name__ == "__main__":
    main()
