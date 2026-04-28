import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(r'C:\Users\Lithium\Downloads\jiffy-2210132G-1775322297.json');
  if (!file.existsSync()) {
    print('Error: File not found');
    return;
  }

  try {
    final jsonString = file.readAsStringSync();
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<dynamic> timeEntries = data['time_entries'] ?? [];
    final List<dynamic> timeOwners = data['time_owners'] ?? [];

    print('Total Entries: ${timeEntries.length}');
    print('Total Owners: ${timeOwners.length}');

    final Map<String, String> categoryMap = {};
    for (var owner in timeOwners) {
      String rawName = owner['name'] ?? '未分類';
      categoryMap[owner['id']] = rawName;
    }

    int successCount = 0;
    int skippedDeleted = 0;
    int skippedInvalidTime = 0;
    int skippedMissingOwner = 0;

    for (var entry in timeEntries) {
      if (entry['status'] == 'DELETED') {
        skippedDeleted++;
        continue;
      }

      final String? ownerId = entry['owner_id'];
      if (ownerId == null || !categoryMap.containsKey(ownerId)) {
        skippedMissingOwner++;
        continue;
      }

      final int? startMs = entry['start_time'];
      final int? stopMs = entry['stop_time'];

      if (startMs != null && stopMs != null && stopMs > startMs) {
        successCount++;
      } else {
        skippedInvalidTime++;
      }
    }

    print('--- Result ---');
    print('Potentially Success: $successCount');
    print('Skipped (DELETED): $skippedDeleted');
    print('Skipped (Invalid Time): $skippedInvalidTime');
    print('Skipped (Missing Owner): $skippedMissingOwner');

  } catch (e) {
    print('Critical Error during parsing: $e');
  }
}
