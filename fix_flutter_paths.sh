#!/bin/bash

echo "正在修復 Flutter 路徑和重新生成插件..."

cd /Users/Eric/flutter_application_1

# 設置 git 安全目錄（如果需要）
git config --global --add safe.directory /opt/homebrew/share/flutter 2>/dev/null || true

# 重新獲取 Flutter 依賴並生成插件連結
echo "正在運行 flutter pub get..."
flutter pub get

# 安裝 CocoaPods 依賴
echo "正在安裝 CocoaPods 依賴..."
cd ios
pod install

echo ""
echo "完成！現在可以在 Xcode 中重新建置專案了。"
echo "請在 Xcode 中："
echo "1. 選擇 Product → Clean Build Folder"
echo "2. 然後重新建置專案"
