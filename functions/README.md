# Cloud Functions for Training Slots

這個目錄包含三個 Firebase Cloud Functions：

## Functions 說明

### 1. `checkAfterTomorrowTraining`
- **排程時間**: 每天 18:00（台灣時間）
- **功能**: 檢查「後天」是否有 `type="training"` 的時段
- **動作**: 如果有 → 發送 FCM 通知「後天有訓練記得登記」

### 2. `adjustTomorrowSlots`
- **排程時間**: 每天 18:00（台灣時間）
- **功能**: 檢查「明天」所有 `type="training"` 的時段
- **動作**: 
  - 如果某個時段 `participantIds.length <= 2`
  - → 把該 slot 的 `type` 改成 `"selfTraining"`
  - → 發送 FCM 通知「明天人數不足改自主訓練」

### 3. `onTrainingSlotChange`
- **觸發時機**: Firestore `trainingSlots/{slotId}` 文件被更新時
- **功能**: 監聽 `participantIds` 的變化
- **動作**: 
  - 如果之前 `type` 是 `"selfTraining"`，且現在 `participantIds.length >= 3`
  - → 把 `type` 改回 `"training"`
  - → 發送 FCM 通知「已恢復訓練」

## Firestore 資料結構

Collection: `trainingSlots`

每個 document 欄位：
```typescript
{
  date: string;              // "YYYY-MM-DD" 格式，例如 "2026-01-21"
  slotId: string;            // "morning" / "afternoon" / "custom_xxx"
  title: string;             // "早上" / "下午" / "自訂"
  startMin: number;          // 開始分鐘數，例如 540 (9:00)
  endMin: number;            // 結束分鐘數，例如 720 (12:00)
  type: string;              // "training" / "selfTraining" / "none"
  coachIds: string[];        // 教練 ID 陣列
  participantIds: string[];  // 參與者 ID 陣列
}
```

## 安裝與部署

### 1. 安裝依賴
```bash
cd functions
npm install
```

### 2. 編譯 TypeScript
```bash
npm run build
```

### 3. 部署 Functions
```bash
# 部署所有 functions
npm run deploy

# 或從專案根目錄
firebase deploy --only functions
```

### 4. 查看日誌
```bash
npm run logs
```

## FCM Topic 設定

Functions 會發送通知到 FCM topic: `trainingNotice`

你的 Flutter app 需要訂閱這個 topic：
```dart
await FirebaseMessaging.instance.subscribeToTopic('trainingNotice');
```

## 注意事項

- 排程時間設定為 `Asia/Taipei` 時區
- 確保 Firestore 有正確的 Security Rules 允許 Functions 讀寫
- 確保 Firebase Messaging 已啟用並設定完成
