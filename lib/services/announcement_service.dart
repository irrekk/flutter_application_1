import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/announcement.dart';

class AnnouncementService {
  static final CollectionReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('announcements');

  static Stream<List<Announcement>> streamLatest({int limit = 20}) {
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => Announcement.fromMap(d.id, d.data())).toList();
    });
  }

  static Future<void> create({
    required String title,
    required String body,
    required String createdBy,
  }) async {
    final t = title.trim();
    final b = body.trim();
    if (t.isEmpty || b.isEmpty) return;

    final announcement = Announcement(
      id: '',
      title: t,
      body: b,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await _ref.add(announcement.toMapForCreate());
  }

  static Future<void> delete(String id) async {
    if (id.trim().isEmpty) return;
    await _ref.doc(id).delete();
  }
}

