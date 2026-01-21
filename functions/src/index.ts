import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// ============================================
// 工具函數
// ============================================

/**
 * 把 Date 轉成 YYYY-MM-DD 字串
 */
function formatDate(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/**
 * 發送 FCM 通知給所有訂閱 trainingNotice topic 的使用者
 */
async function sendNotificationToAll(message: string): Promise<void> {
  const messagePayload: admin.messaging.Message = {
    notification: {
      title: "訓練通知",
      body: message,
    },
    topic: "trainingNotice", // 你的 Flutter app 需要訂閱這個 topic
    android: {
      priority: "high" as const,
    },
    apns: {
      headers: {
        "apns-priority": "10",
      },
    },
  };

  try {
    const response = await admin.messaging().send(messagePayload);
    functions.logger.info("通知發送成功:", response);
  } catch (error) {
    functions.logger.error("通知發送失敗:", error);
    throw error;
  }
}

// ============================================
// Function 1: 每天 18:00 檢查「後天」有沒有訓練
// ============================================

/**
 * 每天 18:00（台灣時間）檢查「後天」是否有 type="training" 的時段
 * 如果有 → 發通知「後天有訓練記得登記」
 */
export const checkAfterTomorrowTraining = functions.scheduler.onSchedule(
  {
    schedule: "0 18 * * *", // UTC 18:00，但 timeZone 設為 Asia/Taipei
    timeZone: "Asia/Taipei",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    functions.logger.info("開始檢查後天的訓練時段...");

    const now = new Date();
    const afterTomorrow = new Date(now);
    afterTomorrow.setDate(now.getDate() + 2);
    const targetDate = formatDate(afterTomorrow);

    functions.logger.info(`目標日期: ${targetDate}`);

    try {
      const snapshot = await db
        .collection("trainingSlots")
        .where("date", "==", targetDate)
        .where("type", "==", "training")
        .limit(1)
        .get();

      if (!snapshot.empty) {
        functions.logger.info(`找到後天(${targetDate})有訓練時段，發送通知`);
        await sendNotificationToAll("後天有訓練記得登記");
      } else {
        functions.logger.info(`後天(${targetDate})沒有訓練時段`);
      }
    } catch (error) {
      functions.logger.error("檢查後天訓練時段失敗:", error);
      throw error;
    }
  }
);

// ============================================
// Function 2: 每天 18:00 檢查「明天」的訓練人數
// ============================================

/**
 * 每天 18:00（台灣時間）檢查「明天」所有 type="training" 的時段
 * 如果某個時段 participantIds.length <= 2
 * → 把該 slot 的 type 改成 "selfTraining"
 * → 發通知「明天人數不足改自主訓練」
 */
export const adjustTomorrowSlots = functions.scheduler.onSchedule(
  {
    schedule: "0 18 * * *", // UTC 18:00，但 timeZone 設為 Asia/Taipei
    timeZone: "Asia/Taipei",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    functions.logger.info("開始檢查明天的訓練時段人數...");

    const now = new Date();
    const tomorrow = new Date(now);
    tomorrow.setDate(now.getDate() + 1);
    const targetDate = formatDate(tomorrow);

    functions.logger.info(`目標日期: ${targetDate}`);

    try {
      const snapshot = await db
        .collection("trainingSlots")
        .where("date", "==", targetDate)
        .where("type", "==", "training")
        .get();

      if (snapshot.empty) {
        functions.logger.info(`明天(${targetDate})沒有訓練時段`);
        return;
      }

      const batch = db.batch();
      let hasAnyChanged = false;
      let changedCount = 0;

      snapshot.forEach((doc) => {
        const data = doc.data();
        const participantIds: string[] = data.participantIds || [];
        const count = participantIds.length;

        functions.logger.info(
          `時段 ${doc.id} (${data.slotId || "unknown"}): ${count} 人`
        );

        if (count <= 2) {
          batch.update(doc.ref, { type: "selfTraining" });
          hasAnyChanged = true;
          changedCount++;
          functions.logger.info(
            `時段 ${doc.id} 人數不足(${count}人)，改為自主訓練`
          );
        }
      });

      if (hasAnyChanged) {
        await batch.commit();
        functions.logger.info(`共 ${changedCount} 個時段改為自主訓練`);
        await sendNotificationToAll("明天人數不足改自主訓練");
      } else {
        functions.logger.info("所有時段人數都足夠，無需調整");
      }
    } catch (error) {
      functions.logger.error("調整明天時段失敗:", error);
      throw error;
    }
  }
);

// ============================================
// Function 3: Firestore trigger - 監聽 participantIds 變化
// ============================================

/**
 * 當 trainingSlots 的某個 doc 被更新時觸發
 * 如果 participantIds 有變化，且：
 * - 之前 type 是 "selfTraining"
 * - 現在 participantIds.length >= 3
 * → 把 type 改回 "training"，並發通知「已恢復訓練」
 */
export const onTrainingSlotChange = functions.firestore
  .document("trainingSlots/{slotId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const slotId = context.params.slotId;

    functions.logger.info(`時段 ${slotId} 被更新`);

    const beforeParticipantIds: string[] = before.participantIds || [];
    const afterParticipantIds: string[] = after.participantIds || [];

    // 判斷 participantIds 有沒有真的變化
    // 比較長度和內容（用 Set 比較更準確，但這裡用簡單的長度+順序比較）
    const beforeSet = new Set(beforeParticipantIds);
    const afterSet = new Set(afterParticipantIds);

    const hasChanged =
      beforeSet.size !== afterSet.size ||
      ![...beforeSet].every((id) => afterSet.has(id));

    if (!hasChanged) {
      functions.logger.info(`時段 ${slotId} 的 participantIds 沒有變化，跳過`);
      return;
    }

    functions.logger.info(
      `時段 ${slotId} participantIds 變化: ${beforeSet.size} -> ${afterSet.size}`
    );

    const beforeType = before.type;
    const afterCount = afterParticipantIds.length;

    // 條件：之前是 selfTraining，現在人數 >= 3
    if (beforeType === "selfTraining" && afterCount >= 3) {
      functions.logger.info(
        `時段 ${slotId} 從自主訓練恢復為訓練 (${afterCount}人)`
      );

      try {
        await change.after.ref.update({ type: "training" });
        await sendNotificationToAll("已恢復訓練");
        functions.logger.info(`時段 ${slotId} 已恢復為訓練`);
      } catch (error) {
        functions.logger.error(`恢復時段 ${slotId} 失敗:`, error);
        throw error;
      }
    } else {
      functions.logger.info(
        `時段 ${slotId} 不符合恢復條件 (之前: ${beforeType}, 現在人數: ${afterCount})`
      );
    }
  });
