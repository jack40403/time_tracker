import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_provider.dart';

class GoalOrderNotifier extends Notifier<List<String>> {
  static const _key = 'goals_order_v1';

  @override
  List<String> build() {
    final stored = ref.read(storageServiceProvider).prefs.getString(_key);
    if (stored != null) {
      return List<String>.from(jsonDecode(stored));
    }
    return [];
  }

  void reorder(List<String> orderedIds) {
    state = orderedIds;
    ref.read(storageServiceProvider).prefs.setString(_key, jsonEncode(orderedIds));
  }

  void ensureContains(String id) {
    if (!state.contains(id)) {
      final updated = [...state, id];
      state = updated;
      ref.read(storageServiceProvider).prefs.setString(_key, jsonEncode(updated));
    }
  }

  void remove(String id) {
    final updated = state.where((e) => e != id).toList();
    state = updated;
    ref.read(storageServiceProvider).prefs.setString(_key, jsonEncode(updated));
  }

  void resetState() {
    state = [];
  }
}

final goalOrderProvider = NotifierProvider<GoalOrderNotifier, List<String>>(() => GoalOrderNotifier());
