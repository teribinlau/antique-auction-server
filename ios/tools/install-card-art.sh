#!/usr/bin/env bash
# 把一批以 cardId 命名的卡牌 PNG 安装进 CardArt.xcassets。
#   用法: install-card-art.sh <源目录> [目标 CardArt.xcassets 路径]
#
# 源目录里放 lost_paintings_01.png … paper_money_04.png（可含 card_back.png），
# 文件名必须等于 cardId。脚本会拷进对应 imageset 并写好 Contents.json。
#
# 不给第二个参数：默认装进本仓库 ios/AntiqueAuction/CardArt.xcassets。
# 你的 Xcode 工程在别处（用的是自己那份 .xcassets）时，把那份 CardArt.xcassets 的
# 完整路径作为第二个参数传入，例如：
#   install-card-art.sh ./card-art/card_art_out \
#     /Users/claw/Desktop/AntiqueAuction/AntiqueAuction/CardArt.xcassets
set -euo pipefail
SRC="${1:?用法: $0 <含 cardId.png 的源目录> [目标 CardArt.xcassets]}"
CATALOG="${2:-$(cd "$(dirname "$0")/.." && pwd)/AntiqueAuction/CardArt.xcassets}"
[ -d "$SRC" ] || { echo "源目录不存在: $SRC"; exit 1; }
mkdir -p "$CATALOG"
echo "装入图集: $CATALOG"
shopt -s nullglob
count=0
for png in "$SRC"/*.png; do
  id="$(basename "$png" .png)"
  set_dir="$CATALOG/$id.imageset"
  mkdir -p "$set_dir"
  cp -f "$png" "$set_dir/$id.png"
  cat > "$set_dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$id.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
  count=$((count+1)); echo "  安装 $id"
done
echo "完成：安装了 $count 张 → $CATALOG"
if [ "$count" -eq 0 ]; then
  echo "（源目录里没有 .png——先跑 generate_card_art.py 生成图）"
fi
