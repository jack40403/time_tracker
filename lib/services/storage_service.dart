import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/time_session.dart';

class StorageService {
  static const String _sessionsKey = 'sessions';
  static const String _categoryColorsKey = 'category_colors';
  static const String _timerColorKey = 'timer_color';
  static const String _themeModeKey = 'theme_mode';
  static const String _timerStateKey = 'timer_state_v2'; // V2 for simplified state
  static const String _layoutModeKey = 'app_layout_mode';

  final SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;
  StorageService(this._prefs);

  // --- Sessions ---
  List<TimeSession>? loadSessions() {
    final raw = _prefs.getString(_sessionsKey);
    if (raw == null) return null; // First Run
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => TimeSession.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      return null;
    }
  }

  Future<void> saveSessions(List<TimeSession> sessions) async {
    final encoded = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await _prefs.setString(_sessionsKey, encoded);
  }

  // --- Category Colors ---
  Map<String, Color> loadCategoryColors(Map<String, Color> defaults) {
    final raw = _prefs.getString(_categoryColorsKey);
    if (raw == null) return Map.from(defaults);
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      return decoded.map((k, v) => MapEntry(k, Color(v as int)));
    } catch (e) {
      debugPrint('Error loading category colors: $e');
      return Map.from(defaults);
    }
  }

  Future<void> saveCategoryColors(Map<String, Color> colors) async {
    final encoded = jsonEncode(colors.map((k, v) => MapEntry(k, v.value)));
    await _prefs.setString(_categoryColorsKey, encoded);
  }

  // --- Timer Color ---
  Color loadTimerColor(Color defaultColor) {
    final val = _prefs.getInt(_timerColorKey);
    return val != null ? Color(val) : defaultColor;
  }

  Future<void> saveTimerColor(Color color) async {
    await _prefs.setInt(_timerColorKey, color.value);
  }

  // --- Theme Mode ---
  ThemeMode loadThemeMode() {
    final index = _prefs.getInt(_themeModeKey);
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_themeModeKey, mode.index);
  }

  // --- Custom Background ---
  static const String _bgColorKey = 'bg_color';
  static const String _bgImageKey = 'bg_image';
  static const String _bgIsCustomKey = 'bg_is_custom';
  static const String _bgOpacityKey = 'bg_opacity';

  Map<String, dynamic> loadBackgroundSettings() {
    return {
      'color': _prefs.getInt(_bgColorKey),
      'image': _prefs.getString(_bgImageKey),
      'isCustom': _prefs.getBool(_bgIsCustomKey) ?? false,
      'opacity': _prefs.getDouble(_bgOpacityKey) ?? 0.2,
    };
  }

  Future<void> saveBackgroundSettings(int? color, String? image, bool isCustom, double opacity) async {
    if (color != null) await _prefs.setInt(_bgColorKey, color);
    else await _prefs.remove(_bgColorKey);
    
    if (image != null) await _prefs.setString(_bgImageKey, image);
    else await _prefs.remove(_bgImageKey);
    
    await _prefs.setBool(_bgIsCustomKey, isCustom);
    await _prefs.setDouble(_bgOpacityKey, opacity);
  }

  // --- Timer State ---
  Map<String, dynamic>? loadTimerState() {
    final raw = _prefs.getString(_timerStateKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading timer state: $e');
      return null;
    }
  }

  static const String _hiddenCategoriesKey = 'hidden_categories';
  static const String _lastUpdatedKey = 'last_updated_at';

  int loadLastUpdated() {
    return _prefs.getInt(_lastUpdatedKey) ?? 0;
  }

  Future<void> saveLastUpdated(int timestamp) async {
    await _prefs.setInt(_lastUpdatedKey, timestamp);
  }

  List<String> loadHiddenCategories() {
    return _prefs.getStringList(_hiddenCategoriesKey) ?? [];
  }

  Future<void> saveHiddenCategories(List<String> categories) async {
    await _prefs.setStringList(_hiddenCategoriesKey, categories);
  }

  Future<void> saveTimerState(Map<String, dynamic> state) async {
    await _prefs.setString(_timerStateKey, jsonEncode(state));
  }

  // --- Layout Mode ---
  int loadLayoutMode() {
    return _prefs.getInt(_layoutModeKey) ?? 0;
  }

  Future<void> saveLayoutMode(int index) async {
    await _prefs.setInt(_layoutModeKey, index);
  }
}
