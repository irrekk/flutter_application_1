import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String title;
  final String body;
  final String createdBy; // user id
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdBy,
    required this.createdAt,
  });

  factory Announcement.fromMap(String id, Map<String, dynamic> data) {
    final ts = data['createdAt'];
    DateTime createdAt;
    if (ts is Timestamp) {
      createdAt = ts.toDate();
    } else {
      createdAt = DateTime.fromMillisecondsSinceEpoch(0);
    }

    return Announcement(
      id: id,
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMapForCreate() {
    return <String, dynamic>{
      'title': title,
      'body': body,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

