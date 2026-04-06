import 'dart:convert';
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
        // Fix potential encoding issues (Mojibake fix)
        String fixedName = _fixEncoding(rawName);
        
        // Final mapping bridge
        categoryMap[owner['id']] = _customMapping[fixedName] ?? fixedName;
      }

      final List<TimeSession> sessions = [];
      for (var entry in timeEntries) {
        final String? ownerId = entry['owner_id'];
        if (ownerId == null) continue;

        final String category = categoryMap[ownerId] ?? '已刪除分類';
        final int? startMs = entry['start_time'];
        final int? stopMs = entry['stop_time'];

        if (startMs != null && stopMs != null) {
          final int duration = (stopMs - startMs) ~/ 1000;
          if (duration > 0) {
            sessions.add(TimeSession(
              category: category,
              durationSeconds: duration,
              date: DateTime.fromMillisecondsSinceEpoch(startMs),
            ));
          }
        }
      }
      return sessions;
    } catch (e) {
      print('JiffyImportService Error: $e');
      return [];
    }
  }

  /// Attempts to fix common encoding issues (Latin-1 read as UTF-8 mojibake).
  static String _fixEncoding(String input) {
    try {
      // If the string contains characters that look like Latin-1 misintepretations of UTF-8.
      // Example: "å­¸ç¿" -> "學習"
      List<int> bytes = input.codeUnits;
      // Only attempt fix if we see high-byte characters common in mojibake
      if (bytes.any((b) => b > 127 && b < 256)) {
        return utf8.decode(bytes);
      }
    } catch (_) {
      // If decoding fails, return original
    }
    return input;
  }
}
