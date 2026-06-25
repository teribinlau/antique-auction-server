#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批量生成「古董拍卖」卡牌插画（One Piece TCG 风格），输出 5:7 / 1500x2100 的 PNG。

支持官方 OpenAI 与「中转站」(自定义 base URL)，并兼容 gpt-image-1 / dall-e-3 / dall-e-2。

用法（官方 OpenAI）：
    export OPENAI_API_KEY=sk-...
    pip install openai pillow
    python3 generate_card_art.py

用法（中转站 / 自建网关）：
    export OPENAI_API_KEY=中转站给的key
    export OPENAI_BASE_URL=https://你的中转站域名/v1     # 关键：接口地址
    python3 generate_card_art.py                         # 默认 gpt-image-1
    python3 generate_card_art.py --model dall-e-3        # 中转站只有 dall-e-3 时

常用参数：
    --only seals_02        只生成 / 重生成某一张
    --quality medium       省钱档（gpt-image-1: low/medium/high；dall-e-3: high→hd 其余 standard）
    --force                覆盖已存在的图
    --base-url <url>       覆盖 OPENAI_BASE_URL
    --size 1024x1536       覆盖默认尺寸（一般不用，脚本会按模型自动选）

完成后把图装进图集：
    ../install-card-art.sh ./card_art_out
"""
import argparse
import base64
import io
import json
import os
import sys
import time
import urllib.request
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
TARGET_RATIO = 5 / 7

# 各模型的默认纵向尺寸（脚本随后会本地裁切到 5:7，所以这里只要是竖图即可）
DEFAULT_SIZE = {
    "gpt-image-1": "1024x1536",
    "dall-e-3": "1024x1792",
    "dall-e-2": "1024x1024",
}


def crop_to_5x7(img: "Image.Image") -> "Image.Image":
    """居中裁切到 5:7，再高质量放大到 1500x2100。任意输入尺寸都可。"""
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


def _extract_bytes(resp) -> bytes:
    """从 images.generate 返回里取出图片字节，兼容 b64_json 与 url 两种形态。"""
    d = resp.data[0]
    b64 = getattr(d, "b64_json", None)
    if b64:
        return base64.b64decode(b64)
    url = getattr(d, "url", None)
    if url:
        with urllib.request.urlopen(url) as r:   # noqa: S310
            return r.read()
    raise RuntimeError("返回里既没有 b64_json 也没有 url")


def gen_one(client, prompt, model, size, quality) -> bytes:
    base = dict(model=model, prompt=prompt, n=1)
    opt = {}                                          # 可选参数（中转站不认就逐个去掉）
    if size:
        opt["size"] = size
    if model.startswith("dall-e"):
        opt["response_format"] = "b64_json"           # 让中转站尽量直接回 base64
        if model == "dall-e-3":
            opt["quality"] = "hd" if quality == "high" else "standard"
    else:                                             # gpt-image-1 / gpt-image-2 等兼容
        opt["quality"] = quality

    last = None
    for attempt in range(6):
        try:
            return _extract_bytes(client.images.generate(**base, **opt))
        except Exception as e:  # noqa: BLE001
            msg = str(e).lower()
            # 中转站的这个模型不支持某个参数 → 去掉它，立刻重试（不计退避）
            bad = any(w in msg for w in ("unsupport", "invalid", "not allowed",
                                          "unknown", "extra", "unexpected", "param"))
            if bad:
                dropped = next((p for p in ("quality", "response_format", "size")
                                if p in opt and p in msg), None)
                if dropped:
                    opt.pop(dropped, None)
                    print(f"      · 模型不支持参数 {dropped}，去掉后重试", flush=True)
                    continue
            last = e
            wait = 2 ** attempt
            print(f"      ! {e}  (第 {attempt + 1}/6 次，{wait}s 后重试)", flush=True)
            time.sleep(wait)
    raise RuntimeError(f"重试多次仍失败：{last}")


def main() -> None:
    ap = argparse.ArgumentParser(description="批量生成古董卡牌插画")
    ap.add_argument("--out", default=str(HERE / "card_art_out"), help="输出文件夹")
    ap.add_argument("--quality", default="high", choices=["low", "medium", "high"])
    ap.add_argument("--model", default="gpt-image-1")
    ap.add_argument("--base-url", default=None, help="中转站接口地址(覆盖 OPENAI_BASE_URL)")
    ap.add_argument("--size", default=None, help="覆盖默认尺寸，如 1024x1536")
    ap.add_argument("--only", default=None, help="只生成某个 cardId")
    ap.add_argument("--force", action="store_true", help="覆盖已存在的图")
    args = ap.parse_args()

    if not os.environ.get("OPENAI_API_KEY"):
        sys.exit("请先设置：export OPENAI_API_KEY=...")
    if not PROMPTS_FILE.exists():
        sys.exit(f"找不到提示词文件：{PROMPTS_FILE}")

    base_url = args.base_url or os.environ.get("OPENAI_BASE_URL")
    size = args.size or DEFAULT_SIZE.get(args.model, "1024x1536")

    cards = json.loads(PROMPTS_FILE.read_text(encoding="utf-8"))
    if args.only:
        cards = [c for c in cards if c["cardId"] == args.only]
        if not cards:
            sys.exit(f"找不到 cardId={args.only}")

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    client = OpenAI(base_url=base_url) if base_url else OpenAI()

    total, done, skipped, failed = len(cards), 0, 0, []
    print(f"共 {total} 张  →  {out}")
    print(f"模型={args.model}  尺寸={size}  quality={args.quality}  "
          f"接口={'中转站 ' + base_url if base_url else '官方 OpenAI'}\n")
    for i, c in enumerate(cards, 1):
        cid = c["cardId"]
        dst = out / f"{cid}.png"
        if dst.exists() and not args.force:
            print(f"[{i}/{total}] {cid}  已存在，跳过")
            skipped += 1
            continue
        print(f"[{i}/{total}] {cid}  生成中…", flush=True)
        try:
            raw = gen_one(client, c["prompt"], args.model, size, args.quality)
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
