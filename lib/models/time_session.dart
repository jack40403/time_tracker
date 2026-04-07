import 'package:uuid/uuid.dart';

class TimeSession {
  final String id;
  final String category;
  final int durationSeconds;
  final DateTime date;
  final String? note; // 用於「日誌」的心得或詳細描述

  TimeSession({
    String? id,
    required this.category,
    required this.durationSeconds,
    required this.date,
    this.note,
  }) : id = id ?? const Uuid().v4();

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
    return TimeSession(
      id: json['id'] as String?,
      category: json['category'] as String,
      durationSeconds: json['durationSeconds'] as int,
      date: DateTime.parse(json['date'] as String).toLocal(),
      note: json['note'] as String?,
    );
  }
}
