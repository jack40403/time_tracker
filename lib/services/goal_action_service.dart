import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../models/goal.dart';
import 'firestore_service.dart';
import 'goal_progress_service.dart';

class GoalActionResult {
  final Goal goal;
  final int currentValue;

  const GoalActionResult(this.goal, this.currentValue);
}

class GoalActionService {
  static const _taskGoalsKey = 'goals_task_v4';
  static const _refreshRequestedKey = 'goal_action_refresh_requested';

  static Future<GoalActionResult?> apply({
    required String goalId,
    required String action,
    DateTime? now,
  }) async {
    final actionTime = now ?? DateTime.now();
    final dateKey = GoalProgressService.dateKey(actionTime);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final localGoals = _readLocalGoals(prefs);
    final localIndex = localGoals.indexWhere((goal) => goal.id == goalId);
    Goal? updated;
    var hasSignedInUser = false;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        hasSignedInUser = true;
        final data = await FirestoreService(user.uid).applyTaskGoalAction(
          goalId: goalId,
          dateKey: dateKey,
          action: action,
        );
        if (data == null) return null;
        updated = Goal.fromJson(data);
      }
    } catch (_) {
      // The caller queues the action for retry when the background write fails.
      return null;
    }

    if (!hasSignedInUser && updated == null && localIndex >= 0) {
      updated = _applyLocally(localGoals[localIndex], dateKey, action, actionTime);
    }
    if (updated == null) return null;

    if (localIndex >= 0) {
      localGoals[localIndex] = updated;
    } else {
      localGoals.add(updated);
    }
    await prefs.setString(
      _taskGoalsKey,
      jsonEncode(localGoals.map((goal) => goal.toJson()).toList()),
    );
    await prefs.setBool(_refreshRequestedKey, true);
    return GoalActionResult(updated, updated.completionHistory[dateKey] ?? 0);
  }

  static Future<bool> takeRefreshRequest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final requested = prefs.getBool(_refreshRequestedKey) ?? false;
    if (requested) await prefs.remove(_refreshRequestedKey);
    return requested;
  }

  static List<Goal> _readLocalGoals(SharedPreferences prefs) {
    final raw = prefs.getString(_taskGoalsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((item) => Goal.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Goal? _applyLocally(
    Goal goal,
    String dateKey,
    String action,
    DateTime now,
  ) {
    final history = Map<String, int>.from(goal.completionHistory);
    final current = history[dateKey] ?? 0;
    if (action == 'complete' && goal.type == GoalType.binary) {
      history[dateKey] = 1;
    } else if (action == 'increment' && goal.type == GoalType.task) {
      history[dateKey] = current + 1;
    } else if (action == 'decrement' && goal.type == GoalType.task) {
      history[dateKey] = current > 0 ? current - 1 : 0;
    } else {
      return null;
    }
    return goal.copyWith(completionHistory: history, updatedAt: now);
  }
}
