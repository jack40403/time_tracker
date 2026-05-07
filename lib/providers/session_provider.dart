import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/time_session.dart';
import 'storage_provider.dart';
import 'firestore_provider.dart';
import 'category_provider.dart';

class SessionsNotifier extends Notifier<List<TimeSession>> {
  @override
  List<TimeSession> build() {
    final storage = ref.watch(storageServiceProvider);
    final localSessions = storage.loadSessions();
    final firestore = ref.watch(firestoreServiceProvider);

    if (firestore != null) {
      ref.listen(cloudSessionsProvider, (previous, next) {
        next.whenData((cloudData) {
          if (cloudData != null) {
            Future.microtask(() => _syncWithCloud(cloudData));
          }
        });
      });

      // 關鍵修復：Riverpod listen 不會重播已存在的快照值，必須主動讀取
      Future.microtask(() {
        final current = ref.read(cloudSessionsProvider);
        if (current.hasValue && current.value != null && current.value!.isNotEmpty) {
          _syncWithCloud(current.value!);
        }
      });
    }
    
    if (localSessions == null) {
      // 登入狀態下不生成假數據，等待雲端同步
      if (firestore != null) return [];
      final now = DateTime.now();
      return _generateDefaultSessions(now);
    }
    return localSessions;
  }

  // 強制從 firestore 直接抓取（繞過 stream 快牆）
  Future<void> forceSyncFromCloud() async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    try {
      final sessions = await firestore.fetchSessionsOnce();
      if (sessions.isNotEmpty) {
        debugPrint('SessionsNotifier: Force sync got ${sessions.length} sessions');
        _syncWithCloud(sessions);
      }
    } catch (e) {
      debugPrint('SessionsNotifier: Force sync failed: $e');
      rethrow;
    }
  }

  // 強制執行深層雲端清理 (原子級修復：Fetch -> Deduplicate -> Wipe -> Repopulate)
  Future<int> forceCloudCleanup() async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return 0;

    try {
      // 1. 從伺服器強制抓取最完整的資料
      final cloudData = await firestore.fetchSessionsOnce();
      final Map<String, TimeSession> normalizedMap = {};

      for (var s in cloudData) {
        final session = TimeSession.fromJson(s as Map<String, dynamic>);
        final stableId = TimeSession.generateId(session.category, session.date);

        // 模糊查重與優先級保留
        if (normalizedMap.containsKey(stableId)) {
          final existing = normalizedMap[stableId]!;
          bool shouldReplace = (existing.note == null || existing.note!.isEmpty) && 
                               (session.note != null && session.note!.isNotEmpty);
          if (!shouldReplace && session.category.length > existing.category.length) {
            shouldReplace = true;
          }
          if (shouldReplace) normalizedMap[stableId] = session.copyWith(id: stableId);
        } else {
          normalizedMap[stableId] = session.copyWith(id: stableId);
        }
      }

      final List<TimeSession> cleanSessions = normalizedMap.values.toList();
      
      // 2. 執行原子級操作：清空雲端並重新上傳乾淨數據
      debugPrint('SessionsNotifier: NUCLEAR CLEANUP START. Clearing cloud...');
      await firestore.deleteAllSessions(); // 清空目前的 Session 集合
      
      debugPrint('SessionsNotifier: NUCLEAR CLEANUP. Repopulating Cloud with ${cleanSessions.length} clean sessions...');
      await firestore.batchUploadSessions(cleanSessions);
      
      // 3. 更新本地狀態以對齊乾淨數據
      state = cleanSessions..sort((a, b) => b.date.compareTo(a.date));
      _saveLocally(state);
      
      return cloudData.length - cleanSessions.length;
    } catch (e) {
      debugPrint('SessionsNotifier: Atomic cleanup failed: $e');
      return 0;
    }
  }

  Future<void> _syncWithCloud(List<dynamic> cloudSessions) async {
    // 安全檢查：如果雲端回傳空數據，但本地有數據，且可能是網路不穩或快取問題
    if (cloudSessions.isEmpty && state.isNotEmpty) {
      debugPrint('SessionsNotifier: Cloud data empty but local exists. Avoiding wipe.');
      // 嘗試將本地數據推上去補齊，而不是直接抹除本地
      _pushAllToCloud();
      return;
    }

    // If cloud has data, it is the ABSOLUTE source of truth.
    // We synchronize and deduplicate based on Fuzzy IDs (BaseName + Timestamp)
    
    final List<String> zombieIds = [];
    final Map<String, TimeSession> normalizedMap = {};
    
    // 1. Process Cloud Data (Normalize IDs & Fuzzy Deduplication)
    for (var s in cloudSessions) {
      TimeSession session;
      if (s is TimeSession) {
        session = s;
      } else if (s is Map<String, dynamic>) {
        session = TimeSession.fromJson(s);
      } else {
        continue;
      }
      
      final String cloudDocId = session.id;
      final stableId = TimeSession.generateId(session.category, session.date);
      
      // Identify "Zombie" IDs: 
      // If the cloud ID doesn't match the stable ID (e.g. contains emojis or different format), mark for deletion
      if (cloudDocId != stableId) {
        zombieIds.add(cloudDocId);
      }
      
      // Fuzzy Deduplication:
      if (normalizedMap.containsKey(stableId)) {
        final existing = normalizedMap[stableId]!;
        
        // Priority Rule:
        // - Keep if it has a note.
        // - Keep if the category name is "richer" (has more symbols/emojis).
        bool shouldReplace = (existing.note == null || existing.note!.isEmpty) && 
                             (session.note != null && session.note!.isNotEmpty);
        
        if (!shouldReplace) {
          if (session.category.length > existing.category.length) {
            shouldReplace = true;
          }
        }

        if (shouldReplace) {
           normalizedMap[stableId] = session.copyWith(id: stableId);
        }
      } else {
        normalizedMap[stableId] = session.copyWith(id: stableId);
      }
    }

    final now = DateTime.now();
    
    // 2. Process Local Data (Normalize & Sync)
    for (var s in state) {
      final stableId = TimeSession.generateId(s.category, s.date);
      
      if (!normalizedMap.containsKey(stableId)) {
        final ageInSec = now.difference(s.date.toLocal()).inSeconds;
        // 安全緩衝：保留尚未上傳的本地紀錄 (增加到 48 小時，避免弱網環境下數據被沖掉)
        if (ageInSec < 172800 && ageInSec > -172800) {
          normalizedMap[stableId] = s.copyWith(id: stableId);
          debugPrint('SessionsNotifier: Carrying over fresh local session: $stableId');
        }
      }
    }

    final List<TimeSession> finalSessions = normalizedMap.values.toList();
    finalSessions.sort((a, b) => b.date.compareTo(a.date));
    
    // Update state and save
    state = finalSessions;
    _saveLocally(state);
    
    // 3. Cloud Cleanup pass - 嚴格 AWAIT 防止背景程序重疊
    if (finalSessions.length < cloudSessions.length || zombieIds.isNotEmpty) {
      debugPrint('SessionsNotifier: Incremental sync cleanup triggered!');
      final firestore = ref.read(firestoreServiceProvider);
      if (firestore != null) {
        if (zombieIds.isNotEmpty) {
          await firestore.batchDeleteSessionsByIds(zombieIds);
        }
        await firestore.batchUploadSessions(finalSessions);
      }
    }
    debugPrint('SessionsNotifier: Sync complete.');
  }

  Future<int> importSessions(List<TimeSession> newSessions) async {
    // 1. Ensure all categories from the import exist in the system
    final importedCategories = newSessions.map((s) => s.category).toSet().toList();
    ref.read(categoryColorProvider.notifier).ensureCategoriesExist(importedCategories);

    final currentMap = {
      for (var s in state) '${s.category}_${(s.date.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000}': s
    };

    int importedCount = 0;
    for (var s in newSessions) {
      final id = '${s.category}_${(s.date.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000}';
      if (!currentMap.containsKey(id)) {
        currentMap[id] = s;
        importedCount++;
      }
    }

    if (importedCount > 0) {
      final newList = currentMap.values.toList()..sort((a, b) => b.date.compareTo(a.date));
      state = newList;
      _saveLocally(state);
      await _pushAllToCloud();
    }
    return importedCount;
  }


  Future<void> clearAll() async {
    state = [];
    _saveLocally(state);
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      await firestore.deleteAllSessions();
    }
  }

  void resetState() {
    state = [];
  }

  List<TimeSession> _generateDefaultSessions(DateTime now) {
    final initial = [
      TimeSession(category: '閱讀 📚', durationSeconds: 3600, date: now.subtract(const Duration(hours: 2))),
      TimeSession(category: '程式碼 💻', durationSeconds: 7200, date: now.subtract(const Duration(hours: 5))),
      TimeSession(category: '運動 🏃', durationSeconds: 1800, date: now.subtract(const Duration(days: 1))),
    ];
    _saveLocally(initial);
    return initial;
  }

  void deleteSession(TimeSession session) async {
    state = state.where((s) => s != session).toList();
    _saveLocally(state);
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) await firestore.deleteSession(session);
  }

  void updateSession(TimeSession updated) async {
    state = state.map((s) => s.id == updated.id ? updated : s).toList();
    _saveLocally(state);
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) await firestore.addSession(updated); // addSession uses SET so it updates if ID exists
  }

  void addSession(TimeSession session) async {
    final stableSession = session.copyWith(id: session.id); // Ensure ID is generated by model logic
    state = [stableSession, ...state];
    _saveLocally(state);
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) await firestore.addSession(stableSession);
  }

  void renameCategory(String oldCat, String newCat) async {
    // 1. Update local state immediately for snappy UI
    final List<TimeSession> updatedSessions = state.map((s) => s.category == oldCat ? s.copyWith(category: newCat) : s).toList();
    state = updatedSessions;
    _saveLocally(state);
    
    // 2. Cloud Update
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      try {
        // We MUST wait for deletion to complete before uploading to avoid ID conflicts
        // and ensure the "Source of Truth" doesn't revert local state.
        await firestore.batchDeleteSessionsByCategory(oldCat); 
        await firestore.batchUploadSessions(updatedSessions);
        debugPrint('SessionsNotifier: Category rename sync complete for $oldCat -> $newCat');
      } catch (e) {
        debugPrint('SessionsNotifier: Rename sync failed: $e');
      }
    }
  }

  void deleteByCategory(String category) async {
    state = state.where((s) => s.category != category).toList();
    _saveLocally(state);
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) await firestore.batchDeleteSessionsByCategory(category);
  }

  Future<String?> _pushAllToCloud() async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      try {
        await firestore.batchUploadSessions(state);
        return null;
      } catch (e) {
        return e.toString();
      }
    }
    return '未登入雲端服務';
  }

  Future<void> syncNow() async {
    await _pushAllToCloud();
  }

  Future<String?> handleInitialSync() async {
    return await _pushAllToCloud();
  }

  void _saveLocally(List<TimeSession> sessions) {
    ref.read(storageServiceProvider).saveSessions(sessions);
  }
}

final sessionsProvider = NotifierProvider<SessionsNotifier, List<TimeSession>>(
  () => SessionsNotifier(),
);
