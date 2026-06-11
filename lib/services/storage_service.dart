import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/time_session.dart';

class StorageService {
  final String? uid;
  final SharedPreferences _prefs;

  StorageService(this._prefs, {this.uid});

  // Helper to generate User-Specific Key
  String _pk(String key) => uid == null ? key : '${uid}_$key';

  static const String _sessionsKey = 'sessions';
  static const String _categoryColorsKey = 'category_colors';
  static const String _timerColorKey = 'timer_color';
  static const String _themeModeKey = 'theme_mode';
  static const String _timerStateKey = 'timer_state_v2';
  static const String _layoutModeKey = 'app_layout_mode';
  static const String _deviceIdKey = 'device_id';

  SharedPreferences get prefs => _prefs;

  // --- Sessions ---
  List<TimeSession>? loadSessions() {
    final raw = _prefs.getString(_pk(_sessionsKey));
    if (raw == null) return null;
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
    await _prefs.setString(_pk(_sessionsKey), encoded);
  }

  // --- Category Colors ---
  Map<String, Color> loadCategoryColors(Map<String, Color> defaults) {
    final raw = _prefs.getString(_pk(_categoryColorsKey));
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
    await _prefs.setString(_pk(_categoryColorsKey), encoded);
  }

  // --- Timer Color ---
  Color loadTimerColor(Color defaultColor) {
    final val = _prefs.getInt(_pk(_timerColorKey));
    return val != null ? Color(val) : defaultColor;
  }

  Future<void> saveTimerColor(Color color) async {
    await _prefs.setInt(_pk(_timerColorKey), color.value);
  }

  // --- Theme Mode ---
  ThemeMode loadThemeMode() {
    final index = _prefs.getInt(_pk(_themeModeKey));
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_pk(_themeModeKey), mode.index);
  }

  // --- Custom Background ---
  static const String _bgColorKey = 'bg_color';
  static const String _bgImageKey = 'bg_image';
  static const String _bgIsCustomKey = 'bg_is_custom';
  static const String _bgOpacityKey = 'bg_opacity';

  Map<String, dynamic> loadBackgroundSettings() {
    return {
      'color': _prefs.getInt(_pk(_bgColorKey)),
      'image': _prefs.getString(_pk(_bgImageKey)),
      'isCustom': _prefs.getBool(_pk(_bgIsCustomKey)) ?? false,
      'opacity': _prefs.getDouble(_pk(_bgOpacityKey)) ?? 0.2,
    };
  }

  Future<void> saveBackgroundSettings(int? color, String? image, bool isCustom, double opacity) async {
    if (color != null) await _prefs.setInt(_pk(_bgColorKey), color);
    else await _prefs.remove(_pk(_bgColorKey));
    
    if (image != null) await _prefs.setString(_pk(_bgImageKey), image);
    else await _prefs.remove(_pk(_bgImageKey));
    
    await _prefs.setBool(_pk(_bgIsCustomKey), isCustom);
    await _prefs.setDouble(_pk(_bgOpacityKey), opacity);
  }

  // --- Timer State ---
  Map<String, dynamic>? loadTimerState() {
    final raw = _prefs.getString(_pk(_timerStateKey));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading timer state: $e');
      return null;
    }
  }

  static const String _hiddenCategoriesKey = 'hidden_categories';
  static const String _timerHiddenCategoriesKey = 'timer_hidden_categories';
  static const String _statsHiddenCategoriesKey = 'stats_hidden_categories';
  static const String _historyHiddenCategoriesKey = 'history_hidden_categories';
  static const String _lastUpdatedKey = 'last_updated_at';

  int loadLastUpdated() {
    return _prefs.getInt(_pk(_lastUpdatedKey)) ?? 0;
  }

  Future<void> saveLastUpdated(int timestamp) async {
    await _prefs.setInt(_pk(_lastUpdatedKey), timestamp);
  }

  List<String> loadHiddenCategories() {
    return _prefs.getStringList(_pk(_hiddenCategoriesKey)) ?? [];
  }

  Future<void> saveHiddenCategories(List<String> categories) async {
    await _prefs.setStringList(_pk(_hiddenCategoriesKey), categories);
  }

  List<String> loadTimerHiddenCategories() {
    return _prefs.getStringList(_pk(_timerHiddenCategoriesKey)) ?? [];
  }

  Future<void> saveTimerHiddenCategories(List<String> categories) async {
    await _prefs.setStringList(_pk(_timerHiddenCategoriesKey), categories);
  }

  List<String> loadStatsHiddenCategories() {
    return _prefs.getStringList(_pk(_statsHiddenCategoriesKey)) ?? [];
  }

  Future<void> saveStatsHiddenCategories(List<String> categories) async {
    await _prefs.setStringList(_pk(_statsHiddenCategoriesKey), categories);
  }

  List<String> loadHistoryHiddenCategories() {
    return _prefs.getStringList(_pk(_historyHiddenCategoriesKey)) ?? [];
  }

  Future<void> saveHistoryHiddenCategories(List<String> categories) async {
    await _prefs.setStringList(_pk(_historyHiddenCategoriesKey), categories);
  }

  Future<void> saveTimerState(Map<String, dynamic> state) async {
    await _prefs.setString(_pk(_timerStateKey), jsonEncode(state));
  }

  String loadOrCreateDeviceId() {
    final key = _pk(_deviceIdKey);
    final existing = _prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    _prefs.setString(key, created);
    return created;
  }

  // --- Layout Mode ---
  int loadLayoutMode() {
    return _prefs.getInt(_pk(_layoutModeKey)) ?? 0;
  }

  Future<void> saveLayoutMode(int index) async {
    await _prefs.setInt(_pk(_layoutModeKey), index);
  }

  // --- Master Reset ---
  Future<void> clearAllLocalData() async {
    debugPrint('StorageService: FORCE CLEARING ALL PERSISTENT DATA');
    // 強制完整抹除，不論是否已登入，確保絕對隱私
    await _prefs.clear();
  }
}
