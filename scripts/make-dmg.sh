#!/bin/sh
# 打 DMG：定制窗口（背景图上画安装与首次打开指引）+ Leaf.app + Applications 快捷方式。
# 默认输出到 ~/Downloads。首次运行时系统可能询问是否允许控制「访达」，需允许。
set -e
cd "$(dirname "$0")/.."

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Leaf.xcodeproj -scheme Leaf -configuration Release \
  -derivedDataPath .build/DerivedData build -quiet 2>/dev/null

APP=.build/DerivedData/Build/Products/Release/Leaf.app
VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
VOLNAME="Leaf $VERSION"
OUT="${1:-$HOME/Downloads}/Leaf-$VERSION.dmg"
WORK=.build/dmg
RW="$WORK/rw.dmg"

# 同名卷已挂载（比如打开过上一版安装包）会冲突，先推出
[ -d "/Volumes/$VOLNAME" ] && hdiutil detach -quiet "/Volumes/$VOLNAME"

rm -rf "$WORK" && mkdir -p "$WORK/stage/.background"
cp -R "$APP" "$WORK/stage/"
ln -s /Applications "$WORK/stage/Applications"
swift scripts/dmg/background.swift "$WORK" 2>/dev/null
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/stage/.background/bg.tiff" 2>/dev/null

hdiutil create -volname "$VOLNAME" -srcfolder "$WORK/stage" -format UDRW -fs HFS+ -quiet "$RW"
DEV=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk '/Apple_HFS/ {print $1}')

# 窗口 640×460 内容区 + 标题栏；图标中心与背景图上的箭头对齐
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 840, 608}
    set opts to icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 96
    set text size of opts to 13
    set background picture of opts to file ".background:bg.tiff"
    set position of item "Leaf.app" of container window to {170, 150}
    set position of item "Applications" of container window to {470, 150}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach -quiet "$DEV"
rm -f "$OUT"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -quiet -o "$OUT"
rm -rf "$WORK"

# 构建目录副本别留在 LaunchServices 登记表里
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u "$APP" 2>/dev/null || true
echo "$OUT"
