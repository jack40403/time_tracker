import 'package:flutter/foundation.dart';

enum GoalPeriod { daily, weekly, monthly, yearly }

enum GoalType { time, task, binary }

class Goal {
  final String id;
  final String category;
  final int targetSeconds; // For Time goals: seconds. For Count goals: target count. For Binary: 1.
  final GoalPeriod period;
  final GoalType type;
  final bool isActive;
  final DateTime createdAt;
  final DateTime startDate; // User-defined start date
  final Map<String, int> completionHistory; // 'yyyy-MM-dd' -> count/units

  final int lastMilestone; // 0, 25, 50, 75, 100

  Goal({
    required this.id,
    required this.category,
    required this.targetSeconds,
    required this.period,
    this.type = GoalType.time,
    this.isActive = true,
    required this.createdAt,
    required this.startDate,
    this.completionHistory = const {},
    this.lastMilestone = 0,
  });

  Goal copyWith({
    String? id,
    String? category,
    int? targetSeconds,
    GoalPeriod? period,
    GoalType? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? startDate,
    Map<String, int>? completionHistory,
    int? lastMilestone,
  }) {
    return Goal(
      id: id ?? this.id,
      category: category ?? this.category,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      period: period ?? this.period,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      completionHistory: completionHistory ?? this.completionHistory,
      lastMilestone: lastMilestone ?? this.lastMilestone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'targetSeconds': targetSeconds,
      'period': period.name,
      'type': type.name,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'completionHistory': Map<String, int>.from(completionHistory),
      'lastMilestone': lastMilestone,
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    String typeStr = json['type'] as String? ?? 'time';
    // Backwards compatibility: existing 'task' stays 'task' (count-based)
    GoalType gType = GoalType.time;
    if (typeStr == 'task') gType = GoalType.task;
    else if (typeStr == 'binary') gType = GoalType.binary;

    return Goal(
      id: json['id'] as String,
      category: json['category'] as String,
      targetSeconds: json['targetSeconds'] as int,
      period: GoalPeriod.values.byName(json['period'] as String),
      type: gType,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startDate: DateTime.parse(json['startDate'] as String? ?? json['createdAt'] as String),
      completionHistory: (json['completionHistory'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v is bool ? (v ? 1 : 0) : (v as int? ?? 0))) ?? {},
      lastMilestone: json['lastMilestone'] as int? ?? 0,
    );
  }
}
