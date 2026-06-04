import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DebugHelper {
  static const String _snapshotKey = 'debug_data_snapshot';
  
  static const List<String> _keysToTrack = [
    'sessions',
    'category_colors',
    'timer_color',
    'theme_mode',
    'timer_state_v2',
    'app_layout_mode',
    'hidden_categories',
    'stats_hidden_categories',
    'history_hidden_categories',
    'last_updated_at',
    'time_tracker_goals',
  ];

  static Future<void> createSnapshot(SharedPreferences prefs) async {
    final Map<String, dynamic> data = {};
    for (final key in _keysToTrack) {
      final val = prefs.get(key);
      if (val != null) {
        data[key] = val;
      }
    }
    await prefs.setString(_snapshotKey, jsonEncode(data));
    debugPrint('DebugHelper: Snapshot created.');
  }

  static Future<bool> restoreSnapshot(SharedPreferences prefs) async {
    final raw = prefs.getString(_snapshotKey);
    if (raw == null) return false;

    try {
      final Map<String, dynamic> data = jsonDecode(raw);
      
      // Clear current tracked keys first (optional, but cleaner)
      for (final key in _keysToTrack) {
        await prefs.remove(key);
      }

      for (final entry in data.entries) {
        final key = entry.key;
        final val = entry.value;

        if (val is String) {
          await prefs.setString(key, val);
        } else if (val is int) {
          await prefs.setInt(key, val);
        } else if (val is double) {
          await prefs.setDouble(key, val);
        } else if (val is bool) {
          await prefs.setBool(key, val);
        } else if (val is List) {
          await prefs.setStringList(key, val.cast<String>());
        }
      }
      debugPrint('DebugHelper: Snapshot restored.');
      return true;
    } catch (e) {
      debugPrint('DebugHelper: Restore failed: $e');
      return false;
    }
  }

  static Future<void> clearAll(SharedPreferences prefs) async {
    for (final key in _keysToTrack) {
      await prefs.remove(key);
    }
  }

  static bool hasSnapshot(SharedPreferences prefs) {
    return prefs.containsKey(_snapshotKey);
  }
}
