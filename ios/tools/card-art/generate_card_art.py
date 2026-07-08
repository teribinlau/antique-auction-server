#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批量生成「古董拍卖」卡牌插画（One Piece TCG 风格），输出 5:7 / 1500x2100 的 PNG。

直接用 HTTP 调 OpenAI 兼容的 /images/generations，并用「万能解析」兼容官方与各种中转站的返回
（data[].b64_json / data[].url / data 为 url 字符串数组 / chat 风格 content 里的 markdown 图
/ data:image;base64 等都能抠出来）。只依赖 Pillow。

用法（中转站）：
    export OPENAI_API_KEY=中转站给的key
    export OPENAI_BASE_URL=https://你的中转站域名/v1
    python3 generate_card_art.py --only lost_paintings_01 --model gpt-image-2-vip
    python3 generate_card_art.py --model gpt-image-2-vip            # 全部 41 张

排错：加 --debug 会把每次返回的前 800 字打印出来。
完成后装图：  ../install-card-art.sh ./card_art_out
"""
import argparse
import base64
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

try:
    from PIL import Image
except ImportError:
    sys.exit("缺少依赖，请先运行：pip install pillow")

HERE = Path(__file__).resolve().parent
PROMPTS_FILE = HERE / "card_art_prompts.json"
TARGET_W, TARGET_H = 1500, 2100
TARGET_RATIO = 5 / 7
DEFAULT_SIZE = {"gpt-image-1": "1024x1536", "dall-e-3": "1024x1792", "dall-e-2": "1024x1024"}


def crop_to_5x7(img: "Image.Image") -> "Image.Image":
    img = img.convert("RGB")
    w, h = img.size
    if w / h > TARGET_RATIO:
        nw = int(round(h * TARGET_RATIO)); x = (w - nw) // 2
        img = img.crop((x, 0, x + nw, h))
    else:
        nh = int(round(w / TARGET_RATIO)); y = (h - nh) // 2
        img = img.crop((0, y, w, y + nh))
    return img.resize((TARGET_W, TARGET_H), Image.LANCZOS)


def crop_landscape(img: "Image.Image", tw: int = 1920, th: int = 900) -> "Image.Image":
    """居中裁切成横版(牌桌背景用)并缩放到 tw×th。"""
    img = img.convert("RGB")
    w, h = img.size
    ratio = tw / th
    if w / h > ratio:
        nw = int(round(h * ratio)); x = (w - nw) // 2
        img = img.crop((x, 0, x + nw, h))
    else:
        nh = int(round(w / ratio)); y = (h - nh) // 2
        img = img.crop((0, y, w, y + nh))
    return img.resize((tw, th), Image.LANCZOS)


TABLE_BG_PROMPT = (
    "A luxurious background texture for an online antique-auction card game table, viewed straight "
    "from above. Rich dark mahogany and rosewood wood grain surface, a large subtle oval inlay of "
    "thin antique-gold filigree around the middle, delicate traditional Chinese cloud-pattern "
    "engravings near the outer edges, warm candlelight glow at the center fading into a deep dark "
    "vignette at the edges. Muted, elegant, atmospheric, low-key. IMPORTANT: the central area must "
    "stay clean, dark and low-contrast — game cards and buttons will be overlaid on top. Empty "
    "table only: no objects, no cards, no hands, no text, no letters, no watermark. Wide landscape "
    "16:9 composition, full-bleed, fully opaque."
)


def crop_square(img: "Image.Image", side: int = 1024) -> "Image.Image":
    """居中裁成正方形并缩放到 side×side（App 图标用，不透明）。"""
    img = img.convert("RGB")
    w, h = img.size
    m = min(w, h)
    x = (w - m) // 2
    y = (h - m) // 2
    return img.crop((x, y, x + m, y + m)).resize((side, side), Image.LANCZOS)


ICON_PROMPT = (
    "A premium 3D app icon in soft glassmorphism style: a small fan of three or four translucent "
    "frosted-glass cards floating at a gentle angle, made of smooth matte frosted glass with a soft "
    "gradient from lavender purple to sky blue, subtle translucency and light refraction, gentle "
    "soft drop shadows and delicate highlights. On the front card a single elegant emblem is gently "
    "embossed into the glass — a classical antique vase / Chinese treasure silhouette. Clean minimal "
    "background of very light lavender fading to off-white with a soft glow. Modern Apple-style 3D "
    "icon aesthetic, soft studio lighting, smoothly rounded card corners, high detail. Square 1:1 "
    "composition, the card fan centered and filling most of the frame, fully opaque background. Do "
    "NOT add any text, letters, numbers, words or watermark. Do NOT add an outer rounded-corner "
    "frame or a phone."
)


def _scan_str(s: str):
    """从一段文本里找出图片来源：data-uri base64 / 图片直链 / 任意 http 链接。"""
    out = []
    for m in re.finditer(r"data:image/[A-Za-z0-9.+-]+;base64,([A-Za-z0-9+/=\s]+)", s):
        out.append(("b64", m.group(1)))
    for u in re.findall(r"https?://[^\s)\]\"'<>]+\.(?:png|jpe?g|webp)[^\s)\]\"'<>]*", s, re.I):
        out.append(("url", u))
    if not out:
        for u in re.findall(r"https?://[^\s)\]\"'<>]+", s):
            out.append(("url", u))
    return out


def _candidates(obj):
    found = []

    def walk(o):
        if isinstance(o, dict):
            if isinstance(o.get("b64_json"), str):
                found.append(("b64", o["b64_json"]))
            if isinstance(o.get("url"), str):
                found.append(("url", o["url"]))
            if isinstance(o.get("content"), str):
                found.extend(_scan_str(o["content"]))
            for k, v in o.items():
                if k not in ("b64_json", "url", "content"):
                    walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v) if not isinstance(v, str) else found.extend(_scan_str(v))

    walk(obj)
    return found


def _resolve(kind: str, val: str) -> bytes:
    if kind == "b64":
        return base64.b64decode(re.sub(r"\s+", "", val))
    with urllib.request.urlopen(val, timeout=120) as r:   # noqa: S310
        return r.read()


def _extract(raw_text: str) -> bytes:
    try:
        obj = json.loads(raw_text)
    except Exception:  # noqa: BLE001
        obj = None
    cands = _candidates(obj) if obj is not None else _scan_str(raw_text)
    for kind, val in cands:
        try:
            data = _resolve(kind, val)
            if data and len(data) > 100:
                return data
        except Exception:  # noqa: BLE001
            continue
    raise ValueError("no-image")


def normalize_base(b: str):
    """中转站常忘了写 /v1：只有域名时自动补上。返回 (规范化地址, 是否自动补过)。"""
    b = b.rstrip("/")
    if re.search(r"/v\d+$", b):                 # 已经是 .../v1 /v2 等
        return b, False
    if not urlparse(b).path.strip("/"):         # 只有域名、没路径
        return b + "/v1", True
    return b, False


def gen_one(api_key, base_url, prompt, model, size, quality, mode="auto", debug=False) -> bytes:
    if mode == "auto":                          # gemini 等：图在 chat 回复里；其它走 images 端点
        mode = "chat" if "gemini" in model.lower() else "images"
    if mode == "chat":
        url = base_url.rstrip("/") + "/chat/completions"
        payload = {"model": model,
                   "messages": [{"role": "user", "content": prompt}],
                   "stream": False}
    else:
        url = base_url.rstrip("/") + "/images/generations"
        payload = {"model": model, "prompt": prompt, "n": 1}
        if size:
            payload["size"] = size
        if model.startswith("dall-e"):
            payload["response_format"] = "b64_json"
            if model == "dall-e-3":
                payload["quality"] = "hd" if quality == "high" else "standard"
        else:
            payload["quality"] = quality
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "card-art-gen/1.0",
    }
    last = None
    for attempt in range(6):
        req = urllib.request.Request(
            url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST"
        )
        try:
            with urllib.request.urlopen(req, timeout=240) as r:   # noqa: S310
                raw = r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")
            low = body.lower()
            dropped = next((p for p in ("quality", "response_format", "size")
                            if p in payload and p in low), None)
            if dropped and any(w in low for w in ("unsupport", "invalid", "not allowed",
                                                  "extra", "unexpected", "param")):
                payload.pop(dropped, None)
                print(f"      · 模型不支持参数 {dropped}，去掉后重试", flush=True)
                continue
            last = f"HTTP {e.code}: {body[:400]}"
            if e.code in (408, 409, 429, 500, 502, 503, 504):
                wait = 2 ** attempt
                print(f"      ! {last}  ({attempt + 1}/6，{wait}s 后重试)", flush=True)
                time.sleep(wait); continue
            raise RuntimeError(last)             # 其它 4xx：参数/鉴权问题，停
        except (urllib.error.URLError, TimeoutError) as e:
            last = str(e); wait = 2 ** attempt
            print(f"      ! {last}  ({attempt + 1}/6，{wait}s 后重试)", flush=True)
            time.sleep(wait); continue

        if debug:
            print(f"      --- 返回前 800 字 ---\n{raw[:800]}\n      ---------------------", flush=True)
        head = raw.lstrip()[:200].lower()
        if head.startswith("<!doctype") or head.startswith("<html") or "<title>new api" in head:
            raise RuntimeError("接口返回的是网页(HTML)，多半是接口地址少了 /v1 或路径不对。\n"
                               f"      实际请求了：{url}\n"
                               "      把 OPENAI_BASE_URL 设成形如 https://域名/v1 再试。")
        try:
            return _extract(raw)
        except ValueError:
            raise RuntimeError("接口返回 200 但解析不到图片。把下面这段原样发我：\n"
                               f"      返回前 800 字：\n{raw[:800]}")
    raise RuntimeError(f"重试多次仍失败：{last}")


def main() -> None:
    ap = argparse.ArgumentParser(description="批量生成古董卡牌插画")
    ap.add_argument("--out", default=str(HERE / "card_art_out"))
    ap.add_argument("--quality", default="high", choices=["low", "medium", "high"])
    ap.add_argument("--model", default="gpt-image-1")
    ap.add_argument("--mode", default="auto", choices=["auto", "chat", "images"],
                    help="auto=按模型自动选(gemini→chat，其它→images)")
    ap.add_argument("--base-url", default=None)
    ap.add_argument("--size", default=None, help="覆盖默认尺寸，如 1024x1536")
    ap.add_argument("--only", default=None, help="只生成某个 cardId")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--debug", action="store_true", help="打印每次原始返回")
    ap.add_argument("--icon", action="store_true", help="改为生成 App 图标(1024×1024 方形)")
    ap.add_argument("--icon-count", type=int, default=4, help="出几版图标供挑选(默认4)")
    ap.add_argument("--table-bg", action="store_true", help="改为生成牌桌背景候选(1920×900 横版)")
    ap.add_argument("--table-count", type=int, default=3, help="出几版牌桌背景供挑选(默认3)")
    ap.add_argument("--use-table-bg", type=int, metavar="N",
                    help="把第 N 张牌桌背景候选压成 webp 装进 web/public/table_bg.webp")
    args = ap.parse_args()

    # 装载已生成的牌桌背景候选(不联网)
    if args.use_table_bg is not None:
        src = HERE / "card_art_out" / f"table_bg_{args.use_table_bg}.png"
        if not src.exists():
            sys.exit(f"找不到 {src}(先跑 --table-bg 生成候选)")
        dst = HERE.parent.parent.parent / "web" / "public" / "table_bg.webp"
        dst.parent.mkdir(parents=True, exist_ok=True)
        crop_landscape(Image.open(src)).save(dst, "WEBP", quality=80, method=6)
        print(f"✓ 已装载牌桌背景 → {dst}({dst.stat().st_size // 1024}KB)")
        print("用 GitHub Desktop 提交 web/public/table_bg.webp 并推送、合并 main 即上线。")
        return

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        sys.exit("请先设置：export OPENAI_API_KEY=...")
    if not PROMPTS_FILE.exists():
        sys.exit(f"找不到提示词文件：{PROMPTS_FILE}")
    base_url = args.base_url or os.environ.get("OPENAI_BASE_URL") or "https://api.openai.com/v1"
    base_url, autov1 = normalize_base(base_url)
    size = args.size or DEFAULT_SIZE.get(args.model, "1024x1536")

    if args.table_bg:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        print(f"出牌桌背景 ×{args.table_count}  模型={args.model}  接口={base_url}\n")
        ok = 0
        for i in range(1, args.table_count + 1):
            dst = out / f"table_bg_{i}.png"
            print(f"[{i}/{args.table_count}] {dst.name}  生成中…", flush=True)
            try:
                raw = gen_one(api_key, base_url, TABLE_BG_PROMPT, args.model, size,
                              args.quality, args.mode, args.debug)
                crop_landscape(Image.open(io.BytesIO(raw))).save(dst, "PNG")
                ok += 1
                print(f"        ✓ {dst}")
            except Exception as e:  # noqa: BLE001
                print(f"        ✗ 失败:{e}")
        print(f"\n出了 {ok} 版牌桌背景 → {out}")
        print("挑中第 N 张后装载:python3 generate_card_art.py --use-table-bg N")
        return

    if args.icon:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        print(f"出 App 图标 ×{args.icon_count}  模型={args.model}  接口={base_url}\n")
        ok = 0
        for i in range(1, args.icon_count + 1):
            dst = out / f"app_icon_{i}.png"
            print(f"[{i}/{args.icon_count}] {dst.name}  生成中…", flush=True)
            try:
                raw = gen_one(api_key, base_url, ICON_PROMPT, args.model, size,
                              args.quality, args.mode, args.debug)
                crop_square(Image.open(io.BytesIO(raw)), 1024).save(dst, "PNG")
                ok += 1
                print(f"        ✓ {dst}")
            except Exception as e:  # noqa: BLE001
                print(f"        ✗ 失败：{e}")
        print(f"\n出了 {ok} 版图标 → {out}")
        print("挑一张满意的，拖进 Xcode 的 Assets.xcassets → AppIcon（1024 单格）。")
        return

    cards = json.loads(PROMPTS_FILE.read_text(encoding="utf-8"))
    if args.only:
        cards = [c for c in cards if c["cardId"] == args.only]
        if not cards:
            sys.exit(f"找不到 cardId={args.only}")

    out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    total, done, skipped, failed = len(cards), 0, 0, []
    print(f"共 {total} 张  →  {out}")
    eff_mode = args.mode if args.mode != "auto" else ("chat" if "gemini" in args.model.lower() else "images")
    extra = f"尺寸={size}  quality={args.quality}  " if eff_mode == "images" else ""
    print(f"模型={args.model}  调用={eff_mode}  {extra}接口={base_url}"
          f"{'  (已自动补 /v1)' if autov1 else ''}\n")
    for i, c in enumerate(cards, 1):
        cid = c["cardId"]; dst = out / f"{cid}.png"
        if dst.exists() and not args.force:
            print(f"[{i}/{total}] {cid}  已存在，跳过"); skipped += 1; continue
        print(f"[{i}/{total}] {cid}  生成中…", flush=True)
        try:
            raw = gen_one(api_key, base_url, c["prompt"], args.model, size, args.quality, args.mode, args.debug)
            crop_to_5x7(Image.open(io.BytesIO(raw))).save(dst, "PNG")
            done += 1; print(f"        ✓ {dst}")
        except Exception as e:  # noqa: BLE001
            failed.append(cid); print(f"        ✗ 失败：{cid} — {e}")

    print(f"\n完成：新生成 {done}，跳过 {skipped}，失败 {len(failed)}。")
    if failed:
        print("失败的 cardId：" + ", ".join(failed))
    print(f"\n下一步装图：\n  {HERE.parent / 'install-card-art.sh'} {out}")


if __name__ == "__main__":
    main()
