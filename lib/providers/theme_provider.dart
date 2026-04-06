import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_provider.dart';
import 'firestore_provider.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final storage = ref.read(storageServiceProvider);
    final local = storage.loadThemeMode();

    // Merge-on-login: Push local theme preference to cloud on first login
    ref.listen(firestoreServiceProvider, (prev, next) {
      if (next != null && prev == null) {
        _saveToCloud(state);
      }
    });

    return local;
  }

  void toggle(bool isDark) {
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    state = newMode;
    _saveLocally(newMode);
    _saveToCloud(newMode);
  }

  void resetToDefault() {
    state = ThemeMode.system;
    _saveLocally(ThemeMode.system);
    _saveToCloud(ThemeMode.system);
  }

  void _saveLocally(ThemeMode mode) {
    ref.read(storageServiceProvider).saveThemeMode(mode);
  }

  void _saveToCloud(ThemeMode mode) {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      firestore.updateSettings({'theme_mode': mode.index});
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  () => ThemeModeNotifier(),
);
