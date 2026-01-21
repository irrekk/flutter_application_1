#!/bin/bash

echo "=========================================="
echo "修復 Flutter iOS 建置問題"
echo "=========================================="
echo ""

cd /Users/Eric/flutter_application_1

# 步驟 1: 設置 git 安全目錄
echo "步驟 1: 設置 git 安全目錄..."
git config --global --add safe.directory /opt/homebrew/share/flutter 2>/dev/null || true
echo "✓ 完成"
echo ""

# 步驟 2: 清理舊的連結和建置文件
echo "步驟 2: 清理舊的連結和建置文件..."
rm -rf ios/.symlinks
rm -rf ios/Flutter/Generated.xcconfig
rm -rf .dart_tool/flutter_build
echo "✓ 完成"
echo ""

# 步驟 3: 修復 Flutter 權限（如果需要）
echo "步驟 3: 檢查 Flutter 權限..."
if [ ! -w /opt/homebrew/share/flutter/bin/cache/engine.stamp ]; then
    echo "⚠️  檢測到 Flutter 權限問題"
    echo "   請執行以下命令修復權限（需要輸入密碼）："
    echo "   sudo chown -R \$(whoami) /opt/homebrew/share/flutter"
    echo ""
    read -p "是否現在執行權限修復？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo chown -R $(whoami) /opt/homebrew/share/flutter
        echo "✓ 權限已修復"
    else
        echo "⚠️  跳過權限修復，如果後續出現權限錯誤，請手動執行上述命令"
    fi
else
    echo "✓ Flutter 權限正常"
fi
echo ""

# 步驟 4: 重新獲取 Flutter 依賴
echo "步驟 4: 重新獲取 Flutter 依賴並生成插件連結..."
flutter pub get
if [ $? -eq 0 ]; then
    echo "✓ Flutter 依賴獲取成功"
else
    echo "❌ Flutter 依賴獲取失敗"
    echo "   如果出現權限錯誤，請先執行："
    echo "   sudo chown -R \$(whoami) /opt/homebrew/share/flutter"
    exit 1
fi
echo ""

# 步驟 5: 驗證插件連結
echo "步驟 5: 驗證插件連結..."
if [ -d "ios/.symlinks/plugins" ]; then
    echo "✓ 插件連結目錄已生成"
    echo "   找到以下插件："
    ls -1 ios/.symlinks/plugins/ | head -5
else
    echo "❌ 插件連結目錄未生成"
    exit 1
fi
echo ""

# 步驟 6: 安裝 CocoaPods 依賴
echo "步驟 6: 安裝 CocoaPods 依賴..."
cd ios
pod install
if [ $? -eq 0 ]; then
    echo "✓ CocoaPods 依賴安裝成功"
else
    echo "❌ CocoaPods 依賴安裝失敗"
    exit 1
fi
echo ""

echo "=========================================="
echo "✅ 所有步驟完成！"
echo "=========================================="
echo ""
echo "現在可以在 Xcode 中："
echo "1. 選擇 Product → Clean Build Folder (Shift + Command + K)"
echo "2. 重新建置專案 (Command + B)"
echo ""
