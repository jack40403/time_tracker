import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/time_session.dart';
import '../models/goal.dart';
import '../providers/session_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/task_goal_provider.dart';
import '../providers/category_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/goal_order_provider.dart';
import '../providers/storage_provider.dart';

class BackupService {
  final WidgetRef ref;
  BackupService(this.ref);

  /// Creates a full JSON backup of the entire app state.
  String createFullBackup() {
    final sessions = ref.read(sessionsProvider);
    final goals = ref.read(goalProvider);
    final taskGoals = ref.read(taskGoalProvider);
    final categoryColors = ref.read(categoryColorProvider);
    final theme = ref.read(themeModeProvider);
    final goalOrder = ref.read(goalOrderProvider);
    final hiddenCategories = ref.read(hiddenCategoriesProvider);
    final timerHidden = ref.read(timerHiddenCategoriesProvider);
    final goalsHidden = ref.read(goalsHiddenCategoriesProvider);
    final statsHidden = ref.read(statsHiddenCategoriesProvider);
    final historyHidden = ref.read(historyHiddenCategoriesProvider);

    final backup = {
      'version': 1,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'payload': {
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'goals': goals.map((g) => g.toJson()).toList(),
        'task_goals': taskGoals.map((g) => g.toJson()).toList(),
        'category_colors': categoryColors.map((k, v) => MapEntry(k, v.value)),
        'theme_mode': theme.index,
        'goal_order': goalOrder,
        'hidden_categories': hiddenCategories.toList(),
        'timer_hidden_categories': timerHidden.toList(),
        'goals_hidden_categories': goalsHidden.toList(),
        'stats_hidden_categories': statsHidden.toList(),
        'history_hidden_categories': historyHidden.toList(),
      }
    };

    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  /// Restores the app state from a JSON backup string.
  Future<bool> restoreFromBackup(String jsonString) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final int version = data['version'] ?? 0;
      if (version < 1) return false;

      final payload = data['payload'] as Map<String, dynamic>;

      // 1. Restore Category Colors
      if (payload.containsKey('category_colors')) {
        final colors = (payload['category_colors'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, Color(v as int))
        );
        ref.read(categoryColorProvider.notifier).state = colors;
        await ref.read(storageServiceProvider).saveCategoryColors(colors);
      }

      // 2. Restore Sessions
      if (payload.containsKey('sessions')) {
        final sessions = (payload['sessions'] as List).map((e) => TimeSession.fromJson(e)).toList();
        ref.read(sessionsProvider.notifier).state = sessions;
        await ref.read(storageServiceProvider).saveSessions(sessions);
      }

      // 3. Restore Goals
      if (payload.containsKey('goals')) {
        final goals = (payload['goals'] as List).map<Goal>((e) => Goal.fromJson(e)).toList();
        await ref.read(goalProvider.notifier).restoreFromBackup(goals);
      }

      // 4. Restore Task Goals
      if (payload.containsKey('task_goals')) {
        final taskGoals = (payload['task_goals'] as List).map<Goal>((e) => Goal.fromJson(e)).toList();
        await ref.read(taskGoalProvider.notifier).restoreFromBackup(taskGoals);
      }

      // 5. Restore Goal Order
      if (payload.containsKey('goal_order')) {
        final order = (payload['goal_order'] as List).cast<String>();
        ref.read(goalOrderProvider.notifier).state = order;
        await ref.read(storageServiceProvider).prefs.setStringList('goal_order', order);
      }

      // 6. Restore Theme
      if (payload.containsKey('theme_mode')) {
        final modeIndex = payload['theme_mode'] as int;
        final mode = ThemeMode.values[modeIndex];
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      }
      
      // 7. Restore Hidden Categories
      if (payload.containsKey('hidden_categories')) {
          final hidden = (payload['hidden_categories'] as List).cast<String>().toSet();
          ref.read(hiddenCategoriesProvider.notifier).state = hidden;
          ref.read(storageServiceProvider).saveHiddenCategories(hidden.toList());
      }
      if (payload.containsKey('timer_hidden_categories')) {
          final hidden = (payload['timer_hidden_categories'] as List).cast<String>().toSet();
          ref.read(timerHiddenCategoriesProvider.notifier).state = hidden;
          ref.read(storageServiceProvider).saveTimerHiddenCategories(hidden.toList());
      }
      if (payload.containsKey('goals_hidden_categories')) {
          final hidden = (payload['goals_hidden_categories'] as List).cast<String>().toSet();
          ref.read(goalsHiddenCategoriesProvider.notifier).state = hidden;
          ref.read(storageServiceProvider).prefs.setStringList('goals_hidden_categories', hidden.toList());
      }
      if (payload.containsKey('stats_hidden_categories')) {
          final hidden = (payload['stats_hidden_categories'] as List).cast<String>().toSet();
          ref.read(statsHiddenCategoriesProvider.notifier).state = hidden;
          ref.read(storageServiceProvider).saveStatsHiddenCategories(hidden.toList());
      }
      if (payload.containsKey('history_hidden_categories')) {
          final hidden = (payload['history_hidden_categories'] as List).cast<String>().toSet();
          ref.read(historyHiddenCategoriesProvider.notifier).state = hidden;
          ref.read(storageServiceProvider).saveHistoryHiddenCategories(hidden.toList());
      }

      return true;
    } catch (e) {
      debugPrint('Restore Error: $e');
      return false;
    }
  }

  /// Generates a CSV string of all time sessions.
  String createSessionsCsv() {
    final sessions = ref.read(sessionsProvider);
    // Header
    final lines = ['Date,Start Time,Category,Duration (Seconds),Duration (Formatted),Note'];
    
    // Sort sessions by date (newest first)
    final sorted = List<TimeSession>.from(sessions)..sort((a, b) => b.date.compareTo(a.date));

    for (var s in sorted) {
      final dateStr = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      final timeStr = '${s.date.hour.toString().padLeft(2, '0')}:${s.date.minute.toString().padLeft(2, '0')}';
      final h = (s.durationSeconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((s.durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final sec = (s.durationSeconds % 60).toString().padLeft(2, '0');
      final formattedDuration = '$h:$m:$sec';
      
      // Escape commas and quotes in notes
      String note = (s.note ?? '').replaceAll('"', '""');
      if (note.contains(',') || note.contains('"') || note.contains('\n')) {
        note = '"$note"';
      }

      lines.add('$dateStr,$timeStr,${s.category},${s.durationSeconds},$formattedDuration,$note');
    }

    // Join with CRLF for maximum CSV compatibility
    return lines.join('\r\n');
  }

  /// Generates a CSV string of all goals and their completion history.
  String createGoalsCsv() {
    final goals = ref.read(goalProvider);
    final taskGoals = ref.read(taskGoalProvider);
    final all = [...goals, ...taskGoals];

    final lines = ['Title,Category,Type,Period,Target,Date,Value,Status'];
    
    for (var g in all) {
      final target = g.targetSeconds;
      final typeStr = g.type.name;
      final periodStr = g.period.name;
      
      // If no history, add a placeholder row
      if (g.completionHistory.isEmpty) {
        lines.add('"${g.title}",${g.category},$typeStr,$periodStr,$target,N/A,0,No History');
        continue;
      }

      // Sort dates
      final dates = g.completionHistory.keys.map((e) => e.toString()).toList()..sort((a, b) => b.compareTo(a));
      
      for (var date in dates) {
        final val = g.completionHistory[date] ?? 0;
        final isAchieved = val >= target ? 'Achieved' : 'Ongoing';
        lines.add('"${g.title}",${g.category},$typeStr,$periodStr,$target,$date,$val,$isAchieved');
      }
    }

    return lines.join('\r\n');
  }
}

final backupServiceProvider = Provider.family<BackupService, WidgetRef>((ref, widgetRef) {
  return BackupService(widgetRef);
});
