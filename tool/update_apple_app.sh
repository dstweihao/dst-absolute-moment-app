#!/bin/bash
set -e

echo "==> 清理旧构建产物..."
rm -rf build

echo "==> 清理 macOS 扩展属性..."
find macos lib tool -name ".DS_Store" -delete 2>/dev/null || true
find macos lib tool -name "._*" -delete 2>/dev/null || true
xattr -cr macos lib tool 2>/dev/null || true

echo "==> 自动构建 Apple macOS 原生应用..."
flutter build macos --release

echo "==> 签署与分发..."
APP_BUNDLE=$(ls -d build/macos/Build/Products/Release/*.app | head -n 1)
APP_NAME=$(basename "$APP_BUNDLE")

find "$APP_BUNDLE" -name ".DS_Store" -delete 2>/dev/null || true
find "$APP_BUNDLE" -name "._*" -delete 2>/dev/null || true
xattr -r -d com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
find "$APP_BUNDLE" -exec xattr -d com.apple.FinderInfo {} + 2>/dev/null || true
find "$APP_BUNDLE" -type f -exec xattr -c {} + 2>/dev/null || true
find "$APP_BUNDLE" -type d -exec xattr -c {} + 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
dot_clean -m "$APP_BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE"

rm -rf release_macos/*
mkdir -p release_macos
cp -R "$APP_BUNDLE" release_macos/

echo "==> 重启 macOS 客户端..."
pkill -f "absolute_moment_app" 2>/dev/null || true
pkill -f "绝对时刻" 2>/dev/null || true
sleep 0.5
open "release_macos/$APP_NAME"

echo "==> macOS App 已自动更新并启动！"
