#!/bin/bash

echo "=========================================="
echo "手動設置 Flutter 插件（無需 flutter pub get）"
echo "=========================================="
echo ""

cd /Users/Eric/flutter_application_1

# 創建插件連結目錄
mkdir -p ios/.symlinks/plugins

# 定義需要下載的插件
PLUGINS=(
    "cloud_firestore:6.1.1"
    "firebase_core:4.3.0"
    "firebase_messaging:16.1.0"
    "flutter_secure_storage:8.0.0"
    "permission_handler_apple:9.4.7"
)

# 臨時目錄
TEMP_DIR=$(mktemp -d)
echo "使用臨時目錄: $TEMP_DIR"
echo ""

# 下載並設置每個插件
for PLUGIN_INFO in "${PLUGINS[@]}"; do
    PLUGIN_NAME=$(echo $PLUGIN_INFO | cut -d: -f1)
    PLUGIN_VERSION=$(echo $PLUGIN_INFO | cut -d: -f2)
    
    echo "處理插件: $PLUGIN_NAME ($PLUGIN_VERSION)"
    
    # 下載插件
    PLUGIN_URL="https://pub.dev/packages/$PLUGIN_NAME/versions/$PLUGIN_VERSION.tar.gz"
    PLUGIN_TAR="$TEMP_DIR/${PLUGIN_NAME}-${PLUGIN_VERSION}.tar.gz"
    
    echo "  下載中..."
    curl -L -o "$PLUGIN_TAR" "$PLUGIN_URL" 2>/dev/null
    
    if [ $? -eq 0 ] && [ -f "$PLUGIN_TAR" ]; then
        # 解壓
        PLUGIN_DIR="$TEMP_DIR/$PLUGIN_NAME-$PLUGIN_VERSION"
        mkdir -p "$PLUGIN_DIR"
        tar -xzf "$PLUGIN_TAR" -C "$PLUGIN_DIR" --strip-components=1 2>/dev/null
        
        # 創建連結
        if [ -d "$PLUGIN_DIR" ]; then
            ln -sf "$PLUGIN_DIR" "ios/.symlinks/plugins/$PLUGIN_NAME"
            echo "  ✓ 已創建連結: $PLUGIN_NAME"
        else
            echo "  ✗ 解壓失敗: $PLUGIN_NAME"
        fi
    else
        echo "  ✗ 下載失敗: $PLUGIN_NAME"
        echo "    嘗試使用本地 pub cache..."
        
        # 嘗試在常見位置查找
        POSSIBLE_LOCATIONS=(
            "$HOME/.pub-cache/hosted/pub.dev/$PLUGIN_NAME-$PLUGIN_VERSION"
            "$HOME/Library/Caches/pub/hosted/pub.dev/$PLUGIN_NAME-$PLUGIN_VERSION"
            "/opt/homebrew/share/flutter/.pub-cache/hosted/pub.dev/$PLUGIN_NAME-$PLUGIN_VERSION"
        )
        
        FOUND=0
        for LOC in "${POSSIBLE_LOCATIONS[@]}"; do
            if [ -d "$LOC" ]; then
                ln -sf "$LOC" "ios/.symlinks/plugins/$PLUGIN_NAME"
                echo "  ✓ 找到本地版本並創建連結: $PLUGIN_NAME"
                FOUND=1
                break
            fi
        done
        
        if [ $FOUND -eq 0 ]; then
            echo "  ⚠️  無法找到 $PLUGIN_NAME，將跳過"
        fi
    fi
    echo ""
done

# 清理臨時文件
rm -rf "$TEMP_DIR"

echo "=========================================="
echo "插件設置完成"
echo "=========================================="
echo ""
echo "驗證插件連結："
ls -la ios/.symlinks/plugins/ | grep -v "^total" | grep -v "^d"
echo ""

# 檢查是否有 iOS 目錄
echo "檢查插件 iOS 支持："
for PLUGIN in ios/.symlinks/plugins/*; do
    if [ -L "$PLUGIN" ] || [ -d "$PLUGIN" ]; then
        PLUGIN_NAME=$(basename "$PLUGIN")
        if [ -d "$PLUGIN/ios" ] || [ -d "$(readlink "$PLUGIN")/ios" 2>/dev/null ]; then
            echo "  ✓ $PLUGIN_NAME 有 iOS 支持"
        else
            echo "  ⚠️  $PLUGIN_NAME 沒有 iOS 目錄"
        fi
    fi
done
echo ""

echo "現在可以嘗試運行: cd ios && pod install"
