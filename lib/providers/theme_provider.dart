import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_provider.dart';
import 'firestore_provider.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final storage = ref.watch(storageServiceProvider);
    final local = storage.loadThemeMode();

    // 監聽雲端設定，實現跨裝置同步
    ref.listen(cloudSettingsProvider, (previous, next) {
      final cloudSettings = next.value;
      if (cloudSettings != null && cloudSettings.containsKey('theme_mode')) {
        final int index = cloudSettings['theme_mode'];
        if (index >= 0 && index < ThemeMode.values.length) {
          final cloudMode = ThemeMode.values[index];
          if (state != cloudMode) {
            state = cloudMode;
            _saveLocally(cloudMode);
          }
        }
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

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _saveLocally(mode);
    _saveToCloud(mode);
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
