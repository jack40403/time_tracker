import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/goal.dart';
import '../services/goal_stats_service.dart';
import '../services/notification_coordinator.dart';
import '../services/goal_progress_service.dart';
import 'session_provider.dart';
import 'category_provider.dart';
import 'firestore_provider.dart';
import 'session_provider.dart';
import 'storage_provider.dart';
import 'timer_provider.dart';

class TaskGoalNotifier extends Notifier<List<Goal>> {
  static const _storageKey = 'goals_task_v4';
  static const _tombstoneKey = 'goals_task_tombstones';

  int _lastMutationTime = 0;
  Set<String> _tombstones = {};

  @override
  List<Goal> build() {
    final storage = ref.watch(storageServiceProvider);
    final tombstoneJson = storage.prefs.getString(_tombstoneKey);
    if (tombstoneJson != null) {
      try {
        _tombstones = Set<String>.from(jsonDecode(tombstoneJson) as List);
      } catch (_) {
        _tombstones = {};
      }
    }

    final firestore = ref.watch(firestoreServiceProvider);
    if (firestore != null) {
      ref.listen(cloudTaskGoalsProvider, (previous, next) {
        if (next.hasValue) {
          final remote = next.value!.map((e) => Goal.fromJson(e)).toList();
          _syncWithCloud(remote);
        }
      });

      Future.microtask(() {
        final current = ref.read(cloudTaskGoalsProvider);
        if (current.hasValue && current.value!.isNotEmpty) {
          final remote = current.value!.map((e) => Goal.fromJson(e)).toList();
          _syncWithCloud(remote);
        }
      });
    }

    return _load();
  }

  List<Goal> _load() {
    final prefs = ref.read(storageServiceProvider).prefs;
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return [];

    try {
      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      return decoded
          .map((item) {
            try {
              return Goal.fromJson(item as Map<String, dynamic>);
            } catch (err) {
              debugPrint('TaskGoalNotifier: Skipping corrupted goal: $err');
              return null;
            }
          })
          .whereType<Goal>()
          .toList();
    } catch (err) {
      debugPrint('TaskGoalNotifier: Error decoding storage: $err');
      return [];
    }
  }

  Future<void> _saveLocal() async {
    final prefs = ref.read(storageServiceProvider).prefs;
    final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  Future<void> _saveSingleLocal(Goal goal, {bool isDelete = false}) async {
    _lastMutationTime = DateTime.now().millisecondsSinceEpoch;
    await _saveLocal();

    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;

    if (isDelete) {
      await firestore.deleteGoalById(goal.id, isTaskGoal: true);
    } else {
      await firestore.saveGoal(goal, isTaskGoal: true);
    }
  }

  void _syncWithCloud(List<Goal> remoteGoals, {bool force = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && (now - _lastMutationTime) < 3000) return;

    final filteredRemote = remoteGoals.where((goal) => !_tombstones.contains(goal.id)).toList();
    final remoteIds = remoteGoals.map((goal) => goal.id).toSet();
    final removedTombstones = _tombstones.where((id) => !remoteIds.contains(id)).toList();
    if (removedTombstones.isNotEmpty) {
      _tombstones.removeAll(removedTombstones);
      ref.read(storageServiceProvider).prefs.setString(_tombstoneKey, jsonEncode(_tombstones.toList()));
    }

    if (state.isEmpty && filteredRemote.isNotEmpty) {
      state = filteredRemote;
      _saveLocal();
      return;
    }

    final mergedMap = {for (final goal in state) goal.id: goal};
    var changed = false;

    for (final remote in filteredRemote) {
      final local = mergedMap[remote.id];
      if (local == null) {
        mergedMap[remote.id] = remote;
        changed = true;
        continue;
      }

      if (remote.updatedAt.isAfter(local.updatedAt)) {
        // Firestore transactions are authoritative, including valid decrements.
        mergedMap[remote.id] = remote;
        changed = true;
      }
    }

    if (changed) {
      state = mergedMap.values.toList();
      _saveLocal();
    }
  }

  String addGoal(
    String category,
    int target,
    GoalPeriod period, {
    String? title,
    GoalType type = GoalType.task,
    DateTime? startDate,
    String? reminderTime,
    bool isReminderEnabled = false,
  }) {
    final now = DateTime.now();
    final newGoal = Goal(
      id: const Uuid().v4(),
      title: title ?? category,
      category: category,
      targetSeconds: target,
      period: period,
      type: type,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      startDate: startDate ?? now,
      reminderTime: reminderTime,
      isReminderEnabled: isReminderEnabled,
      completionHistory: {},
    );
    state = [...state, newGoal];
    _saveSingleLocal(newGoal);
    unawaited(NotificationCoordinator.instance.requestReminderSchedule(newGoal));
    return newGoal.id;
  }

  void addRawGoal(Goal goal) {
    if (state.any((existing) => existing.id == goal.id)) return;
    state = [...state, goal];
    _saveLocal();
  }

  void updateGoal(Goal updated) {
    final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
    state = state.map((goal) => goal.id == withTimestamp.id ? withTimestamp : goal).toList();
    _saveSingleLocal(withTimestamp);
    unawaited(NotificationCoordinator.instance.requestReminderSchedule(withTimestamp));
  }

  void forceMergeFromCloud(List<Goal> remoteGoals) {
    _lastMutationTime = 0;
    _syncWithCloud(remoteGoals, force: true);
  }

  Future<void> forceSyncFromCloud() async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    try {
      final data = await firestore.fetchTaskGoalsOnce();
      if (data.isNotEmpty) {
        forceMergeFromCloud(data.map((e) => Goal.fromJson(e)).toList());
      }
    } catch (err) {
      debugPrint('TaskGoalNotifier: Force sync failed: $err');
    }
  }

  Future<void> reloadFromStorage() async {
    await ref.read(storageServiceProvider).prefs.reload();
    state = _load();
  }

  void deleteGoal(String id) {
    final goal = state.firstWhere(
      (goal) => goal.id == id,
      orElse: () => Goal(
        id: id,
        title: '',
        category: '',
        targetSeconds: 0,
        period: GoalPeriod.daily,
        createdAt: DateTime.now(),
        startDate: DateTime.now(),
      ),
    );
    _addTombstones([id]);
    state = state.where((goal) => goal.id != id).toList();
    _saveSingleLocal(goal, isDelete: true);
    unawaited(NotificationCoordinator.instance.requestReminderCancel(id));
  }

  Future<void> deleteGoalsByCategory(String category) async {
    final targets = state.where((goal) => goal.category == category).toList();
    _addTombstones(targets.map((goal) => goal.id).toList());
    state = state.where((goal) => goal.category != category).toList();

    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      for (final goal in targets) {
        await firestore.deleteGoalById(goal.id, isTaskGoal: true);
      }
    }
    await _saveLocal();
  }

  void _addTombstones(List<String> ids) {
    if (ids.isEmpty) return;
    _tombstones.addAll(ids);
    ref.read(storageServiceProvider).prefs.setString(_tombstoneKey, jsonEncode(_tombstones.toList()));
  }

  void resetState() {
    state = [];
    _tombstones.clear();
  }

  Future<void> restoreFromBackup(List<Goal> goals) async {
    state = goals;
    await _saveLocal();
    _tombstones.clear();
    ref.read(storageServiceProvider).prefs.remove(_tombstoneKey);
  }

  Future<void> saveAll(List<Goal> goals) async {
    state = goals;
    await _saveLocal();
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      for (final goal in goals) {
        await firestore.saveGoal(goal, isTaskGoal: true);
      }
    }
  }

  Future<void> syncNow() async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    for (final goal in state) {
      await firestore.saveGoal(goal, isTaskGoal: true);
    }
  }

  void renameCategory(String oldCat, String newCat) {
    final updated = state.map((goal) {
      if (goal.category == oldCat) {
        return goal.copyWith(category: newCat, updatedAt: DateTime.now());
      }
      return goal;
    }).toList();
    state = updated;

    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      for (final goal in updated.where((goal) => goal.category == newCat)) {
        firestore.saveGoal(goal, isTaskGoal: true);
      }
    }
    _saveLocal();
  }

  Future<void> setManualValue(String id, DateTime date, int val) async {
    final dateKey = _formatDate(date);
    Goal? updatedGoal;
    state = state.map((goal) {
      if (goal.id != id) return goal;
      final history = Map<String, int>.from(goal.completionHistory);
      history[dateKey] = val < 0 ? 0 : val;
      updatedGoal = goal.copyWith(completionHistory: history, updatedAt: DateTime.now());
      return updatedGoal!;
    }).toList();
    if (updatedGoal != null) await _saveSingleLocal(updatedGoal!);
  }

  void toggleManualCompletion(String id, DateTime date) {
    final dateKey = _formatDate(date);
    Goal? updatedGoal;
    state = state.map((goal) {
      if (goal.id != id) return goal;
      final history = Map<String, int>.from(goal.completionHistory);
      history[dateKey] = (history[dateKey] ?? 0) > 0 ? 0 : 1;
      updatedGoal = goal.copyWith(completionHistory: history, updatedAt: DateTime.now());
      return updatedGoal!;
    }).toList();
    if (updatedGoal != null) _saveSingleLocal(updatedGoal!);
  }

  double getProgress(Goal goal) {
    return GoalProgressService.buildProgress(
      goal: goal,
      now: DateTime.now(),
      sessions: ref.read(sessionsProvider),
    ).progress;
  }

  String getRemainingText(Goal goal) {
    return GoalProgressService.buildProgress(
      goal: goal,
      now: DateTime.now(),
      sessions: ref.read(sessionsProvider),
    ).remainingText;
  }

  Map<String, String> getRecords(Goal goal) {
    final timerState = ref.read(timerProvider);
    final stats = GoalStatsService.buildStats(
      goal,
      now: DateTime.now(),
      sessions: ref.read(sessionsProvider),
      currentRunningSeconds: timerState.isRunning && timerState.category == goal.category
          ? timerState.currentElapsed
          : 0,
      isTimerRunning: timerState.isRunning,
      runningCategory: timerState.category,
    );
    return stats.toLegacyMap();
  }

  int _currentPeriodValue(Goal goal, DateTime now) {
    final range = _periodRange(goal.period, now);
    var total = 0;
    for (final entry in goal.completionHistory.entries) {
      final date = DateTime.tryParse(entry.key.replaceAll('/', '-'));
      if (date == null) continue;
      if (date.isBefore(range.start)) continue;
      if (!date.isBefore(range.endExclusive)) continue;
      if (date.isBefore(goal.startDate)) continue;
      total += entry.value;
    }
    if (goal.type == GoalType.binary) return total > 0 ? 1 : 0;
    return total;
  }

  _DateRange _periodRange(GoalPeriod period, DateTime date) {
    final local = date.toLocal();
    switch (period) {
      case GoalPeriod.daily:
        final start = DateTime(local.year, local.month, local.day);
        return _DateRange(start, start.add(const Duration(days: 1)));
      case GoalPeriod.weekly:
        final startOfDay = DateTime(local.year, local.month, local.day);
        final start = startOfDay.subtract(Duration(days: local.weekday - 1));
        return _DateRange(start, start.add(const Duration(days: 7)));
      case GoalPeriod.monthly:
        final start = DateTime(local.year, local.month);
        return _DateRange(start, DateTime(local.year, local.month + 1));
      case GoalPeriod.yearly:
        final start = DateTime(local.year);
        return _DateRange(start, DateTime(local.year + 1));
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _DateRange {
  final DateTime start;
  final DateTime endExclusive;

  const _DateRange(this.start, this.endExclusive);
}

final taskGoalProvider = NotifierProvider<TaskGoalNotifier, List<Goal>>(
  () => TaskGoalNotifier(),
);

final visibleTaskGoalsProvider = Provider<List<Goal>>((ref) {
  final all = ref.watch(taskGoalProvider);
  final hiddenGoals = ref.watch(goalsHiddenCategoriesProvider);
  final hiddenGlobal = ref.watch(hiddenCategoriesProvider);
  return all.where((goal) {
    return goal.isActive &&
        !hiddenGoals.contains(goal.category) &&
        !hiddenGlobal.contains(goal.category);
  }).toList();
});
