import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_provider.dart';
import 'timer_provider.dart';
import 'firestore_provider.dart';
import 'session_provider.dart';
import 'goal_provider.dart';

const defaultCategoryColors = {
  '閱讀 📚': Color(0xFF6C63FF),
  '程式碼 💻': Color(0xFF03DAC6),
  '運動 🏃': Color(0xFFFF6584),
};

class CategoryColorNotifier extends Notifier<Map<String, Color>> {
  int _lastLocalUpdateTime = 0;

  @override
  Map<String, Color> build() {
    final storage = ref.read(storageServiceProvider);
    final local = storage.loadCategoryColors(defaultCategoryColors);
    _lastLocalUpdateTime = storage.loadLastUpdated();

    final firestore = ref.watch(firestoreServiceProvider);

    if (firestore != null) {
      ref.listen(cloudSettingsProvider, (previous, next) {
        final cloudSettings = next.value;
        if (cloudSettings != null) {
          Future.microtask(() {
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
          });
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
    ref.read(hiddenCategoriesProvider.notifier).unhideCategory(category);
    if (!state.containsKey(category)) {
      state = {...state, category: color};
      _save();
    }
  }

  void renameCategory(String oldCat, String newCat) {
    if (state.containsKey(oldCat)) {
      final color = state[oldCat]!;
      final newState = Map<String, Color>.from(state);
      newState.remove(oldCat);
      newState[newCat] = color;
      
      ref.read(hiddenCategoriesProvider.notifier).unhideCategory(newCat);
      ref.read(hiddenCategoriesProvider.notifier).removePermanently(oldCat);
      
      state = newState;
      _save();
      
      // Update across all tracked data to avoid "double data" issue
      ref.read(timerProvider.notifier).handleCategoryRename(oldCat, newCat);
      ref.read(sessionsProvider.notifier).renameCategory(oldCat, newCat);
      ref.read(goalProvider.notifier).renameCategory(oldCat, newCat);
    }
  }

  // ONLY HIDES category (KEEP HISTORY COLORS)
  void deleteCategory(String category) {
    if (state.length <= 1) return;
    ref.read(hiddenCategoriesProvider.notifier).hideCategory(category);
    _save();
    // STOP: We no longer reset the timer for "Label Only (Hidden)" categories.
    // The user can continue timing the hidden category until they finish.
  }
  
  // COMPLETELY REMOVES category and colors
  void hardDeleteCategory(String category) {
     if (state.length <= 1) return;
     final newState = Map<String, Color>.from(state);
     newState.remove(category);
     ref.read(hiddenCategoriesProvider.notifier).removePermanently(category);
     state = newState;
     _save();
     
     // Remove all associated data
     ref.read(timerProvider.notifier).handleCategoryDelete(category);
     ref.read(sessionsProvider.notifier).deleteByCategory(category);
  }

  void resetToTrueZero() {
    state = {};
    _save();
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
      if (!newState.containsKey(name) && !hidden.contains(name)) {
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

  void reorderCategories(int oldIndex, int newIndex) {
    final visible = ref.read(visibleCategoriesProvider);
    final all = state.keys.toList();
    final hidden = ref.read(hiddenCategoriesProvider);
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final reorderedVisible = List<String>.from(visible);
    final item = reorderedVisible.removeAt(oldIndex);
    reorderedVisible.insert(newIndex, item);
    
    // Construct new full list: reordered visible followed by hidden
    final List<String> newList = [...reorderedVisible];
    for (final cat in all) {
      if (hidden.contains(cat)) {
        newList.add(cat);
      }
    }
    
    final Map<String, Color> newState = {};
    for (final cat in newList) {
      newState[cat] = state[cat]!;
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
    final storage = ref.read(storageServiceProvider);
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

  void clearAll() {
    state = {};
    _save();
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

final categoryColorProvider = NotifierProvider<CategoryColorNotifier, Map<String, Color>>(
  () => CategoryColorNotifier(),
);

final hiddenCategoriesProvider = NotifierProvider<HiddenCategoriesNotifier, Set<String>>(
  () => HiddenCategoriesNotifier(),
);

final visibleCategoriesProvider = Provider<List<String>>((ref) {
  final all = ref.watch(categoryColorProvider).keys.toList();
  final hidden = ref.watch(hiddenCategoriesProvider);
  return all.where((c) => !hidden.contains(c)).toList();
});
