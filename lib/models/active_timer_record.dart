import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveTimerRecord {
  final String recordId;
  final String userId;
  final String? workspaceId;
  final String deviceId;
  final String category;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final DateTime updatedAt;
  final String? note;

  const ActiveTimerRecord({
    required this.recordId,
    required this.userId,
    required this.deviceId,
    required this.category,
    required this.status,
    required this.startedAt,
    required this.updatedAt,
    this.workspaceId,
    this.endedAt,
    this.durationSeconds = 0,
    this.note,
  });

  bool get isRunning => status == 'running';

  ActiveTimerRecord copyWith({
    String? recordId,
    String? userId,
    String? workspaceId,
    String? deviceId,
    String? category,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    DateTime? updatedAt,
    String? note,
  }) {
    return ActiveTimerRecord(
      recordId: recordId ?? this.recordId,
      userId: userId ?? this.userId,
      workspaceId: workspaceId ?? this.workspaceId,
      deviceId: deviceId ?? this.deviceId,
      category: category ?? this.category,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'userId': userId,
        'workspaceId': workspaceId,
        'deviceId': deviceId,
        'category': category,
        'status': status,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'note': note,
      };

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate().toUtc();
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw).toUtc();
    if (raw is String) {
      try {
        return DateTime.parse(raw).toUtc();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  factory ActiveTimerRecord.fromJson(Map<String, dynamic> json) {
    final startedAt = _parseDate(json['startedAt']) ?? DateTime.now().toUtc();
    return ActiveTimerRecord(
      recordId: json['recordId']?.toString() ?? json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      workspaceId: json['workspaceId']?.toString(),
      deviceId: json['deviceId']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Focus',
      status: json['status']?.toString() ?? 'running',
      startedAt: startedAt,
      endedAt: _parseDate(json['endedAt']),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      updatedAt: _parseDate(json['updatedAt']) ?? startedAt,
      note: json['note']?.toString(),
    );
  }
}
