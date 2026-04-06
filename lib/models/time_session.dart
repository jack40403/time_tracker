import 'package:flutter/foundation.dart';

class TimeSession {
  final String category;
  final int durationSeconds;
  final DateTime date;

  TimeSession({
    required this.category,
    required this.durationSeconds,
    required this.date,
  });

  TimeSession copyWith({
    String? category,
    int? durationSeconds,
    DateTime? date,
  }) {
    return TimeSession(
      category: category ?? this.category,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'durationSeconds': durationSeconds,
      'date': date.toUtc().toIso8601String(),
    };
  }

  factory TimeSession.fromJson(Map<String, dynamic> json) {
    return TimeSession(
      category: json['category'] as String,
      durationSeconds: json['durationSeconds'] as int,
      date: DateTime.parse(json['date'] as String).toLocal(),
    );
  }
}
