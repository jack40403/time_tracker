import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TimeSession {
  final String id;
  final String category;
  final int durationSeconds;
  final DateTime date;
  final String? note; // ?冽?隤?敹??底蝝唳?餈?
  TimeSession({
    String? id,
    required this.category,
    required this.durationSeconds,
    required this.date,
    this.note,
  }) : id = id ?? generateId(category, date);

  static String toBaseName(String name) {
    // 移除 Emoji 或特殊符號、數字、空白
    // fix emoji pattern regex comment
    final emojiPattern = RegExp(
      r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}]',
      unicode: true,
    );
    return name.replaceAll(emojiPattern, '').trim();
  }

  static String generateId(String category, DateTime date) {
    final base = toBaseName(category);
    final fixedTime = (date.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000;
    return '${base}_$fixedTime';
  }

  TimeSession copyWith({
    String? id,
    String? category,
    int? durationSeconds,
    DateTime? date,
    String? note,
  }) {
    return TimeSession(
      id: id ?? this.id,
      category: category ?? this.category,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      date: date ?? this.date,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'durationSeconds': durationSeconds,
      'date': date.toUtc().toIso8601String(),
      'note': note,
    };
  }

  factory TimeSession.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    DateTime parsedDate;
    
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate().toLocal();
    } else if (rawDate is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawDate).toLocal();
    } else if (rawDate is String) {
      parsedDate = DateTime.parse(rawDate).toLocal();
    } else {
      parsedDate = DateTime.now();
    }

    final rawDuration = json['durationSeconds'] ?? 0;
    final int duration = rawDuration is num ? rawDuration.toInt() : 0;

    return TimeSession(
      id: json['id'] as String?,
      category: json['category']?.toString() ?? '未分類',
      durationSeconds: duration,
      date: parsedDate,
      note: json['note'] as String?,
    );
  }
}
