import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/goal.dart';
import '../services/goal_stats_service.dart';
import 'storage_provider.dart';
import 'firestore_provider.dart';
import 'session_provider.dart';
import 'category_provider.dart';
import 'timer_provider.dart';
import '../services/notification_service.dart';

class GoalNotifier extends Notifier<List<Goal>> {
  static const _storageKey = 'goals_time_v4';
  static const _tombstoneKey = 'goals_time_tombstones';
  int _lastMutationTime = 0;
  Set<String> _tombstones = {};

  @override
  List<Goal> build() {
    // 載入墓碑清單
    final storage = ref.watch(storageServiceProvider);
    final tombstoneJson = storage.prefs.getString(_tombstoneKey);
    if (tombstoneJson != null) {
      _tombstones = Set<String>.from(jsonDecode(tombstoneJson));
    }

    final firestore = ref.watch(firestoreServiceProvider);
    if (firestore != null) {
      ref.listen(cloudGoalsProvider, (previous, next) {
        if (next.hasValue) {
          final List<Goal> remote = next.value!.map((e) => Goal.fromJson(e)).toList();
          // 修復：不再使用 isFirst 強制同步，避免刪除後的雲端回波將已刪除目標寫回
          _syncWithCloud(remote);
        }
      });

      Future.microtask(() {
        final current = ref.read(cloudGoalsProvider);
        if (current.hasValue && current.value!.isNotEmpty) {
          final remote = current.value!.map((e) => Goal.fromJson(e)).toList();
          _syncWithCloud(remote);
        }
        _checkMilestones();
      });
    }

    ref.listen(sessionsProvider, (previous, next) {
      if (previous != next) {
        Future.microtask(recalculateAllGoalsHistory);
      }
    });

    return _load();
  }

  List<Goal> _load() {
    final storage = ref.read(storageServiceProvider);
    final jsonStr = storage.prefs.getString(_storageKey);
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final List<Goal> loaded = [];
        for (var e in decoded) {
          try {
            loaded.add(Goal.fromJson(e));
          } catch (err) {
            debugPrint('GoalNotifier: Skipping corrupted goal: $err');
          }
        }
        return loaded;
      } catch (e) {
        debugPrint('GoalNotifier: Error decoding storage: $e');
      }
    }
    return [];
  }

  void _saveLocal() async {
    final prefs = ref.read(storageServiceProvider).prefs;
    final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }

  void _saveSingleLocal(Goal goal, {bool isDelete = false}) async {
    // 「同步」設定 mutation 時間戳 — 不等 async 完成，節流立即生效
    _lastMutationTime = DateTime.now().millisecondsSinceEpoch;

    // 1. 本地存檔
    final prefs = ref.read(storageServiceProvider).prefs;
    final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);

    // 2. 雲端單點同步
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      if (isDelete) {
        await firestore.deleteGoalById(goal.id, isTaskGoal: false);
      } else {
        await firestore.saveGoal(goal, isTaskGoal: false);
      }
    }
  }

  Future<void> saveAll(List<Goal> goals) async {
    state = goals;
    _saveLocal();
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      for (var goal in goals) {
        await firestore.saveGoal(goal, isTaskGoal: false);
      }
    }
  }

  void _syncWithCloud(List<Goal> remoteGoals, {bool force = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 登入後第一次同步必須強制執行（繞流不中斷）
    if (!force && (now - _lastMutationTime) < 3000) return;

    // 1. 過濾掉本地已刪除（墓碑中）的目標
    final List<Goal> filteredRemote = remoteGoals.where((r) => !_tombstones.contains(r.id)).toList();

    // 2. 自動清理墓碑：如果雲端資料中已經不再包含某個墓碑 ID，代表雲端已同步完成刪除，可以移除墓碑
    final Set<String> remoteIds = remoteGoals.map((g) => g.id).toSet();
    final List<String> toRemoveFromTombstone = _tombstones.where((id) => !remoteIds.contains(id)).toList();
    if (toRemoveFromTombstone.isNotEmpty) {
      _tombstones.removeAll(toRemoveFromTombstone);
      final storage = ref.read(storageServiceProvider);
      storage.prefs.setString(_tombstoneKey, jsonEncode(_tombstones.toList()));
    }

    // 沒有本地數據時直接用雲端數據
    if (state.isEmpty && filteredRemote.isNotEmpty) {
      state = filteredRemote;
      _saveLocal();
      return;
    }

    final Map<String, Goal> mergedMap = {for (var g in state) g.id: g};
    bool changed = false;

    for (var remote in filteredRemote) {
      if (!mergedMap.containsKey(remote.id)) {
        mergedMap[remote.id] = remote;
        changed = true;
      } else {
        final local = mergedMap[remote.id]!;
        
        // 衝突仲裁：若雲端版本較新，或兩者時間相同但內容不同
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          // 深度合併 completionHistory
          final Map<String, int> localHistory = Map<String, int>.from(local.completionHistory);
          final Map<String, int> remoteHistory = remote.completionHistory;

          remoteHistory.forEach((date, remoteVal) {
            final localVal = localHistory[date] ?? 0;
            if (remoteVal > localVal) {
              localHistory[date] = remoteVal;
            }
          });

          mergedMap[remote.id] = remote.copyWith(
            completionHistory: localHistory, // 保留兩端最大的歷史數據
            updatedAt: remote.updatedAt,
          );
          changed = true;
        }
      }
    }
    if (changed) {
      state = mergedMap.values.toList();
      _saveLocal();
    }
  }

  // --- API ---
  String addGoal(String category, int targetSeconds, GoalPeriod period, {
    String? title, 
    GoalType type = GoalType.time, 
    DateTime? startDate,
    String? reminderTime,
    bool isReminderEnabled = false,
  }) {
    final newGoal = Goal(
      id: const Uuid().v4(),
      title: title ?? category,
      category: category,
      targetSeconds: targetSeconds,
      period: period,
      type: type,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      startDate: startDate ?? DateTime.now(),
      reminderTime: reminderTime,
      isReminderEnabled: isReminderEnabled,
    );
    state = [...state, newGoal];
    _saveSingleLocal(newGoal);
    _checkMilestones();
    
    // 安排鬧鐘提醒
    NotificationService.scheduleGoalReminder(newGoal);
    
    return newGoal.id;
  }

  void forceMergeFromCloud(List<Goal> remoteGoals) {
    _lastMutationTime = 0;
    _syncWithCloud(remoteGoals);
  }

  Future<void> forceSyncFromCloud() async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    try {
      final data = await firestore.fetchGoalsOnce();
      if (data.isNotEmpty) {
        final remote = data.map((e) => Goal.fromJson(e)).toList();
        forceMergeFromCloud(remote);
      }
    } catch (e) {
      debugPrint('GoalNotifier: Force sync failed: $e');
    }
  }

  void deleteGoal(String id) {
    final goal = state.firstWhere((g) => g.id == id, orElse: () => Goal(id: id, title: '', category: '', targetSeconds: 0, period: GoalPeriod.daily, createdAt: DateTime.now(), startDate: DateTime.now()));
    _addTombstones([id]);
    state = state.where((g) => g.id != id).toList();
    _saveSingleLocal(goal, isDelete: true);
    
    // 取消鬧鐘提醒
    NotificationService.cancelGoalReminder(id);
  }

  Future<void> deleteGoalsByCategory(String category) async {
    final targets = state.where((g) => g.category == category).toList();
    final idsToRemove = targets.map((g) => g.id).toList();
    _addTombstones(idsToRemove);
    state = state.where((g) => g.category != category).toList();
    
    // 批次單點刪除
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      for (var g in targets) {
        await firestore.deleteGoalById(g.id, isTaskGoal: false);
      }
    }
    _saveLocal();
  }

  void clearAllGoals() {
    _addTombstones(state.map((g) => g.id).toList());
    final oldState = List<Goal>.from(state);
    state = [];
    
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      for (var g in oldState) {
        firestore.deleteGoalById(g.id, isTaskGoal: false);
      }
    }
    _saveLocal();
  }

  void _addTombstones(List<String> ids) {
    if (ids.isEmpty) return;
    _tombstones.addAll(ids);
    final storage = ref.read(storageServiceProvider);
    storage.prefs.setString(_tombstoneKey, jsonEncode(_tombstones.toList()));
  }

  void resetState() {
    state = [];
    _tombstones.clear();
  }

  Future<void> restoreFromBackup(List<Goal> goals) async {
    state = goals;
    _saveLocal();
    _tombstones.clear();
    final storage = ref.read(storageServiceProvider);
    storage.prefs.remove(_tombstoneKey);
  }

  void renameCategory(String oldCat, String newCat) {
    final updated = state.map((g) {
      if (g.category == oldCat) {
        return g.copyWith(category: newCat, updatedAt: DateTime.now());
      }
      return g;
    }).toList();
    state = updated;
    // 逐一更新各目標，避免全量覆蓋
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      for (var g in updated.where((g) => g.category == newCat)) {
        firestore.saveGoal(g, isTaskGoal: false);
      }
    }
    _saveLocal();
  }

  void updateGoal(Goal updated) {
    final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
    state = state.map((g) => g.id == withTimestamp.id ? withTimestamp : g).toList();
    _saveSingleLocal(withTimestamp);
    _checkMilestones();

    // 更新鬧鐘提醒
    NotificationService.scheduleGoalReminder(withTimestamp);
  }

  void setManualValue(String id, DateTime date, int val) {
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    Goal? updatedGoal;
    state = state.map((g) {
      if (g.id == id) {
        final history = Map<String, int>.from(g.completionHistory);
        history[dateKey] = val;
        updatedGoal = g.copyWith(completionHistory: history, updatedAt: DateTime.now());
        return updatedGoal!;
      }
      return g;
    }).toList();
    if (updatedGoal != null) _saveSingleLocal(updatedGoal!);
  }

  void recalculateHistoryFromSessions(String goalId) {
    Goal? updated;
    state = state.map((goal) {
      if (goal.id == goalId) {
        final sessions = ref.read(sessionsProvider);
        final newHistory = <String, int>{};
        
        for (var s in sessions) {
          if (s.category == goal.category) {
            final d = s.date.toLocal();
            if (d.isBefore(goal.startDate.subtract(const Duration(seconds: 1)))) continue;
            final String dateKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            newHistory[dateKey] = (newHistory[dateKey] ?? 0) + s.durationSeconds;
          }
        }
        updated = goal.copyWith(completionHistory: newHistory, updatedAt: DateTime.now());
        return updated!;
      }
      return goal;
    }).toList();
    // 單點更新，不再全量推送
    if (updated != null) _saveSingleLocal(updated!);
  }

  void recalculateAllGoalsHistory() {
    final sessions = ref.read(sessionsProvider);
    bool changed = false;
    
    final newState = state.map((goal) {
      if (goal.type != GoalType.time) return goal;
      
      final newHistory = <String, int>{};
      for (var s in sessions) {
        if (s.category == goal.category) {
          final d = s.date.toLocal();
          if (d.isBefore(goal.startDate.subtract(const Duration(seconds: 1)))) continue;
          final String dateKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          newHistory[dateKey] = (newHistory[dateKey] ?? 0) + s.durationSeconds;
        }
      }
      
      // 比對歷史記錄是否有變動，避免無謂的更新
      if (mapEquals(newHistory, goal.completionHistory)) return goal;
      
      changed = true;
      return goal.copyWith(completionHistory: newHistory, updatedAt: DateTime.now());
    }).toList();

    if (changed) {
      state = newState;
      _saveLocal();
      // 此處不逐一推送到雲端（批量更新時改用一次性本地快取存檔，待下次單點操作再同步）
      // 或者您可以選擇循環調用 _saveSingleLocal，但在這裡頻繁調用雲端可能過載
    }
  }

  double getProgress(Goal goal, {DateTime? atDate}) {
    final targetDate = atDate ?? DateTime.now();
    final allSessions = ref.read(sessionsProvider);
    final String cat = goal.category;
    int currentSeconds = 0;
    final timerState = ref.read(timerProvider);

    for (var s in allSessions) {
      if (s.category == cat) {
        final d = s.date.toLocal();
        // 關鍵核心：僅統計起始日期之後的數據
        if (d.isBefore(goal.startDate.subtract(const Duration(seconds: 1)))) continue;
        
        bool match = false;
        if (goal.period == GoalPeriod.daily) {
          match = d.year == targetDate.year && d.month == targetDate.month && d.day == targetDate.day;
        } else if (goal.period == GoalPeriod.weekly) {
          final monday = targetDate.subtract(Duration(days: targetDate.weekday - 1));
          final start = DateTime(monday.year, monday.month, monday.day);
          final end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
          match = d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end);
        } else if (goal.period == GoalPeriod.monthly) {
          match = d.year == targetDate.year && d.month == targetDate.month;
        } else if (goal.period == GoalPeriod.yearly) {
          match = d.year == targetDate.year;
        }
        if (match) currentSeconds += s.durationSeconds;
      }
    }

    final now = DateTime.now();
    final isCurrentDay = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;
    if (goal.type == GoalType.time &&
        isCurrentDay &&
        !now.isBefore(goal.startDate.subtract(const Duration(seconds: 1))) &&
        timerState.isRunning &&
        timerState.category == cat) {
      currentSeconds += timerState.currentElapsed;
    }

    if (goal.targetSeconds <= 0) return 1.0;
    return (currentSeconds / goal.targetSeconds).clamp(0.0, 1.0);
  }

  void _checkMilestones() {
    final sessions = ref.read(sessionsProvider);
    final now = DateTime.now();
    bool hasChanged = false;

    final newList = state.map((goal) {
      if (goal.type != GoalType.time) return goal;

      final history = Map<String, int>.from(goal.completionHistory);
      final dailySeconds = sessions
          .where((s) => s.category == goal.category && s.date.toLocal().year == now.year && s.date.toLocal().month == now.month && s.date.toLocal().day == now.day)
          .fold(0, (sum, s) => sum + s.durationSeconds);
      
      final String dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (history[dateKey] != dailySeconds) {
        hasChanged = true;
        history[dateKey] = dailySeconds;
        return goal.copyWith(completionHistory: history);
      }
      return goal;
    }).toList();

    if (hasChanged) {
      state = newList;
      // 不推送雲端：milestone 只是本地結果累積，不應該触發全量上傳（防止已刪除目標被復活）
      _saveLocal();
    }
  }

  String getRemainingText(Goal goal) {
    final progress = getProgress(goal);
    if (progress >= 1.0) return '已達成！ 🎉';
    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timerState = ref.read(timerProvider);
    final currentToday = (goal.completionHistory[dateKey] ?? 0) +
        ((goal.type == GoalType.time &&
                !now.isBefore(goal.startDate.subtract(const Duration(seconds: 1))) &&
                timerState.isRunning &&
                timerState.category == goal.category)
            ? timerState.currentElapsed
            : 0);
    final remainingSeconds = goal.targetSeconds - currentToday;
    if (remainingSeconds <= 0) return '已達成！ 🎉';
    final hrs = remainingSeconds ~/ 3600;
    final mins = (remainingSeconds % 3600) ~/ 60;
    if (hrs > 0) return '還差 ${hrs}h ${mins}m';
    return '還差 ${mins}m';
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

  Future<void> syncNow() async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    
    for (var goal in state) {
      await firestore.saveGoal(goal, isTaskGoal: false);
    }
  }
}

final goalProvider = NotifierProvider<GoalNotifier, List<Goal>>(() => GoalNotifier());

final visibleTimeGoalsProvider = Provider<List<Goal>>((ref) {
  final all = ref.watch(goalProvider);
  final hiddenGoals = ref.watch(goalsHiddenCategoriesProvider);
  final hiddenGlobal = ref.watch(hiddenCategoriesProvider);
  return all.where((g) => g.isActive && !hiddenGoals.contains(g.category) && !hiddenGlobal.contains(g.category)).toList();
});

final historyManualAddTimeCategoriesProvider = Provider<List<String>>((ref) {
  final timeGoals = ref.watch(visibleTimeGoalsProvider);
  final categories = <String>{};
  for (final goal in timeGoals) {
    if (goal.type == GoalType.time) {
      categories.add(goal.category);
    }
  }
  final list = categories.toList()..sort();
  return list;
});
