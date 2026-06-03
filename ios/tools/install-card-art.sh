#!/usr/bin/env bash
# 把一批以 cardId 命名的卡牌 PNG 安装进 CardArt.xcassets。
#   用法: ios/tools/install-card-art.sh <源目录>
# 源目录里放 lost_paintings_01.png … paper_money_04.png（可含 card_back.png），
# 文件名必须等于 cardId。脚本会拷进对应 imageset 并写好 Contents.json。
set -euo pipefail
SRC="${1:?用法: $0 <含 cardId.png 的源目录>}"
CATALOG="$(cd "$(dirname "$0")/.." && pwd)/AntiqueAuction/CardArt.xcassets"
[ -d "$CATALOG" ] || { echo "找不到图集: $CATALOG"; exit 1; }
shopt -s nullglob
count=0
for png in "$SRC"/*.png; do
  id="$(basename "$png" .png)"
  set_dir="$CATALOG/$id.imageset"
  [ -d "$set_dir" ] || { echo "跳过 $id（图集无同名 imageset）"; continue; }
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
  count=$((count+1)); echo "安装 $id"
done
echo "完成：安装了 $count 张。"
