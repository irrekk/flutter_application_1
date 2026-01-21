enum TrainingType { training, selfTraining, none }

TrainingType _trainingTypeFromString(String? raw) {
  final v = (raw ?? '').trim().toLowerCase();
  switch (v) {
    case 'training':
      return TrainingType.training;
    // Firestore 我們存的是 selfTraining，toLowerCase 後會變成 selftraining
    case 'selftraining':
      return TrainingType.selfTraining;
    default:
      return TrainingType.none;
  }
}

String _trainingTypeToString(TrainingType t) {
  switch (t) {
    case TrainingType.training:
      return 'training';
    case TrainingType.selfTraining:
      return 'selfTraining';
    case TrainingType.none:
      return 'none';
  }
}

class TrainingSlot {
  /// morning / afternoon / custom_xxx
  String id;

  /// 早上/下午/自訂
  String title;

  /// 09:00 => 540
  int startMin;

  /// 12:00 => 720
  int endMin;

  TrainingType type;

  /// 只有 type==training 才需要（你原本規則）
  List<String> coachIds;

  /// 每個時段自己的參加球員
  Set<String> participantIds;

  TrainingSlot({
    required this.id,
    required this.title,
    required this.startMin,
    required this.endMin,
    required this.type,
    required this.coachIds,
    Set<String>? participantIds,
  }) : participantIds = participantIds ?? <String>{};

  /// 從 Firestore 的 Map 建立 TrainingSlot
  /// - docId：Firestore 的文件 ID（不一定等於 slotId）
  /// - data['id']：我們存的 slotId（如果存在，優先）
  factory TrainingSlot.fromMap(String docId, Map<String, dynamic> data) {
    final slotId = (data['id'] as String?) ?? docId;
    return TrainingSlot(
      id: slotId,
      title: (data['title'] as String?) ?? '',
      startMin: (data['startMin'] as int?) ?? 0,
      endMin: (data['endMin'] as int?) ?? 0,
      type: _trainingTypeFromString(data['type'] as String?),
      coachIds: (data['coachIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
      participantIds: (data['participantIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          <String>{},
    );
  }

  /// 轉換成 Map 存入 Firestore
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'startMin': startMin,
      'endMin': endMin,
      'type': _trainingTypeToString(type),
      'coachIds': coachIds,
      'participantIds': participantIds.toList(),
    };
  }
}

class TrainingDay {
  List<TrainingSlot> slots;

  /// 保留（相容用）：整天層級參加球員（你原本就有）
  /// 但目前畫面顯示會用 slot.participantIds
  Set<String> participantIds;

  TrainingDay({
    required this.slots,
    required this.participantIds,
  });
}
