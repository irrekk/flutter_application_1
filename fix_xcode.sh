#!/bin/bash

echo "正在修復 Xcode 連接問題..."

# 設置 git 安全目錄
git config --global --add safe.directory /opt/homebrew/share/flutter

# 清理舊的配置
cd /Users/Eric/flutter_application_1
rm -rf ios/.symlinks ios/Flutter/Generated.xcconfig .dart_tool/flutter_build

# 重新獲取 Flutter 依賴
echo "正在獲取 Flutter 依賴..."
flutter pub get

# 安裝 CocoaPods 依賴
echo "正在安裝 CocoaPods 依賴..."
cd ios
pod install

echo "完成！現在可以在 Xcode 中打開 Runner.xcworkspace"
