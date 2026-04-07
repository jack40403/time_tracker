import 'package:flutter/foundation.dart';

enum GoalPeriod { daily, weekly, monthly, yearly }

enum GoalType { time, task, binary }

class Goal {
  final String id;
  final String title; // Custom goal name
  final String category;
  final int targetSeconds; 
  final GoalPeriod period;
  final GoalType type;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime startDate; 
  final Map<String, int> completionHistory; 

  final int lastMilestone; 

  Goal({
    required this.id,
    required this.title,
    required this.category,
    required this.targetSeconds,
    required this.period,
    this.type = GoalType.time,
    this.isActive = true,
    required this.createdAt,
    DateTime? updatedAt,
    required this.startDate,
    this.completionHistory = const {},
    this.lastMilestone = 0,
  }) : updatedAt = updatedAt ?? createdAt;

  Goal copyWith({
    String? id,
    String? title,
    String? category,
    int? targetSeconds,
    GoalPeriod? period,
    GoalType? type,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startDate,
    Map<String, int>? completionHistory,
    int? lastMilestone,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      period: period ?? this.period,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startDate: startDate ?? this.startDate,
      completionHistory: completionHistory ?? this.completionHistory,
      lastMilestone: lastMilestone ?? this.lastMilestone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'targetSeconds': targetSeconds,
      'period': period.name,
      'type': type.name,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'startDate': startDate.toIso8601String(),
      'completionHistory': Map<String, int>.from(completionHistory),
      'lastMilestone': lastMilestone,
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    String typeStr = json['type'] as String? ?? 'time';
    GoalType gType = GoalType.time;
    if (typeStr == 'task') gType = GoalType.task;
    else if (typeStr == 'binary') gType = GoalType.binary;

    String periodStr = json['period'] as String? ?? 'daily';
    GoalPeriod gPeriod = GoalPeriod.daily;
    if (periodStr == 'weekly') gPeriod = GoalPeriod.weekly;
    else if (periodStr == 'monthly') gPeriod = GoalPeriod.monthly;
    else if (periodStr == 'yearly') gPeriod = GoalPeriod.yearly;

    final createdAtStr = json['createdAt'] as String? ?? DateTime.now().toIso8601String();
    final startDateStr = json['startDate'] as String? ?? createdAtStr;
    final catName = json['category'] as String? ?? '未分類';

    return Goal(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? catName,
      category: catName,
      targetSeconds: (json['targetSeconds'] as num?)?.toInt() ?? 0,
      period: gPeriod,
      type: gType,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(createdAtStr),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? createdAtStr),
      startDate: DateTime.parse(startDateStr),
      completionHistory: (json['completionHistory'] as Map<String, dynamic>?)?.map((k, v) {
        // 自動正規化日期 Key：將所有 '/' 轉換為 '-' 確保相容性
        final normalizedKey = k.replaceAll('/', '-');
        return MapEntry(normalizedKey, (v as num?)?.toInt() ?? 0);
      }) ?? {},
      lastMilestone: (json['lastMilestone'] as num?)?.toInt() ?? 0,
    );
  }
}
