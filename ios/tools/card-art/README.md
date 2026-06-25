# 卡牌插画批量生成（One Piece TCG 风格）

用 OpenAI `gpt-image-1` 一条命令生成全部 41 张卡牌插画，自动裁成 **5:7 / 1500×2100**，
再用同目录上一层的 `install-card-art.sh` 装进 `CardArt.xcassets`。

> ⚠️ Claude 这边的云环境**无法联网到 OpenAI**，所以图要在**你自己的 Mac** 上跑（本机不受限）。

## 文件
- `card_art_prompts.json` —— 41 条提示词（40 张古董 + `card_back`），每条已含统一画风、套系配色、5:7 与「顶/底叠字安全区」约束。
- `generate_card_art.py` —— 批量生成脚本（含失败重试、断点续跑、本地裁切放大）。

## 一次性准备
```bash
# 1) 装依赖（建议在虚拟环境里）
python3 -m pip install openai pillow

# 2) 配置你的 OpenAI 钥匙
export OPENAI_API_KEY=sk-你的key
```

### 用「中转站 / 自建网关」而非官方 OpenAI
中转站除了 key，还必须设**接口地址**，并确认它支持出图模型：
```bash
export OPENAI_API_KEY=中转站给的key
export OPENAI_BASE_URL=https://你的中转站域名/v1     # 关键：接口地址，结尾一般是 /v1
python3 generate_card_art.py                         # 默认走 gpt-image-1
python3 generate_card_art.py --model dall-e-3        # 中转站只代理 dall-e-3 时
```
脚本会自动按模型选尺寸、并兼容返回 b64 或 url 两种形态。**先 `--only lost_paintings_01` 测一张**，确认中转站真的能出图再批量。

#### Gemini 出图模型（如 `gemini-3-pro-image-preview`）
这类模型不走 `/images/generations`，而是把图片夹在 **`/chat/completions`** 的回复里。脚本对名字含 `gemini` 的模型会**自动切到 chat 调用**并从回复里抠图，无需额外设置：
```bash
export OPENAI_BASE_URL=https://你的中转站域名/v1
python3 generate_card_art.py --model gemini-3-pro-image-preview          # 质量高
python3 generate_card_art.py --model gemini-3.1-flash-image-preview      # 更快更省
```
（如需手动指定通道：`--mode chat` 或 `--mode images`。）

## 生成
```bash
cd ios/tools/card-art

python3 generate_card_art.py                  # 全部 41 张 → ./card_art_out
python3 generate_card_art.py --quality medium # 省钱档
python3 generate_card_art.py --only seals_02  # 只重做某一张
python3 generate_card_art.py --force          # 覆盖重生成
```
- 已生成的 PNG 默认**跳过**，可随时 Ctrl-C 中断、再次运行**续生成**。
- 某张失败会跳过并在末尾列出，重跑即补。

## 装进图集
```bash
../install-card-art.sh ./card_art_out
```
（脚本只认 `<cardId>.png`，文件名正好就是脚本输出的名字。）

然后回 Xcode：**Cmd+Shift+K** 清理 → **Run**，真图就上了；没生成的卡仍走程序化渐变兜底。

## 费用（约）
`gpt-image-1`、1024×1536：
- `high` ≈ 每张 $0.15–0.20 → 41 张约 **$7–8**
- `medium` ≈ 每张 $0.04 左右 → 41 张约 **$1.5–2**

先 `--only lost_paintings_01` 出一张看看风格满不满意，再批量，省钱。

## 想换风格 / 改某张
直接编辑 `card_art_prompts.json` 里对应 `cardId` 的 `prompt` 字段，再 `--only <cardId> --force` 重跑即可。
