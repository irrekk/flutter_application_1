import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/training.dart';

class TrainingService {
  static final CollectionReference<Map<String, dynamic>> _trainingSlotsRef =
      FirebaseFirestore.instance.collection('trainingSlots');

  // 工具函數：將 DateTime 格式化為 YYYY-MM-DD
  static String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${
        d.month.toString().padLeft(2, '0')}-${
        d.day.toString().padLeft(2, '0')}';
  }

  static bool _isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  static Query<Map<String, dynamic>> _queryDay(DateTime date) {
    final targetDateString = _formatDate(date);
    // 只用單一 where(date==...)，避免觸發 composite index 需求
    return _trainingSlotsRef.where('date', isEqualTo: targetDateString);
  }

  static String _docIdFor(DateTime date, String slotId) {
    // 讓同一天同 slot 的 docId 固定，避免重複建立
    final ds = _formatDate(date);
    return '${ds}_$slotId';
  }

  static List<TrainingSlot> _defaultSlotsFor(DateTime date) {
    final weekend = _isWeekend(date);
    final defaultType = weekend ? TrainingType.training : TrainingType.none;
    return <TrainingSlot>[
      TrainingSlot(
        id: 'morning',
        title: '早上',
        startMin: 9 * 60,
        endMin: 12 * 60,
        type: defaultType,
        coachIds: <String>[],
        participantIds: <String>{},
      ),
      TrainingSlot(
        id: 'afternoon',
        title: '下午',
        startMin: 14 * 60,
        endMin: 17 * 60,
        type: defaultType,
        coachIds: <String>[],
        participantIds: <String>{},
      ),
    ];
  }

  static Future<void> _ensureDefaultsExist(DateTime date) async {
    final snapshot = await _queryDay(date).limit(1).get();
    if (snapshot.docs.isNotEmpty) return;

    final ds = _formatDate(date);
    final slots = _defaultSlotsFor(date);

    final batch = FirebaseFirestore.instance.batch();
    for (final s in slots) {
      final docRef = _trainingSlotsRef.doc(_docIdFor(date, s.id));
      batch.set(docRef, {
        ...s.toMap(),
        'date': ds,
      });
    }
    await batch.commit();
  }

  /// 監聽某天的所有訓練時段（即時更新）
  /// - 只針對「目前選取的日期」補預設資料，避免月曆格子造成大量寫入
  static Stream<TrainingDay> dayStream(DateTime date) {
    // 先確保該日的預設時段存在（只寫入一次）
    final ensure = Stream.fromFuture(_ensureDefaultsExist(date));

    return ensure.asyncExpand((_) {
      return _queryDay(date).snapshots().map((snapshot) {
        final slots = snapshot.docs
            .map((doc) => TrainingSlot.fromMap(doc.id, doc.data()))
            .toList()
          ..sort((a, b) => a.startMin.compareTo(b.startMin));
        return TrainingDay(slots: slots, participantIds: <String>{});
      });
    });
  }

  /// 取得某天的所有訓練時段
  static Future<TrainingDay> getDay(DateTime date) async {
    // 若當天沒有任何資料，建立預設兩個時段（週末=訓練、平日=none）
    await _ensureDefaultsExist(date);

    final snapshot = await _queryDay(date).get();
    final slots = snapshot.docs
        .map((doc) => TrainingSlot.fromMap(doc.id, doc.data()))
        .toList();
    slots.sort((a, b) => a.startMin.compareTo(b.startMin));
    return TrainingDay(slots: slots, participantIds: <String>{});
  }

  /// 取得某時段（找不到回 null）
  static Future<TrainingSlot?> getSlot(DateTime date, String slotId) async {
    // 先嘗試用固定 docId 直接取（morning/afternoon 都適用）
    final docRef = _trainingSlotsRef.doc(_docIdFor(date, slotId));
    final snap = await docRef.get();
    if (snap.exists && snap.data() != null) {
      return TrainingSlot.fromMap(snap.id, snap.data()!);
    }

    // 若是 custom slot，或舊資料 docId 不符合規則，就退回用 date 掃描
    final snapshot = await _queryDay(date).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final id = (data['id'] as String?) ?? doc.id;
      if (id == slotId) return TrainingSlot.fromMap(doc.id, data);
    }
    return null;
  }

  /// 設定時段類型
  static Future<void> setSlotType({
    required DateTime date,
    required String slotId,
    required TrainingType type,
  }) async {
    await _ensureDefaultsExist(date);

    final docRef = _trainingSlotsRef.doc(_docIdFor(date, slotId));
    final snap = await docRef.get();
    if (!snap.exists) {
      // fallback：可能是 custom slot 或舊資料
      final found = await getSlot(date, slotId);
      if (found == null) return;
    }

    final updates = <String, dynamic>{'type': type.name};

    // 非訓練就不需要教練
    if (type != TrainingType.training) {
      updates['coachIds'] = <String>[];
    }

    // none 的話也不該保留參加名單（避免球員登記到未開放時段）
    if (type == TrainingType.none) {
      updates['participantIds'] = <String>[];
    }
    await docRef.update(updates);
  }

  /// 設定時段教練（只有 type=training 時才會保留）
  static Future<void> setSlotCoaches({
    required DateTime date,
    required String slotId,
    required List<String> coachIds,
  }) async {
    await _ensureDefaultsExist(date);

    final docRef = _trainingSlotsRef.doc(_docIdFor(date, slotId));
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return;
    final currentSlot = TrainingSlot.fromMap(snap.id, snap.data()!);

    if (currentSlot.type != TrainingType.training) {
      await docRef.update({'coachIds': <String>[]});
      return;
    }
    await docRef.update({'coachIds': coachIds});
  }

  /// ✅ 球員：切換「某時段」參加（回傳：切換後是否為已參加）
  /// 只能讓 training / selfTraining 登記；none 不允許
  static Future<bool> toggleSlotParticipant({
    required DateTime date,
    required String slotId,
    required String playerId,
  }) async {
    await _ensureDefaultsExist(date);

    final docRef = _trainingSlotsRef.doc(_docIdFor(date, slotId));
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) return false;
    final currentSlot = TrainingSlot.fromMap(snap.id, snap.data()!);

    if (currentSlot.type == TrainingType.none) {
      return currentSlot.participantIds.contains(playerId);
    }

    if (currentSlot.participantIds.contains(playerId)) {
      await docRef.update({
        'participantIds': FieldValue.arrayRemove([playerId]),
      });
      return false;
    } else {
      await docRef.update({
        'participantIds': FieldValue.arrayUnion([playerId]),
      });
      return true;
    }
  }

  /// ✅ 新增自訂時段
  static Future<void> addCustomSlot({
    required DateTime date,
    required String title,
    required int startMin,
    required int endMin,
  }) async {
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    final newSlot = TrainingSlot(
      id: id,
      title: title.trim().isEmpty ? '自訂' : title.trim(),
      startMin: startMin,
      endMin: endMin,
      type: TrainingType.training,
      coachIds: <String>[],
      participantIds: <String>{},
    );
    // 用固定 docId，方便未來查找/避免重複
    final docRef = _trainingSlotsRef.doc(_docIdFor(date, id));
    await docRef.set({
      ...newSlot.toMap(),
      'date': _formatDate(date),
    });
  }

  /// ✅ 刪除時段
  static Future<void> removeSlot({
    required DateTime date,
    required String slotId,
  }) async {
    final docRef = _trainingSlotsRef.doc(_docIdFor(date, slotId));
    final snap = await docRef.get();
    if (snap.exists) {
      await docRef.delete();
      return;
    }

    // fallback：舊資料或 docId 不符合
    final snapshot = await _queryDay(date).get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final id = (data['id'] as String?) ?? doc.id;
      if (id == slotId) {
        await doc.reference.delete();
        return;
      }
    }
  }

  /// （你原本就有的）整天層級球員參加
  /// 此方法已不再使用，因為 participantIds 已拆分到 TrainingSlot 層級。
  @Deprecated('Use toggleSlotParticipant instead.')
  static Future<void> toggleParticipant({
    required DateTime date,
    required String playerId,
  }) async {
    // Implementation no longer needed, keeping for compilation compatibility for now.
    // In a real app, this would be removed completely after UI refactor.
  }

  /// 月曆小點：只要當天任一 slot 不是 none 就有點
  static Future<bool> hasAnyPlan(DateTime date) async {
    // 注意：這個方法會被月曆格子大量呼叫，不能在這裡自動建立預設資料（會造成大量寫入）
    final snapshot = await _queryDay(date).get();
    if (snapshot.docs.isEmpty) {
      // 沒任何資料時，沿用「週末預設有訓練」的視覺提示，但不寫入 Firestore
      return _isWeekend(date);
    }

    for (final doc in snapshot.docs) {
      final type = (doc.data()['type'] as String?)?.toLowerCase() ?? 'none';
      if (type != 'none') return true;
    }
    return false;
  }
}
