import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/time_session.dart';

class JiffyImportService {
  /// Map for bridging Jiffy categories to Elite categories for future continuity.
  static const Map<String, String> _customMapping = {
    // Add custom mappings here: 'Jiffy ID or Name': 'Elite Name'
  };

  /// Parses the Jiffy JSON export string into a list of TimeSession objects.
  static List<TimeSession> parseJiffyJson(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic> timeEntries = data['time_entries'] ?? [];
      final List<dynamic> timeOwners = data['time_owners'] ?? [];

      // Map owner_id to category name for fast lookup
      final Map<String, String> categoryMap = {};
      for (var owner in timeOwners) {
        String rawName = owner['name'] ?? '未分類';
        
        // Final mapping bridge
        String fixedName = _fixEncoding(rawName);
        categoryMap[owner['id']] = _customMapping[fixedName] ?? fixedName;
      }

      final List<TimeSession> sessions = [];
      for (var entry in timeEntries) {
        // --- 1. Filter out deleted or draft entries ---
        if (entry['status'] == 'DELETED') continue;

        final String? ownerId = entry['owner_id'];
        if (ownerId == null) continue;

        final String category = categoryMap[ownerId] ?? '已刪除分類';
        
        final dynamic rawStart = entry['start_time'];
        final dynamic rawStop = entry['stop_time'];

        // --- 2. Robust Time Parsing ---
        if (rawStart is! num || rawStop is! num) continue;
        
        // Jiffy represents unfinished or broken entries with -1
        final int startMs = rawStart.toInt();
        final int stopMs = rawStop.toInt();

        if (stopMs <= startMs || stopMs <= 0) continue;

        final int duration = (stopMs - startMs) ~/ 1000;
        if (duration > 0) {
          sessions.add(TimeSession(
            category: category,
            durationSeconds: duration,
            date: DateTime.fromMillisecondsSinceEpoch(startMs),
            note: entry['note'] as String?,
          ));
        }
      }
      return sessions;
    } catch (e) {
      debugPrint('JiffyImportService Error: $e');
      return [];
    }
  }

  /// Attempts to fix common encoding issues (Latin-1 read as UTF-8 mojibake).
  static String _fixEncoding(String input) {
    try {
      // 檢測是否包含明顯的 UTF-8 位元特徵被誤讀為 Latin-1
      // 常見於從 Android 導出到不同語系的系統
      List<int> bytes = input.codeUnits;
      
      // 如果所有位元都在 0-255 範圍內，則可能是編碼錯誤
      if (bytes.every((b) => b >= 0 && b <= 255)) {
        // 嘗試將 Latin-1 轉回 UTF-8
        String decoded = utf8.decode(bytes);
        if (decoded.length < input.length) {
           return decoded; // 如果解碼後長度變短（多位元組合），通常是成功的
        }
      }
    } catch (_) {
      // 失敗時返回原始字串
    }
    return input;
  }
}
