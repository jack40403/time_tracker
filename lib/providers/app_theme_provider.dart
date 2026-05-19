import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_themes.dart';
import 'storage_provider.dart';

const _kThemeKey = 'app_theme_id';

class AppThemeIdNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider) as SharedPreferences;
    return prefs.getString(_kThemeKey) ?? 'cartoon';
  }

  void set(String id) {
    if (!kAppThemes.containsKey(id)) return;
    state = id;
    (ref.read(sharedPreferencesProvider) as SharedPreferences).setString(_kThemeKey, id);
  }
}

final appThemeIdProvider = NotifierProvider<AppThemeIdNotifier, String>(
  AppThemeIdNotifier.new,
);

final currentAppThemeProvider = Provider<AppTheme>((ref) {
  final id = ref.watch(appThemeIdProvider);
  return kAppThemes[id] ?? kAppThemes['cartoon']!;
});
