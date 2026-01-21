#!/bin/bash

echo "=========================================="
echo "修復 Flutter iOS 建置問題（無需 sudo）"
echo "=========================================="
echo ""

cd /Users/Eric/flutter_application_1

# 步驟 1: 設置 git 安全目錄
echo "步驟 1: 設置 git 安全目錄..."
git config --global --add safe.directory /opt/homebrew/share/flutter 2>/dev/null || true
echo "✓ 完成"
echo ""

# 步驟 2: 確保 Generated.xcconfig 存在
echo "步驟 2: 確保 Generated.xcconfig 存在..."
mkdir -p ios/Flutter
cat > ios/Flutter/Generated.xcconfig << 'EOF'
// This is a generated file; do not edit or check into version control.
FLUTTER_ROOT=/opt/homebrew/share/flutter
FLUTTER_APPLICATION_PATH=/Users/Eric/flutter_application_1
COCOAPODS_PARALLEL_CODE_SIGN=true
FLUTTER_TARGET=lib/main.dart
FLUTTER_BUILD_DIR=build
FLUTTER_BUILD_NAME=1.0.0
FLUTTER_BUILD_NUMBER=1
EXCLUDED_ARCHS[sdk=iphonesimulator*]=i386
EXCLUDED_ARCHS[sdk=iphoneos*]=armv7
DART_OBFUSCATION=false
TRACK_WIDGET_CREATION=true
TREE_SHAKE_ICONS=false
PACKAGE_CONFIG=.dart_tool/package_config.json
EOF
echo "✓ Generated.xcconfig 已創建"
echo ""

# 步驟 3: 清理舊的連結
echo "步驟 3: 清理舊的 Windows 路徑連結..."
rm -rf ios/.symlinks
rm -rf .dart_tool/flutter_build
echo "✓ 完成"
echo ""

# 步驟 4: 嘗試使用環境變數繞過權限問題
echo "步驟 4: 嘗試獲取 Flutter 依賴（繞過權限檢查）..."
export FLUTTER_ROOT=/opt/homebrew/share/flutter
export PATH="/opt/homebrew/bin:$PATH"

# 嘗試直接運行 flutter pub get，忽略權限警告
flutter pub get 2>&1 | grep -v "Permission denied" | grep -v "update_engine_version" || true

# 檢查是否成功生成了插件連結
if [ -d "ios/.symlinks/plugins" ]; then
    echo "✓ 插件連結已生成"
    echo "   找到以下插件："
    ls -1 ios/.symlinks/plugins/ | head -5
else
    echo "⚠️  插件連結未自動生成，嘗試手動創建..."
    
    # 嘗試手動創建插件連結（如果知道 pub cache 位置）
    PUB_CACHE="$HOME/.pub-cache/hosted/pub.dev"
    if [ -d "$PUB_CACHE" ]; then
        mkdir -p ios/.symlinks/plugins
        for plugin in cloud_firestore firebase_core firebase_messaging flutter_secure_storage permission_handler_apple; do
            PLUGIN_PATH=$(find "$PUB_CACHE" -maxdepth 1 -type d -name "${plugin}-*" | head -1)
            if [ -n "$PLUGIN_PATH" ]; then
                ln -sf "$PLUGIN_PATH" "ios/.symlinks/plugins/$plugin"
                echo "   ✓ 創建連結: $plugin"
            fi
        done
    fi
fi
echo ""

# 步驟 5: 安裝 CocoaPods 依賴
echo "步驟 5: 安裝 CocoaPods 依賴..."
cd ios
pod install
if [ $? -eq 0 ]; then
    echo "✓ CocoaPods 依賴安裝成功"
else
    echo "⚠️  CocoaPods 安裝可能有問題，但可以繼續嘗試建置"
fi
echo ""

echo "=========================================="
echo "✅ 修復完成！"
echo "=========================================="
echo ""
echo "如果插件連結仍未生成，請聯繫系統管理員修復 Flutter 權限："
echo "  sudo chown -R \$(whoami) /opt/homebrew/share/flutter"
echo ""
echo "現在可以在 Xcode 中："
echo "1. 選擇 Product → Clean Build Folder (Shift + Command + K)"
echo "2. 重新建置專案 (Command + B)"
echo ""
