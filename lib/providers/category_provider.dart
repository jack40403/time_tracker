import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_provider.dart';
import 'timer_provider.dart';
import 'firestore_provider.dart';
import 'session_provider.dart';
import 'goal_provider.dart';
import 'task_goal_provider.dart';
import '../models/time_session.dart';

const defaultCategoryColors = {
  '閱讀 📚': Color(0xFF6C63FF),
  '程式碼 💻': Color(0xFF03DAC6),
  '運動 🏃': Color(0xFFFF6584),
};

class CategoryColorNotifier extends Notifier<Map<String, Color>> {
  int _lastLocalUpdateTime = 0;

  void _syncFromCloud(Map<String, dynamic> cloudSettings) {
    bool changed = false;

    final int cloudTime = cloudSettings['last_updated_at'] ?? 0;
    if (cloudTime <= _lastLocalUpdateTime) return;

    if (cloudSettings.containsKey('category_colors')) {
      final Map<String, dynamic> cColors = cloudSettings['category_colors'];
      final Map<String, Color> decoded = cColors.map((k, v) => MapEntry(k, Color(v as int)));
      if (decoded.toString() != state.toString()) {
        state = decoded;
        changed = true;
      }
    } else if (cloudSettings.containsKey('last_updated_at')) {
      // Explicitly empty in cloud but exists
      if (state.isNotEmpty) {
        state = {};
        changed = true;
      }
    }

    if (changed) {
      _lastLocalUpdateTime = cloudTime;
      _saveLocally();
    }
  }

  @override
  Map<String, Color> build() {
    final storage = ref.watch(storageServiceProvider);
    final local = storage.loadCategoryColors(defaultCategoryColors);
    _lastLocalUpdateTime = storage.loadLastUpdated();

    final firestore = ref.watch(firestoreServiceProvider);

    if (firestore != null) {
      ref.listen(cloudSettingsProvider, (previous, next) {
        final cloudSettings = next.value;
        if (cloudSettings != null) {
          Future.microtask(() => _syncFromCloud(cloudSettings));
        }
      });

      Future.microtask(() {
        final current = ref.read(cloudSettingsProvider);
        if (current.hasValue && current.value != null) {
          _syncFromCloud(current.value!);
        }
      });
    }

    return local;
  }

  void updateColor(String category, Color newColor) {
    state = {...state, category: newColor};
    _save();
  }

  void addCategory(String category, Color color) {
    // Fuzzy Deduplication: Check if a rich version already exists
    final baseName = TimeSession.toBaseName(category);
    final existingRichName = state.keys.firstWhere(
      (k) => TimeSession.toBaseName(k) == baseName,
      orElse: () => '',
    );

    if (existingRichName.isEmpty) {
      state = {...state, category: color};
      _save();
    }
  }

  void renameCategory(String oldCat, String newCatRaw) {
    final newCat = newCatRaw.trim();
    if (newCat.isEmpty || newCat == oldCat) return;

    if (state.containsKey(oldCat)) {
      final color = state[oldCat]!;
      final newState = Map<String, Color>.from(state);
      
      // Preserve order: find index of old category
      final keys = newState.keys.toList();
      final index = keys.indexOf(oldCat);
      
      newState.remove(oldCat);
      
      // Reconstruct state to preserve position
      final Map<String, Color> orderedState = {};
      for (int i = 0; i < keys.length; i++) {
        if (i == index) {
          orderedState[newCat] = color;
        } else if (keys[i] != oldCat) {
          orderedState[keys[i]] = state[keys[i]]!;
        }
      }
      
      // Preserve hidden status during rename
      final isGlobalHidden = ref.read(hiddenCategoriesProvider).contains(oldCat);
      final isTimerHidden = ref.read(timerHiddenCategoriesProvider).contains(oldCat);
      final isGoalsHidden = ref.read(goalsHiddenCategoriesProvider).contains(oldCat);
      final isStatsHidden = ref.read(statsHiddenCategoriesProvider).contains(oldCat);
      final isHistoryHidden = ref.read(historyHiddenCategoriesProvider).contains(oldCat);

      if (isGlobalHidden) {
        ref.read(hiddenCategoriesProvider.notifier).hideCategory(newCat);
        ref.read(hiddenCategoriesProvider.notifier).unhideCategory(oldCat);
      }
      if (isTimerHidden) {
        ref.read(timerHiddenCategoriesProvider.notifier).hideCategory(newCat);
        ref.read(timerHiddenCategoriesProvider.notifier).unhideCategory(oldCat);
      }
      if (isGoalsHidden) {
        ref.read(goalsHiddenCategoriesProvider.notifier).hideCategory(newCat);
        ref.read(goalsHiddenCategoriesProvider.notifier).unhideCategory(oldCat);
      }
      if (isStatsHidden) {
        ref.read(statsHiddenCategoriesProvider.notifier).hideCategory(newCat);
        ref.read(statsHiddenCategoriesProvider.notifier).unhideCategory(oldCat);
      }
      if (isHistoryHidden) {
        ref.read(historyHiddenCategoriesProvider.notifier).hideCategory(newCat);
        ref.read(historyHiddenCategoriesProvider.notifier).unhideCategory(oldCat);
      }
      
      state = orderedState;
      _save();
      
      // ATOMIC UPDATE: Link across all providers
      ref.read(timerProvider.notifier).handleCategoryRename(oldCat, newCat);
      ref.read(sessionsProvider.notifier).renameCategory(oldCat, newCat);
      ref.read(goalProvider.notifier).renameCategory(oldCat, newCat);
      ref.read(taskGoalProvider.notifier).renameCategory(oldCat, newCat);
    }
  }

  // ARCHIVES category (Hides it from all main views but keeps definition)
  void archiveCategory(String category) {
    if (state.length <= 1) return;
    ref.read(hiddenCategoriesProvider.notifier).hideCategory(category);
    _save();
  }
  
  // REMOVES category from ACTIVE LIST but PROTECTS HISTORY
  bool removeCategoryFromList(String category) {
     try {
       debugPrint('CategoryProvider: Request to remove category: "$category"');
       if (state.length <= 1) {
          debugPrint('CategoryProvider: Cancelled - cannot remove the last item.');
          return false;
       }
       final hiddenNotifier = ref.read(hiddenCategoriesProvider.notifier);
       final newState = Map<String, Color>.from(state);
       newState.remove(category);
       hiddenNotifier.removePermanently(category);
       state = newState;
       _save();
       return true;
     } catch (e) {
       return false;
     }
  }

  // WIPE category COMPLETELY (Category + Sessions + Goals)
  Future<bool> wipeCategoryCompletely(String category) async {
    try {
      if (state.length <= 1) return false;
      
      // 1. Delete all sessions
      ref.read(sessionsProvider.notifier).deleteByCategory(category);
      
      // 2. Delete all goals (Time & Task)
      await ref.read(goalProvider.notifier).deleteGoalsByCategory(category);
      await ref.read(taskGoalProvider.notifier).deleteGoalsByCategory(category);
      
      // 3. Remove the category identity
      return removeCategoryFromList(category);
    } catch (e) {
      debugPrint('CategoryProvider Wipe Error: $e');
      return false;
    }
  }

  void resetState() {
    state = Map.from(defaultCategoryColors);
    _lastLocalUpdateTime = DateTime.now().millisecondsSinceEpoch;
  }

  void ensureCategoriesExist(List<String> names) {
    bool changed = false;
    final newState = Map<String, Color>.from(state);
    final hidden = ref.read(hiddenCategoriesProvider);
    
    final autoColors = [
      const Color(0xFF6C63FF),
      const Color(0xFF03DAC6),
      const Color(0xFFFF6584),
      const Color(0xFFFFA62D),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
    ];
    int colorIdx = state.length;

    for (var name in names) {
      final baseName = TimeSession.toBaseName(name);
      final exists = newState.keys.any((k) => TimeSession.toBaseName(k) == baseName) ||
                     hidden.any((h) => TimeSession.toBaseName(h) == baseName);

      if (!exists) {
        newState[name] = autoColors[colorIdx % autoColors.length];
        colorIdx++;
        changed = true;
      }
    }

    if (changed) {
      state = newState;
      _save();
    }
  }

  void reorderCategories(int oldIndex, int newIndex, {List<String>? reorderableCategories}) {
    final all = state.keys.toList();
    final visible = List<String>.from(reorderableCategories ?? ref.read(visibleCategoriesProvider))
        .where(state.containsKey)
        .toList();

    if (oldIndex < 0 || oldIndex >= visible.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (newIndex < 0) newIndex = 0;
    if (newIndex > visible.length) newIndex = visible.length;

    final reorderedVisible = List<String>.from(visible);
    final item = reorderedVisible.removeAt(oldIndex);
    reorderedVisible.insert(newIndex, item);

    final visibleSet = visible.toSet();
    final reorderedIterator = reorderedVisible.iterator;
    final newState = <String, Color>{};

    for (final cat in all) {
      if (visibleSet.contains(cat)) {
        reorderedIterator.moveNext();
        final reorderedCat = reorderedIterator.current;
        newState[reorderedCat] = state[reorderedCat]!;
      } else {
        newState[cat] = state[cat]!;
      }
    }

    state = newState;
    _save();
  }

  void _save() {
    _lastLocalUpdateTime = DateTime.now().millisecondsSinceEpoch;
    _saveLocally();
    _saveToCloud();
  }

  void _saveLocally() {
    final storage = ref.read(storageServiceProvider);
    storage.saveCategoryColors(state);
    storage.saveLastUpdated(_lastLocalUpdateTime);
  }

  void _saveToCloud() {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      firestore.updateSettings({
        'category_colors': state.map((k, v) => MapEntry(k, v.value)),
        'last_updated_at': _lastLocalUpdateTime,
      });
    }
  }
}

class HiddenCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final storage = ref.watch(storageServiceProvider);
    final initial = storage.loadHiddenCategories().toSet();
    
    // Sync from cloud
    ref.listen(cloudSettingsProvider, (previous, next) {
      final cloudSettings = next.value;
      if (cloudSettings != null && cloudSettings.containsKey('hidden_categories')) {
         final cloudHidden = (cloudSettings['hidden_categories'] as List).cast<String>().toSet();
         if (cloudHidden.length != state.length || !cloudHidden.every(state.contains)) {
           state = cloudHidden;
           storage.saveHiddenCategories(state.toList());
         }
      }
    });

    return initial;
  }

  void hideCategory(String category) {
    if (!state.contains(category)) {
      state = {...state, category};
      _save();
    }
  }

  void unhideCategory(String category) {
    if (state.contains(category)) {
      final newState = Set<String>.from(state);
      newState.remove(category);
      state = newState;
      _save();
    }
  }
  
  void removePermanently(String category) {
    unhideCategory(category);
  }

  void resetState() {
    state = {};
  }

  void _save() {
    final storage = ref.read(storageServiceProvider);
    storage.saveHiddenCategories(state.toList());
    
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      firestore.updateSettings({'hidden_categories': state.toList()});
    }
  }
}

class TimerHiddenCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final storage = ref.watch(storageServiceProvider);
    final initial = storage.loadTimerHiddenCategories().toSet();
    
    // Sync from cloud settings if exists
    ref.listen(cloudSettingsProvider, (previous, next) {
      final cloudSettings = next.value;
      if (cloudSettings != null && cloudSettings.containsKey('timer_hidden_categories')) {
         final cloudHidden = (cloudSettings['timer_hidden_categories'] as List).cast<String>().toSet();
         if (cloudHidden.length != state.length || !cloudHidden.every(state.contains)) {
           state = cloudHidden;
           storage.saveTimerHiddenCategories(state.toList());
         }
      }
    });

    return initial;
  }

  void hideCategory(String category) {
    if (!state.contains(category)) {
      state = {...state, category};
      _save();
    }
  }

  void unhideCategory(String category) {
    if (state.contains(category)) {
      final newState = Set<String>.from(state);
      newState.remove(category);
      state = newState;
      _save();
    }
  }

  void resetState() {
    state = {};
  }

  void _save() {
    final storage = ref.read(storageServiceProvider);
    storage.saveTimerHiddenCategories(state.toList());
    
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      firestore.updateSettings({'timer_hidden_categories': state.toList()});
    }
  }
}

class GoalsHiddenCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final storage = ref.watch(storageServiceProvider);
    // Use a new storage key for goal-specific hiding
    final initial = (storage.prefs.getStringList('goals_hidden_categories') ?? []).toSet();
    
    // Sync from cloud settings if exists
    ref.listen(cloudSettingsProvider, (previous, next) {
      final cloudSettings = next.value;
      if (cloudSettings != null && cloudSettings.containsKey('goals_hidden_categories')) {
         final cloudHidden = (cloudSettings['goals_hidden_categories'] as List).cast<String>().toSet();
         if (cloudHidden.length != state.length || !cloudHidden.every(state.contains)) {
           state = cloudHidden;
           storage.prefs.setStringList('goals_hidden_categories', state.toList());
         }
      }
    });

    return initial;
  }

  void hideCategory(String category) {
    if (!state.contains(category)) {
      state = {...state, category};
      _save();
    }
  }

  void unhideCategory(String category) {
    if (state.contains(category)) {
      final newState = Set<String>.from(state);
      newState.remove(category);
      state = newState;
      _save();
    }
  }

  void resetState() {
    state = {};
  }

  void _save() {
    final storage = ref.read(storageServiceProvider);
    storage.prefs.setStringList('goals_hidden_categories', state.toList());
    
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      firestore.updateSettings({'goals_hidden_categories': state.toList()});
    }
  }
}

class StatsHiddenCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final storage = ref.watch(storageServiceProvider);
    final initial = storage.loadStatsHiddenCategories().toSet();

    ref.listen(cloudSettingsProvider, (previous, next) {
      final cloudSettings = next.value;
      if (cloudSettings != null && cloudSettings.containsKey('stats_hidden_categories')) {
        final cloudHidden = (cloudSettings['stats_hidden_categories'] as List).cast<String>().toSet();
        if (cloudHidden.length != state.length || !cloudHidden.every(state.contains)) {
          state = cloudHidden;
          storage.saveStatsHiddenCategories(state.toList());
        }
      }
    });

    return initial;
  }

  void hideCategory(String category) {
    if (!state.contains(category)) {
      state = {...state, category};
      _save();
    }
  }

  void unhideCategory(String category) {
    if (state.contains(category)) {
      final newState = Set<String>.from(state);
      newState.remove(category);
      state = newState;
      _save();
    }
  }

  void resetState() {
    state = {};
  }

  void _save() {
    final storage = ref.read(storageServiceProvider);
    storage.saveStatsHiddenCategories(state.toList());

    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      firestore.updateSettings({'stats_hidden_categories': state.toList()});
    }
  }
}

class HistoryHiddenCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final storage = ref.watch(storageServiceProvider);
    final initial = storage.loadHistoryHiddenCategories().toSet();

    ref.listen(cloudSettingsProvider, (previous, next) {
      final cloudSettings = next.value;
      if (cloudSettings != null && cloudSettings.containsKey('history_hidden_categories')) {
        final cloudHidden = (cloudSettings['history_hidden_categories'] as List).cast<String>().toSet();
        if (cloudHidden.length != state.length || !cloudHidden.every(state.contains)) {
          state = cloudHidden;
          storage.saveHistoryHiddenCategories(state.toList());
        }
      }
    });

    return initial;
  }

  void hideCategory(String category) {
    if (!state.contains(category)) {
      state = {...state, category};
      _save();
    }
  }

  void unhideCategory(String category) {
    if (state.contains(category)) {
      final newState = Set<String>.from(state);
      newState.remove(category);
      state = newState;
      _save();
    }
  }

  void resetState() {
    state = {};
  }

  void _save() {
    final storage = ref.read(storageServiceProvider);
    storage.saveHistoryHiddenCategories(state.toList());

    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      firestore.updateSettings({'history_hidden_categories': state.toList()});
    }
  }
}

final categoryColorProvider = NotifierProvider<CategoryColorNotifier, Map<String, Color>>(
  () => CategoryColorNotifier(),
);

final hiddenCategoriesProvider = NotifierProvider<HiddenCategoriesNotifier, Set<String>>(
  () => HiddenCategoriesNotifier(),
);

final timerHiddenCategoriesProvider = NotifierProvider<TimerHiddenCategoriesNotifier, Set<String>>(
  () => TimerHiddenCategoriesNotifier(),
);

final goalsHiddenCategoriesProvider = NotifierProvider<GoalsHiddenCategoriesNotifier, Set<String>>(
  () => GoalsHiddenCategoriesNotifier(),
);

final statsHiddenCategoriesProvider = NotifierProvider<StatsHiddenCategoriesNotifier, Set<String>>(
  () => StatsHiddenCategoriesNotifier(),
);

final historyHiddenCategoriesProvider = NotifierProvider<HistoryHiddenCategoriesNotifier, Set<String>>(
  () => HistoryHiddenCategoriesNotifier(),
);

// Global Visibility (used for History, Charts, etc.)
final visibleCategoriesProvider = Provider<List<String>>((ref) {
  final all = ref.watch(categoryColorProvider).keys.toList();
  final hidden = ref.watch(hiddenCategoriesProvider);
  return all.where((c) => !hidden.contains(c)).toList();
});

// Timer-specific Visibility (used for Home Page Timer list)
final timerVisibleCategoriesProvider = Provider<List<String>>((ref) {
  final globalVisible = ref.watch(visibleCategoriesProvider);
  final timerHidden = ref.watch(timerHiddenCategoriesProvider);
  return globalVisible.where((c) => !timerHidden.contains(c)).toList();
});

// Goals-specific Visibility (used for Goals Page)
final goalsVisibleCategoriesProvider = Provider<List<String>>((ref) {
  final globalVisible = ref.watch(visibleCategoriesProvider);
  final goalsHidden = ref.watch(goalsHiddenCategoriesProvider);
  return globalVisible.where((c) => !goalsHidden.contains(c)).toList();
});

// Statistics-specific Visibility
final statsVisibleCategoriesProvider = Provider<List<String>>((ref) {
  final globalVisible = ref.watch(visibleCategoriesProvider);
  final statsHidden = ref.watch(statsHiddenCategoriesProvider);
  return globalVisible.where((c) => !statsHidden.contains(c)).toList();
});

// History-specific Visibility
final historyVisibleCategoriesProvider = Provider<List<String>>((ref) {
  final globalVisible = ref.watch(visibleCategoriesProvider);
  final historyHidden = ref.watch(historyHiddenCategoriesProvider);
  return globalVisible.where((c) => !historyHidden.contains(c)).toList();
});
