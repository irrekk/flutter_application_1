#!/bin/bash

echo "=========================================="
echo "手動設置 Flutter 插件（改進版）"
echo "=========================================="
echo ""

cd /Users/Eric/flutter_application_1

# 創建永久插件目錄（在專案內）
PLUGIN_CACHE_DIR="$PWD/.plugin_cache"
mkdir -p "$PLUGIN_CACHE_DIR"
mkdir -p ios/.symlinks/plugins

echo "使用永久插件緩存目錄: $PLUGIN_CACHE_DIR"
echo ""

# 定義需要下載的插件
PLUGINS=(
    "cloud_firestore:6.1.1"
    "firebase_core:4.3.0"
    "firebase_messaging:16.1.0"
    "flutter_secure_storage:10.0.0"
    "permission_handler_apple:9.4.7"
)

# 下載並設置每個插件
for PLUGIN_INFO in "${PLUGINS[@]}"; do
    PLUGIN_NAME=$(echo $PLUGIN_INFO | cut -d: -f1)
    PLUGIN_VERSION=$(echo $PLUGIN_INFO | cut -d: -f2)
    
    echo "處理插件: $PLUGIN_NAME ($PLUGIN_VERSION)"
    
    PLUGIN_DIR="$PLUGIN_CACHE_DIR/$PLUGIN_NAME-$PLUGIN_VERSION"
    
    # 如果已經存在，跳過下載
    if [ -d "$PLUGIN_DIR" ] && [ -d "$PLUGIN_DIR/ios" ]; then
        echo "  ✓ 插件已存在，跳過下載"
    else
        # 嘗試從 pub.dev 下載
        echo "  下載中..."
        
        # pub.dev 的實際下載 URL 格式
        DOWNLOAD_URL="https://pub.dev/packages/$PLUGIN_NAME/versions/$PLUGIN_VERSION.tar.gz"
        
        # 下載到臨時文件
        TEMP_TAR=$(mktemp)
        curl -L -f -s -o "$TEMP_TAR" "$DOWNLOAD_URL"
        
        if [ $? -eq 0 ] && [ -f "$TEMP_TAR" ] && [ -s "$TEMP_TAR" ]; then
            # 創建目標目錄
            mkdir -p "$PLUGIN_DIR"
            
            # 解壓
            tar -xzf "$TEMP_TAR" -C "$PLUGIN_DIR" --strip-components=1 2>/dev/null
            
            # 清理臨時文件
            rm -f "$TEMP_TAR"
            
            if [ -d "$PLUGIN_DIR" ] && [ "$(ls -A $PLUGIN_DIR 2>/dev/null)" ]; then
                echo "  ✓ 下載並解壓成功"
            else
                echo "  ✗ 解壓失敗或目錄為空"
                rm -rf "$PLUGIN_DIR"
                continue
            fi
        else
            echo "  ✗ 下載失敗，嘗試其他方法..."
            rm -f "$TEMP_TAR"
            
            # 嘗試使用 git clone（如果可用）
            GIT_URL="https://github.com/firebase/flutterfire.git"
            if [ "$PLUGIN_NAME" = "cloud_firestore" ] || [ "$PLUGIN_NAME" = "firebase_core" ] || [ "$PLUGIN_NAME" = "firebase_messaging" ]; then
                echo "  提示: Firebase 插件需要從 flutterfire 倉庫獲取"
                echo "  請手動從 https://pub.dev/packages/$PLUGIN_NAME 下載"
            fi
            continue
        fi
    fi
    
    # 檢查 iOS 目錄
    if [ -d "$PLUGIN_DIR/ios" ]; then
        # 創建連結
        ln -sf "$PLUGIN_DIR" "ios/.symlinks/plugins/$PLUGIN_NAME"
        echo "  ✓ 已創建連結: $PLUGIN_NAME"
        
        # 驗證 podspec
        if [ -f "$PLUGIN_DIR/ios/$PLUGIN_NAME.podspec" ] || [ -f "$PLUGIN_DIR/ios/${PLUGIN_NAME//_/-}.podspec" ]; then
            echo "  ✓ 找到 podspec 文件"
        else
            echo "  ⚠️  未找到 podspec 文件，但 iOS 目錄存在"
        fi
    else
        echo "  ⚠️  iOS 目錄不存在於 $PLUGIN_DIR"
        # 即使沒有 iOS 目錄，也創建連結（可能插件結構不同）
        ln -sf "$PLUGIN_DIR" "ios/.symlinks/plugins/$PLUGIN_NAME"
    fi
    echo ""
done

# 清理臨時目錄的舊連結
echo "清理舊的臨時目錄連結..."
find ios/.symlinks/plugins -type l -exec sh -c 'if [ ! -e "$(readlink "$1")" ]; then rm "$1"; fi' _ {} \;
echo ""

echo "=========================================="
echo "插件設置完成"
echo "=========================================="
echo ""

# 驗證插件連結
echo "驗證插件連結："
for PLUGIN_LINK in ios/.symlinks/plugins/*; do
    if [ -L "$PLUGIN_LINK" ]; then
        PLUGIN_NAME=$(basename "$PLUGIN_LINK")
        TARGET=$(readlink "$PLUGIN_LINK")
        if [ -e "$TARGET" ]; then
            if [ -d "$TARGET/ios" ]; then
                echo "  ✓ $PLUGIN_NAME -> $TARGET (有 iOS 目錄)"
            else
                echo "  ⚠️  $PLUGIN_NAME -> $TARGET (無 iOS 目錄)"
            fi
        else
            echo "  ✗ $PLUGIN_NAME -> $TARGET (連結失效)"
        fi
    fi
done
echo ""

echo "現在可以嘗試運行: cd ios && pod install"
