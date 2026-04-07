import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/goal.dart';
import 'storage_provider.dart';
import 'firestore_provider.dart';
import 'category_provider.dart';

class TaskGoalNotifier extends Notifier<List<Goal>> {
  static const _storageKey = 'goals_task_v4';
  static const _tombstoneKey = 'goals_task_tombstones';
  int _lastMutationTime = 0;
  Set<String> _tombstones = {};

  @override
  List<Goal> build() {
    // 載入墓碑清單
    final storage = ref.read(storageServiceProvider);
    final tombstoneJson = storage.prefs.getString(_tombstoneKey);
    if (tombstoneJson != null) {
      _tombstones = Set<String>.from(jsonDecode(tombstoneJson));
    }

    final firestore = ref.watch(firestoreServiceProvider);
    if (firestore != null) {
      ref.listen(cloudTaskGoalsProvider, (previous, next) {
        if (next.hasValue) {
          final List<Goal> remote = next.value!.map((e) => Goal.fromJson(e)).toList();
          final isFirst = previous == null || !previous.hasValue;
          _syncWithCloud(remote, force: isFirst);
        }
      });

      Future.microtask(() {
        final current = ref.read(cloudTaskGoalsProvider);
        if (current.hasValue && current.value!.isNotEmpty) {
          final remote = current.value!.map((e) => Goal.fromJson(e)).toList();
          _syncWithCloud(remote, force: true);
        }
      });
    }
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
            debugPrint('TaskGoalNotifier: Skipping corrupted goal: $err');
          }
        }
        return loaded;
      } catch (e) { 
        debugPrint('TaskGoalNotifier: Error decoding storage: $e');
      }
    }
    return [];
  }

  void _saveLocal({bool syncToCloud = true}) async {
    final prefs = ref.read(storageServiceProvider).prefs;
    final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
    
    if (syncToCloud) {
       _lastMutationTime = DateTime.now().millisecondsSinceEpoch;
       final firestore = ref.read(firestoreServiceProvider);
       if (firestore != null) {
         // 回落備份：雖然有了單點同步，saveTaskGoals 仍保留作為全量保存手段
         await firestore.saveTaskGoals(state);
       }
    }
  }

  void _saveSingleLocal(Goal goal, {bool isDelete = false}) async {
    // 1. 本地全量存檔 (安全性備份)
    final prefs = ref.read(storageServiceProvider).prefs;
    final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);

    // 2. 雲端精確同步
    _lastMutationTime = DateTime.now().millisecondsSinceEpoch;
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      if (isDelete) {
        await firestore.deleteGoalById(goal.id, isTaskGoal: true);
      } else {
        await firestore.saveGoal(goal, isTaskGoal: true);
      }
    }
  }

  void _syncWithCloud(List<Goal> remoteGoals, {bool force = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && (now - _lastMutationTime) < 3000) return;

    // 1. 過濾掉墓碑名單中的目標
    final List<Goal> filteredRemote = remoteGoals.where((r) => !_tombstones.contains(r.id)).toList();

    // 2. 自動清理墓碑：如果雲端資料中已經不再包含某個墓碑 ID，代表雲端已同步完成
    final Set<String> remoteIds = remoteGoals.map((g) => g.id).toSet();
    final List<String> toRemoveFromTombstone = _tombstones.where((id) => !remoteIds.contains(id)).toList();
    if (toRemoveFromTombstone.isNotEmpty) {
      _tombstones.removeAll(toRemoveFromTombstone);
      final storage = ref.read(storageServiceProvider);
      storage.prefs.setString(_tombstoneKey, jsonEncode(_tombstones.toList()));
    }

    if (state.isEmpty && filteredRemote.isNotEmpty) {
      state = filteredRemote;
      _saveLocal(syncToCloud: false);
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
        
        // 衝突仲裁：雲端版本較新
        if (remote.updatedAt.isAfter(local.updatedAt)) {
          final Map<String, int> localHistory = Map<String, int>.from(local.completionHistory);
          final Map<String, int> remoteHistory = remote.completionHistory;
          bool historyChanged = false;

          remoteHistory.forEach((date, remoteVal) {
            final localVal = localHistory[date] ?? 0;
            if (remoteVal > localVal) {
              localHistory[date] = remoteVal;
              historyChanged = true;
            }
          });

          mergedMap[remote.id] = remote.copyWith(
            completionHistory: localHistory,
            updatedAt: remote.updatedAt,
          );
          changed = true;
        }
      }
    }
    if (changed) {
      state = mergedMap.values.toList();
      _saveLocal(syncToCloud: false);
    }
  }

  // --- API ---
  void addGoal(String category, int target, GoalPeriod period, {String? title, GoalType type = GoalType.task, DateTime? startDate}) {
    final newGoal = Goal(
      id: const Uuid().v4(),
      title: title ?? category,
      category: category,
      targetSeconds: target,
      period: period,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      startDate: startDate ?? DateTime.now(),
      completionHistory: {},
    );
    state = [...state, newGoal];
    _saveSingleLocal(newGoal);
  }

  void addRawGoal(Goal g) {
    if (!state.any((eg) => eg.id == g.id)) {
      state = [...state, g];
      _saveLocal();
    }
  }

  void updateGoal(Goal updated) {
    final withTimestamp = updated.copyWith(updatedAt: DateTime.now());
    state = state.map((g) => g.id == withTimestamp.id ? withTimestamp : g).toList();
    _saveSingleLocal(withTimestamp);
  }

  void forceMergeFromCloud(List<Goal> remoteGoals) {
    _syncWithCloud(remoteGoals, force: true);
  }

  void deleteGoal(String id) {
    final goal = state.firstWhere((g) => g.id == id, orElse: () => Goal(id: id, title: '', category: '', targetSeconds: 0, period: GoalPeriod.daily, createdAt: DateTime.now(), startDate: DateTime.now()));
    _addTombstones([id]);
    state = state.where((g) => g.id != id).toList();
    _saveSingleLocal(goal, isDelete: true);
  }

  Future<void> deleteGoalsByCategory(String category) async {
    final targets = state.where((g) => g.category == category).toList();
    final idsToRemove = targets.map((g) => g.id).toList();
    _addTombstones(idsToRemove);
    state = state.where((g) => g.category != category).toList();

    // 雲端單點批量刪除
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      for (var g in targets) {
        await firestore.deleteGoalById(g.id, isTaskGoal: true);
      }
    }
    _saveLocal(syncToCloud: false);
  }

  void _addTombstones(List<String> ids) {
    if (ids.isEmpty) return;
    _tombstones.addAll(ids);
    final storage = ref.read(storageServiceProvider);
    storage.prefs.setString(_tombstoneKey, jsonEncode(_tombstones.toList()));
  }

  void renameCategory(String oldCat, String newCat) {
    state = state.map((g) => g.category == oldCat ? g.copyWith(category: newCat) : g).toList();
    _saveLocal();
  }

  void setManualValue(String id, DateTime date, int val) {
    final dateKey = _formatDate(date);
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

  void toggleManualCompletion(String id, DateTime date) {
    final dateKey = _formatDate(date);
    Goal? updatedGoal;
    state = state.map((g) {
      if (g.id == id) {
        final history = Map<String, int>.from(g.completionHistory);
        history[dateKey] = (history[dateKey] ?? 0) > 0 ? 0 : 1;
        updatedGoal = g.copyWith(completionHistory: history, updatedAt: DateTime.now());
        return updatedGoal!;
      }
      return g;
    }).toList();
    if (updatedGoal != null) _saveSingleLocal(updatedGoal!);
  }

  double getProgress(Goal goal) {
     final nowStr = _formatDate(DateTime.now());
     final current = goal.completionHistory[nowStr] ?? 0;
     if (goal.type == GoalType.binary) return current > 0 ? 1.0 : 0.0;
     if (goal.targetSeconds <= 0) return 1.0;
     return (current / goal.targetSeconds).clamp(0.0, 1.0);
  }

  String getRemainingText(Goal goal) {
     final prog = getProgress(goal);
     if (prog >= 1.0) return '已達成！ 🎉';
     final current = goal.completionHistory[_formatDate(DateTime.now())] ?? 0;
     if (goal.type == GoalType.binary) return '今日尚未完成';
     return '還差 ${goal.targetSeconds - current} 單位';
  }

  Map<String, String> getRecords(Goal goal) {
    if (goal.completionHistory.isEmpty) return {
      'historical': '尚無紀錄', 
      'monthly': '尚無紀錄',
      'historical_date': '',
      'monthly_date': '',
    };
    
    final sortedDates = goal.completionHistory.keys.toList()..sort();
    if (sortedDates.isEmpty) return {'historical': '0 天連續', 'monthly': '0 天連續', 'historical_date': '', 'monthly_date': ''};

    final now = DateTime.now();
    final monthPrefix = _formatDate(DateTime(now.year, now.month, 1)).substring(0, 7);

    // 取得起始日
    DateTime cursor = goal.startDate;
    final firstRecord = DateTime.tryParse(sortedDates.first.replaceAll('/', '-')); // 支援不同格式解析
    if (firstRecord != null && firstRecord.isBefore(cursor)) cursor = firstRecord;
    
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    int maxAllStreak = 0;
    int currentAllStreak = 0;
    String maxAllEndDate = '';

    int maxMonthStreak = 0;
    int currentMonthStreak = 0;
    String maxMonthEndDate = '';

    while (!cursor.isAfter(now)) {
      final dateKey = _formatDate(cursor);
      final val = goal.completionHistory[dateKey] ?? 0;
      final isMeetingGoal = val >= goal.targetSeconds;

      if (isMeetingGoal) {
        currentAllStreak++;
        if (currentAllStreak > maxAllStreak) {
          maxAllStreak = currentAllStreak;
          maxAllEndDate = dateKey;
        }
      } else {
        currentAllStreak = 0;
      }

      if (dateKey.startsWith(monthPrefix)) {
        if (isMeetingGoal) {
          currentMonthStreak++;
          if (currentMonthStreak > maxMonthStreak) {
            maxMonthStreak = currentMonthStreak;
            maxMonthEndDate = dateKey;
          }
        } else {
          currentMonthStreak = 0;
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return {
      'historical': '$maxAllStreak 天連續',
      'historical_date': maxAllEndDate.isEmpty ? '尚無紀錄' : '最後達成: $maxAllEndDate',
      'monthly': '$maxMonthStreak 天連續',
      'monthly_date': maxMonthEndDate.isEmpty ? '尚無紀錄' : '最後達成: $maxMonthEndDate',
    };
  }

  String _formatDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

final taskGoalProvider = NotifierProvider<TaskGoalNotifier, List<Goal>>(() => TaskGoalNotifier());

final visibleTaskGoalsProvider = Provider<List<Goal>>((ref) {
  final all = ref.watch(taskGoalProvider);
  final hiddenGoals = ref.watch(goalsHiddenCategoriesProvider);
  final hiddenGlobal = ref.watch(hiddenCategoriesProvider);
  return all.where((g) => g.isActive && !hiddenGoals.contains(g.category) && !hiddenGlobal.contains(g.category)).toList();
});
