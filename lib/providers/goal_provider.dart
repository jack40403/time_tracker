import 'dart:convert';
import 'package:flutter/foundation.dart'; // For mapEquals
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/goal.dart';
import '../models/time_session.dart';
import 'storage_provider.dart';
import 'auth_provider.dart';
import 'firestore_provider.dart';
import 'session_provider.dart';
import 'category_provider.dart';

class GoalNotifier extends Notifier<List<Goal>> {
  static const _storageKey = 'time_tracker_goals';
  
  // Anti-Race condition: Store last local mutation timestamp
  int _lastMutationTime = 0;

  @override
  List<Goal> build() {
    _loadLocal();

    // Listen to sessions to update milestones and auto-check days
    ref.listen(sessionsProvider, (_, __) => _checkMilestones());

    // Watch auth state to trigger sync on login/logout
    final firestore = ref.watch(firestoreServiceProvider);

    // Initial sync trigger
    Future.microtask(() => _checkMilestones());

    if (firestore != null) {
      // 1. Trigger an immediate one-time fetch to populate state faster than the stream
      firestore.watchGoals().first.then((cloudData) {
        final List<Goal> remote = cloudData.map((e) => Goal.fromJson(e)).toList();
        if (remote.isNotEmpty && state.isEmpty) {
           state = remote;
           _saveLocal(syncToCloud: false);
        }
      }).catchError((e) => debugPrint('GoalProvider: Initial fetch error: $e'));

      // 2. Listen to cloud goals for real-time updates
      bool hasInitiallySynced = false;
      ref.listen(cloudGoalsProvider, (previous, next) {
        if (next.hasValue) {
          final cloudGoals = next.value!;
          final List<Goal> remote = cloudGoals.map((e) => Goal.fromJson(e)).toList();
          
          // Debounce/Mute sync if we just performed a local mutation (3 seconds grace period)
          final now = DateTime.now().millisecondsSinceEpoch;
          final isRecentlyMutated = (now - _lastMutationTime) < 3000;
          
          if (isRecentlyMutated) {
            debugPrint('GoalProvider: Skipping cloud sync due to recent local mutation');
            return;
          }

          if (remote.isNotEmpty) {
            // Cloud has data - update local if different
            if (remote.toString() != state.toString()) {
              state = remote;
              _saveLocal(syncToCloud: false);
            }
            hasInitiallySynced = true;
          } else {
            // Cloud is EMPTY
            if (!hasInitiallySynced && state.isNotEmpty) {
              // FIRST BOOTSTRAP: Cloud is empty but local has data - push to cloud
              _saveLocal();
              hasInitiallySynced = true;
            } else if (state.isNotEmpty) {
              // SUBSEQUENT SYNC: Cloud is empty, meaning goals were deleted elsewhere/just now
              // Synchronize local state to empty
              state = [];
              _saveLocal(syncToCloud: false);
            }
          }
        }
      });
    }

    return [];
  }

  Future<void> _loadLocal() async {
    final prefs = ref.read(storageServiceProvider).prefs;
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        state = decoded.map((e) => Goal.fromJson(e)).toList();
      } catch (e) {
        state = [];
      }
    }
  }

  Future<void> _saveLocal({bool syncToCloud = true}) async {
    final prefs = ref.read(storageServiceProvider).prefs;
    final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
    
    // Sync to Firestore if logged in and not coming from cloud update
    if (syncToCloud) {
      _lastMutationTime = DateTime.now().millisecondsSinceEpoch;
      final firestore = ref.read(firestoreServiceProvider);
      if (firestore != null) {
        await firestore.saveGoals(state);
      }
    }
  }

  void addGoal(String category, int targetSeconds, GoalPeriod period, {GoalType type = GoalType.time, DateTime? startDate}) {
    final initialGoal = Goal(
      id: const Uuid().v4(),
      category: category,
      targetSeconds: targetSeconds,
      period: period,
      type: type,
      createdAt: DateTime.now(),
      startDate: startDate ?? DateTime.now(),
      completionHistory: {},
      lastMilestone: 0,
    );
    
    // Backfill history based on existing sessions
    final newGoal = _backfillHistory(initialGoal);
    
    state = [...state, newGoal];
    _saveLocal();
  }

  void deleteGoal(String id) {
    state = state.where((g) => g.id != id).toList();
    _saveLocal();
  }

  void deleteGoalCompletely(Goal goal) {
    // 1. Delete the goal itself
    state = state.where((g) => g.id != goal.id).toList();
    _saveLocal();

    // 2. Wipe the category and all session history
    ref.read(categoryColorProvider.notifier).hardDeleteCategory(goal.category);
    
    debugPrint('GoalProvider: Performed total wipe for ${goal.category}');
  }

  void restoreGoal(Goal goal) {
    if (state.any((g) => g.id == goal.id)) return; // Prevent double restore
    state = [...state, goal];
    _saveLocal();
  }

  void toggleGoalActive(String id) {
    state = state.map((g) => g.id == id ? g.copyWith(isActive: !g.isActive) : g).toList();
    _saveLocal();
  }

  Future<void> setManualValue(String id, DateTime date, int value) async {
    final dateKey = _formatDate(date);
    state = state.map((g) {
      if (g.id == id) {
        final history = Map<String, int>.from(g.completionHistory);
        history[dateKey] = value;
        return g.copyWith(completionHistory: history);
      }
      return g;
    }).toList();
    await _saveLocal();
  }

  Future<void> toggleManualCompletion(String id, DateTime date) async {
    final dateKey = _formatDate(date);
    state = state.map((g) {
      if (g.id == id && g.type == GoalType.task) {
        final history = Map<String, int>.from(g.completionHistory);
        final current = history[dateKey] ?? 0;
        history[dateKey] = current > 0 ? 0 : 1;
        return g.copyWith(completionHistory: history);
      }
      return g;
    }).toList();
    await _saveLocal();
  }

  void updateGoal(Goal updatedGoal, {bool rebackfill = false}) {
    Goal finalGoal = updatedGoal;
    if (rebackfill) {
      // Clear history and re-backfill from sessions
      finalGoal = _backfillHistory(updatedGoal.copyWith(completionHistory: {}));
    }
    
    state = state.map((g) => g.id == updatedGoal.id ? finalGoal : g).toList();
    _saveLocal();
  }

  void rescanGoalHistory(String id) {
    final index = state.indexWhere((g) => g.id == id);
    if (index != -1) {
      final goal = state[index];
      // Force clear all history keys before backfilling to wipe any legacy 1-flags
      final rescanned = _backfillHistory(goal.copyWith(completionHistory: {}));
      state = [
        for (var g in state)
          if (g.id == id) rescanned else g
      ];
      _saveLocal();
    }
  }

  void renameCategory(String oldCat, String newCat) {
    state = state.map((g) => g.category == oldCat ? g.copyWith(category: newCat) : g).toList();
    _saveLocal();
  }

  // Calculate progress for a specific goal at a specific date
  double getProgress(Goal goal, {DateTime? atDate}) {
    if (goal.type == GoalType.task) {
      return _getTaskProgress(goal, _getDaysInPeriod(goal.period, atDate ?? DateTime.now()));
    }
    
    final allSessions = ref.read(sessionsProvider);
    final targetDate = atDate ?? DateTime.now();
    int currentSeconds = 0;

    switch (goal.period) {
      case GoalPeriod.daily:
        currentSeconds = allSessions
            .where((s) => s.category.trim() == goal.category.trim() && s.date.toLocal().year == targetDate.year && s.date.toLocal().month == targetDate.month && s.date.toLocal().day == targetDate.day)
            .fold(0, (sum, s) => sum + s.durationSeconds);
        break;
      case GoalPeriod.weekly:
        final monday = targetDate.subtract(Duration(days: targetDate.weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        final endOfTargetDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
        currentSeconds = allSessions
            .where((s) => s.category.trim() == goal.category.trim() && s.date.toLocal().isAfter(start.subtract(const Duration(seconds: 1))) && s.date.toLocal().isBefore(endOfTargetDay))
            .fold(0, (sum, s) => sum + s.durationSeconds);
        break;
      case GoalPeriod.monthly:
        final start = DateTime(targetDate.year, targetDate.month, 1);
        final endOfTargetDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
        currentSeconds = allSessions
            .where((s) => s.category.trim() == goal.category.trim() && s.date.toLocal().isAfter(start.subtract(const Duration(seconds: 1))) && s.date.toLocal().isBefore(endOfTargetDay))
            .fold(0, (sum, s) => sum + s.durationSeconds);
        break;
      case GoalPeriod.yearly:
        final start = DateTime(targetDate.year, 1, 1);
        final endOfTargetDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
        currentSeconds = allSessions
            .where((s) => s.category.trim() == goal.category.trim() && s.date.toLocal().isAfter(start.subtract(const Duration(seconds: 1))) && s.date.toLocal().isBefore(endOfTargetDay))
            .fold(0, (sum, s) => sum + s.durationSeconds);
        break;
    }

    if (goal.targetSeconds <= 0) return 1.0;
    return (currentSeconds / goal.targetSeconds).clamp(0.0, 1.0);
  }

  double _getTaskProgress(Goal goal, List<DateTime> days) {
    if (goal.targetSeconds <= 0) return 0.0;
    
    int totalAchieved = 0;
    for (var d in days) {
      final dateKey = _formatDate(d);
      totalAchieved += (goal.completionHistory[dateKey] ?? 0) as int;
    }
    
    return (totalAchieved / goal.targetSeconds).clamp(0.0, 1.0);
  }

  List<DateTime> _getDaysInPeriod(GoalPeriod period, DateTime targetDate) {
    final List<DateTime> days = [];
    switch (period) {
      case GoalPeriod.daily:
        days.add(DateTime(targetDate.year, targetDate.month, targetDate.day));
        break;
      case GoalPeriod.weekly:
        final monday = targetDate.subtract(Duration(days: targetDate.weekday - 1));
        for (int i = 0; i < 7; i++) {
          days.add(DateTime(monday.year, monday.month, monday.day).add(Duration(days: i)));
        }
        break;
      case GoalPeriod.monthly:
        final start = DateTime(targetDate.year, targetDate.month, 1);
        final end = DateTime(targetDate.year, targetDate.month + 1, 0);
        for (int i = 0; i < end.day; i++) {
          days.add(start.add(Duration(days: i)));
        }
        break;
      case GoalPeriod.yearly:
        final start = DateTime(targetDate.year, 1, 1);
        final end = DateTime(targetDate.year, 12, 31);
        final diff = end.difference(start).inDays;
        for (int i = 0; i <= diff; i++) {
          days.add(start.add(Duration(days: i)));
        }
        break;
    }
    return days;
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String getRemainingText(Goal goal) {
    if (goal.type == GoalType.task) {
      final days = _getDaysInPeriod(goal.period, DateTime.now());
      int totalAchieved = 0;
      for (var d in days) {
         totalAchieved += (goal.completionHistory[_formatDate(d)] ?? 0) as int;
      }
      return '已達成 $totalAchieved / ${goal.targetSeconds} 單位';
    }

    final progress = getProgress(goal);
    if (progress >= 1.0) return '已達成！ 🎉';

    final currentSeconds = (progress * goal.targetSeconds).round();
    final remainingSeconds = goal.targetSeconds - currentSeconds;
    final hrs = remainingSeconds ~/ 3600;
    final mins = (remainingSeconds % 3600) ~/ 60;
    
    if (hrs > 0) return '還差 ${hrs}小時 ${mins}分鐘';
    return '還差 ${mins}分鐘';
  }

  // Calculate Streak Stats
  Map<String, int> getStreaks(Goal goal) {
    int maxSuccess = 0;
    int monthMaxSuccess = 0;
    int currentSuccess = 0;
    int currentMonthSuccess = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Start scanning from the user-defined startDate (reset time to midnight)
    DateTime start = DateTime(goal.startDate.year, goal.startDate.month, goal.startDate.day);
    
    // Iterate from start date to today
    for (int i = 0; ; i++) {
        final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
        if (d.isAfter(today)) break;

        final dateStr = _formatDate(d);
        final val = goal.completionHistory[dateStr];
        final isCompleted = val != null && val > 0;

        if (isCompleted) {
            currentSuccess++;
            if (currentSuccess > maxSuccess) maxSuccess = currentSuccess;
            
            // Monthly calculation
            if (d.year == now.year && d.month == now.month) {
                currentMonthSuccess++;
                if (currentMonthSuccess > monthMaxSuccess) monthMaxSuccess = currentMonthSuccess;
            } else {
                currentMonthSuccess = 0;
            }
        } else {
            currentSuccess = 0;
            currentMonthSuccess = 0;
        }
    }

    return {'success': maxSuccess, 'month': monthMaxSuccess};
  }

  void _checkMilestones() {
    bool hasChanged = false;
    
    final newList = state.map((goal) {
      // 1. Sync history for this specific day
      final syncedGoal = _backfillHistory(goal);
      
      // 2. Update milestone for TODAY
      final progressToday = getProgress(syncedGoal);
      int milestone = 0;
      if (progressToday >= 1.0) milestone = 100;
      else if (progressToday >= 0.75) milestone = 75;
      else if (progressToday >= 0.50) milestone = 50;
      else if (progressToday >= 0.25) milestone = 25;

      // 3. Compare with existing goal to see if we need to update state
      final bool historyChanged = !mapEquals(syncedGoal.completionHistory, goal.completionHistory);
      final bool milestoneChanged = milestone != goal.lastMilestone;

      if (historyChanged || milestoneChanged) {
        hasChanged = true;
        return syncedGoal.copyWith(lastMilestone: milestone);
      }
      return goal;
    }).toList();

    if (hasChanged) {
      state = newList;
      // We don't necessarily need to push to cloud if it was just a local backfill, 
      // but _saveLocal handles state persistence.
      _saveLocal();
    }
  }

  Goal _backfillHistory(Goal goal) {
    final Map<String, int> history = Map<String, int>.from(goal.completionHistory);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final allSessions = ref.read(sessionsProvider);
    
    // Normalize start date to midnight
    DateTime current = DateTime(goal.startDate.year, goal.startDate.month, goal.startDate.day);
    
    // Iterate from start date up to today to fill history
    while (!current.isAfter(today)) {
      final dateKey = _formatDate(current);
      if (goal.type == GoalType.time) {
        // Record the actual daily contribution in seconds
        final dailySeconds = allSessions
            .where((s) => 
              s.category.trim().toLowerCase() == goal.category.trim().toLowerCase() && 
              s.date.toLocal().year == current.year && 
              s.date.toLocal().month == current.month && 
              s.date.toLocal().day == current.day
            ).fold(0, (sum, s) => sum + s.durationSeconds);
            
        // FORCE-OVERWRITE old values (including the legacy '1' flags)
        history[dateKey] = dailySeconds;
      } else {
        // For Tasks: count the number of discrete timer sessions for this category
        final count = allSessions.where((s) => 
          s.category.trim().toLowerCase() == goal.category.trim().toLowerCase() && 
          s.date.toLocal().year == current.year && 
          s.date.toLocal().month == current.month && 
          s.date.toLocal().day == current.day
        ).length;
        
        // FORCE-OVERWRITE old values
        history[dateKey] = count;
      }
      current = current.add(const Duration(days: 1));
    }
    
    return goal.copyWith(completionHistory: history);
  }

  Future<void> clearAllGoals() async {
    state = [];
    await _saveLocal();
  }
}

final goalProvider = NotifierProvider<GoalNotifier, List<Goal>>(() => GoalNotifier());

final visibleGoalsProvider = Provider<List<Goal>>((ref) {
  final allGoals = ref.watch(goalProvider);
  final visibleCategories = ref.watch(visibleCategoriesProvider);
  return allGoals.where((goal) => visibleCategories.contains(goal.category)).toList();
});
