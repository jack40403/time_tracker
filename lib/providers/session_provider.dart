import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/time_session.dart';
import 'storage_provider.dart';
import 'firestore_provider.dart';
import 'category_provider.dart';

class SessionsNotifier extends Notifier<List<TimeSession>> {
  @override
  List<TimeSession> build() {
    final storage = ref.read(storageServiceProvider);
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
    }
  }

  void _syncWithCloud(List<dynamic> cloudSessions) {
    // If cloud has data, it is the ABSOLUTE source of truth.
    // Discard everything local except EXTREMELY recent sessions (last 60 seconds).
    
    final Map<String, TimeSession> cloudMap = {};
    for (var s in cloudSessions) {
      final session = TimeSession.fromJson(s as Map<String, dynamic>);
      // TRUNCATE milliseconds to ensure stable IDs across platforms (consistent with FirestoreService)
      final fixedTime = (session.date.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000;
      final id = '${session.category}_$fixedTime';
      cloudMap[id] = session;
    }

    final now = DateTime.now();
    final List<TimeSession> finalSessions = cloudMap.values.toList();
    
    // Check if we have any very new unsynced local sessions to keep
    for (var s in state) {
      final fixedTime = (s.date.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000;
      final id = '${s.category}_$fixedTime';
      
      if (!cloudMap.containsKey(id)) {
        final ageInSec = now.difference(s.date.toLocal()).inSeconds;
        // Only keep if it was created in the last 60 seconds (waiting for initial sync)
        if (ageInSec < 60 && ageInSec > -60) {
          finalSessions.add(s);
          debugPrint('SessionsNotifier: Carrying over new local session: ${s.category}');
        }
      }
    }

    finalSessions.sort((a, b) => b.date.compareTo(a.date));
    state = finalSessions;
    _saveLocally(state);
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
    state = [session, ...state];
    _saveLocally(state);
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) await firestore.addSession(session);
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
