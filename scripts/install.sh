#!/bin/sh
# 构建 Release 并装到 /Applications，顺带处理 LaunchServices 登记与图标缓存。
set -e
cd "$(dirname "$0")/.."

if pgrep -x Leaf >/dev/null; then
  echo "Leaf 正在运行，先退出再装" >&2
  exit 1
fi

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Leaf.xcodeproj -scheme Leaf -configuration Release \
  -derivedDataPath .build/DerivedData build -quiet

LS=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
PRODUCTS=.build/DerivedData/Build/Products
DEST="/Applications/Leaf.app"

rm -rf "$DEST"
cp -R "$PRODUCTS/Release/Leaf.app" "$DEST"

# 构建目录里的副本别留在登记表里，否则 Finder 可能打开旧版
for config in Debug Release; do
  "$LS" -u "$PRODUCTS/$config/Leaf.app" 2>/dev/null || true  # 未登记时报 -10814，忽略
done

# 更新时间戳 + 重新登记，让 Finder/Dock 丢掉旧图标缓存
touch "$DEST" "$DEST/Contents/Info.plist"
"$LS" -f "$DEST"
echo "已安装 $DEST"
