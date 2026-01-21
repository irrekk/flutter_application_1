# Xcode 建置問題修復指南

## 當前問題

1. **Flutter 引擎權限問題**：Flutter 安裝目錄的權限不正確
2. **插件連結缺失**：`.symlinks/plugins/` 目錄不存在

## 解決步驟

### 步驟 1：修復 Flutter 權限（可選，如果問題持續）

如果 Flutter 命令持續出現權限錯誤，可以嘗試：

```bash
# 檢查 Flutter 安裝位置
which flutter

# 如果使用 Homebrew 安裝，可能需要重新安裝
brew reinstall flutter
```

### 步驟 2：重新生成 Flutter 插件連結（必須）

在終端中執行以下命令：

```bash
cd /Users/Eric/flutter_application_1

# 設置 git 安全目錄（如果需要）
git config --global --add safe.directory /opt/homebrew/share/flutter

# 重新獲取 Flutter 依賴並生成插件連結
flutter pub get

# 檢查插件連結是否生成
ls -la ios/.symlinks/plugins/
```

### 步驟 3：安裝 CocoaPods 依賴（必須）

```bash
cd ios
pod install
```

### 步驟 4：在 Xcode 中清理並重新建置

1. 在 Xcode 中選擇 **Product → Clean Build Folder**（或按 `Shift + Command + K`）
2. 關閉 Xcode
3. 刪除 DerivedData（可選，如果問題持續）：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
   ```
4. 重新打開 Xcode
5. 重新建置專案（按 `Command + B`）

## 如果問題仍然存在

如果執行 `flutter pub get` 時仍然出現權限錯誤，可以嘗試：

1. **使用 sudo（不推薦，但可以臨時解決）**：
   ```bash
   sudo flutter pub get
   ```

2. **檢查 Flutter 安裝**：
   ```bash
   flutter doctor -v
   ```

3. **重新安裝 Flutter**（如果其他方法都失敗）：
   ```bash
   brew uninstall flutter
   brew install flutter
   ```

## 已修復的配置

✅ `Generated.xcconfig` - 已更新為正確的 macOS 路徑  
✅ `flutter_export_environment.sh` - 已更新為正確的 macOS 路徑  
✅ Bundle Identifier - 已更改為 `com.ericsun.spartans`  
✅ 開發團隊設置 - 已配置為 `F6N7366KVX`
