#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/TATSU.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

echo "Compiling..."
swiftc \
  -o "$APP_BUNDLE/Contents/MacOS/TATSU" \
  "$SCRIPT_DIR/TATSU/main.swift" \
  "$SCRIPT_DIR/TATSU/AppDelegate.swift" \
  -framework Cocoa \
  -framework UserNotifications

cp "$SCRIPT_DIR/TATSU/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "Building app icon..."
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
SRC_ICON="$SCRIPT_DIR/tatsu_icon_flying_dragon.png"
sips -z 16 16     "$SRC_ICON" --out "$ICONSET_DIR/icon_16x16.png"      > /dev/null
sips -z 32 32     "$SRC_ICON" --out "$ICONSET_DIR/icon_16x16@2x.png"   > /dev/null
sips -z 32 32     "$SRC_ICON" --out "$ICONSET_DIR/icon_32x32.png"      > /dev/null
sips -z 64 64     "$SRC_ICON" --out "$ICONSET_DIR/icon_32x32@2x.png"   > /dev/null
sips -z 128 128   "$SRC_ICON" --out "$ICONSET_DIR/icon_128x128.png"    > /dev/null
sips -z 256 256   "$SRC_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$SRC_ICON" --out "$ICONSET_DIR/icon_256x256.png"    > /dev/null
sips -z 512 512   "$SRC_ICON" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$SRC_ICON" --out "$ICONSET_DIR/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$SRC_ICON" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET_DIR"

echo "Signing..."
codesign --force --sign - "$APP_BUNDLE"

echo "Build complete: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
