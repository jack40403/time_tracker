import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/time_session.dart';
import '../models/active_timer_record.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  FirestoreService(this.userId);

  // --- Collection Path Helpers ---
  CollectionReference get _sessionsRef =>
      _db.collection('users').doc(userId).collection('sessions');
  
  CollectionReference get _goalsRef =>
      _db.collection('users').doc(userId).collection('goals');
  
  CollectionReference get _taskGoalsRef =>
      _db.collection('users').doc(userId).collection('task_goals');
  
  DocumentReference get _settingsRef =>
      _db.collection('users').doc(userId).collection('settings').doc('app_config');

  DocumentReference get _activeTimerRef =>
      _db.collection('users').doc(userId).collection('settings').doc('timer_state');

  // Standardized ID generation (No-Emoji stable IDs)
  String _getSessionId(TimeSession s) {
    return s.id.isNotEmpty ? s.id : TimeSession.generateId(s.category, s.date);
  }

  // --- Sessions Sync ---
  Stream<List<TimeSession>> watchSessions() {
    debugPrint('FirestoreService: Watching sessions for $userId');
    return _sessionsRef
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('FirestoreService: Received ${snapshot.docs.length} sessions from cloud');
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Ensure the ID in the object matches the document ID for stability
        data['id'] = doc.id;
        return TimeSession.fromJson(data);
      }).toList();
    });
  }

  // 強制從 Server 一次性讀取（繞過 Android Chrome IndexedDB 快牆）
  Future<List<Map<String, dynamic>>> fetchSessionsOnce() async {
    debugPrint('FirestoreService: Force fetching sessions from SERVER for $userId');
    try {
      // 指定 Source.server 強制從伺服器讀取，不用快牆
      final snap = await _sessionsRef
          .orderBy('date', descending: true)
          .get(const GetOptions(source: Source.server));
      debugPrint('FirestoreService: Force fetch got ${snap.docs.length} sessions');
      return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('FirestoreService: Server fetch failed, trying cache: $e');
      // 如果伺服器失敗，回落到快牆
      final snap = await _sessionsRef.orderBy('date', descending: true).get();
      return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
    }
  }

  Future<void> addSession(TimeSession session) async {
    final id = _getSessionId(session);
    debugPrint('FirestoreService: Adding session $id');
    try {
      await _sessionsRef.doc(id).set(session.toJson());
    } catch (e) {
      debugPrint('FirestoreService Error adding session: $e');
    }
  }

  Future<void> updateSession(TimeSession session) async {
    final id = _getSessionId(session);
    debugPrint('FirestoreService: Updating session $id');
    try {
      await _sessionsRef.doc(id).set(session.toJson());
    } catch (e) {
      debugPrint('FirestoreService Error updating session: $e');
    }
  }

  Future<void> deleteSession(TimeSession session) async {
    final docId = _getSessionId(session);
    debugPrint('FirestoreService: Deleting session $docId');
    try {
      await _sessionsRef.doc(docId).delete();
    } catch (e) {
      debugPrint('FirestoreService Error deleting session: $e');
    }
  }

  Future<void> batchDeleteSessionsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    debugPrint('FirestoreService: Batch deleting ${ids.length} sessions by ID');
    try {
      for (var i = 0; i < ids.length; i += 500) {
        final batch = _db.batch();
        final chunk = ids.skip(i).take(500);
        for (var id in chunk) {
          batch.delete(_sessionsRef.doc(id));
        }
        await batch.commit();
      }
      debugPrint('FirestoreService: Batch delete by IDs complete');
    } catch (e) {
      debugPrint('FirestoreService Error in batch delete by IDs: $e');
    }
  }

  Future<void> batchDeleteSessionsByCategory(String category) async {
    debugPrint('FirestoreService: Batch deleting sessions for category $category');
    try {
      final query = await _sessionsRef.where('category', isEqualTo: category).get();
      if (query.docs.isEmpty) return;

      // Handle chunked batching (Firestore limit: 500)
      for (var i = 0; i < query.docs.length; i += 500) {
        final batch = _db.batch();
        final chunk = query.docs.skip(i).take(500);
        for (var doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      debugPrint('FirestoreService: Batch delete for $category complete');
    } catch (e) {
      debugPrint('FirestoreService Error in batch delete: $e');
    }
  }

  Future<void> batchUploadSessions(List<TimeSession> sessions) async {
    if (sessions.isEmpty) return;
    debugPrint('FirestoreService: Batch uploading ${sessions.length} sessions');
    try {
      // Handle chunked batching (Firestore limit: 500)
      for (var i = 0; i < sessions.length; i += 500) {
        final batch = _db.batch();
        final chunk = sessions.skip(i).take(500);
        for (var s in chunk) {
          final id = _getSessionId(s);
          batch.set(_sessionsRef.doc(id), s.toJson());
        }
        await batch.commit();
      }
      debugPrint('FirestoreService: Batch upload complete');
    } catch (e) {
      debugPrint('FirestoreService Error in batch upload: $e');
    }
  }

  Future<void> deleteAllSessions() async {
    debugPrint('FirestoreService: Deleting all sessions for user $userId');
    try {
      final snapshot = await _sessionsRef.get();
      if (snapshot.docs.isEmpty) return;

      for (var i = 0; i < snapshot.docs.length; i += 500) {
        final batch = _db.batch();
        final chunk = snapshot.docs.skip(i).take(500);
        for (var doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      debugPrint('FirestoreService: All sessions deleted from cloud');
    } catch (e) {
      debugPrint('FirestoreService Error deleting all sessions: $e');
    }
  }

  // --- Settings Sync (Category Colors, Timer Color, Theme Mode) ---
  Stream<Map<String, dynamic>?> watchSettings() {
    return _settingsRef.snapshots().map((snapshot) {
      return snapshot.data() as Map<String, dynamic>?;
    });
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    debugPrint('FirestoreService: Updating settings (Overwriting fields)');
    try {
      // Use update instead of set(merge: true) to ensure Map fields (like category_colors)
      // are completely replaced rather than merged. This prevents old/renamed keys from persisting.
      await _settingsRef.update(settings);
    } catch (e) {
      debugPrint('FirestoreService: Document missing, creating initial settings: $e');
      // If document doesn't exist, use set to create it
      await _settingsRef.set(settings);
    }
  }

  // --- Real-time Timer Sync ---
  Stream<Map<String, dynamic>?> watchTimerState() {
    debugPrint('FirestoreService: Watching timer state for $userId');
    return _activeTimerRef.snapshots().map((snapshot) {
      debugPrint('FirestoreService: Received timer state update');
      return snapshot.data() as Map<String, dynamic>?;
    });
  }

  Future<Map<String, dynamic>?> fetchActiveTimerState({bool fromServer = true}) async {
    debugPrint('FirestoreService: Fetching active timer state for $userId (server=$fromServer)');
    try {
      final snap = await _activeTimerRef.get(
        fromServer ? const GetOptions(source: Source.server) : const GetOptions(source: Source.serverAndCache),
      );
      return snap.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('FirestoreService: Fetch active timer state failed: $e');
      if (!fromServer) rethrow;
      final snap = await _activeTimerRef.get();
      return snap.data() as Map<String, dynamic>?;
    }
  }

  Future<void> upsertActiveTimerState(Map<String, dynamic> state) async {
    debugPrint('FirestoreService: Upserting active timer state for $userId');
    try {
      await _activeTimerRef.set(state, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FirestoreService Error updating timer state: $e');
      rethrow;
    }
  }

  Future<void> updateTimerState(Map<String, dynamic> state) async {
    await upsertActiveTimerState(state);
  }

  Future<Map<String, dynamic>?> stopActiveTimerRecord({
    required String deviceId,
    required DateTime stoppedAt,
    String? workspaceId,
    int? observedElapsedSeconds,
    String? note,
  }) async {
    debugPrint('FirestoreService: Stopping active timer for $userId from device=$deviceId');
    try {
      return await _db.runTransaction<Map<String, dynamic>?>((tx) async {
        final snap = await tx.get(_activeTimerRef);
        if (!snap.exists) {
          debugPrint('FirestoreService: No active timer doc found.');
          return null;
        }

        final data = Map<String, dynamic>.from(snap.data() as Map<String, dynamic>);
        if (workspaceId != null && data['workspaceId'] != workspaceId) {
          debugPrint('FirestoreService: Active timer workspace mismatch. Expected=$workspaceId actual=${data['workspaceId']}');
          return null;
        }

        final status = data['status']?.toString() ?? 'running';
        if (status == 'stopped') {
          debugPrint('FirestoreService: Active timer already stopped. Returning existing record.');
          return data;
        }

        final record = ActiveTimerRecord.fromJson(data);
        final recordId = record.recordId.isNotEmpty ? record.recordId : const Uuid().v4();
        final stopped = stoppedAt.toUtc();
        final computedSeconds = observedElapsedSeconds != null && observedElapsedSeconds > 0
            ? observedElapsedSeconds
            : stopped.difference(record.startedAt).inSeconds;
        final safeSeconds = computedSeconds < 0 ? 0 : computedSeconds;

        final updated = <String, dynamic>{
          ...data,
          'recordId': recordId,
          'userId': userId,
          'status': 'stopped',
          'endedAt': stopped.toIso8601String(),
          'durationSeconds': safeSeconds,
          'isRunning': false,
          'baseSeconds': 0,
          'updatedAt': stopped.toIso8601String(),
          'stopDeviceId': deviceId,
          if (note != null && note.isNotEmpty) 'note': note,
        };

        tx.set(_activeTimerRef, updated, SetOptions(merge: true));
        debugPrint('FirestoreService: Active timer stopped successfully. duration=$safeSeconds');
        return updated;
      });
    } catch (e) {
      debugPrint('FirestoreService Error stopping active timer: $e');
      rethrow;
    }
  }

  // --- Goals Sync (Time) ---
  Stream<List<Map<String, dynamic>>> watchGoals() {
    return _goalsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  // 一次性讀取目標（繞過 Stream 快牆）
  Future<List<Map<String, dynamic>>> fetchGoalsOnce() async {
    final snap = await _goalsRef.get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchTaskGoalsOnce() async {
    final snap = await _taskGoalsRef.get();
    return snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
  }

  Future<void> saveGoal(dynamic goal, {bool isTaskGoal = false}) async {
    final CollectionReference ref = isTaskGoal ? _taskGoalsRef : _goalsRef;
    final Map<String, dynamic> data = goal is Map ? Map<String, dynamic>.from(goal) : goal.toJson();
    final String id = data['id'];
    debugPrint('FirestoreService: Saving single goal $id (isTaskGoal: $isTaskGoal)');
    try {
      await ref.doc(id).set(data);
    } catch (e) {
      debugPrint('FirestoreService Error saving single goal: $e');
    }
  }

  Future<void> deleteGoalById(String id, {bool isTaskGoal = false}) async {
    final CollectionReference ref = isTaskGoal ? _taskGoalsRef : _goalsRef;
    debugPrint('FirestoreService: Deleting single goal $id (isTaskGoal: $isTaskGoal)');
    try {
      await ref.doc(id).delete();
    } catch (e) {
      debugPrint('FirestoreService Error deleting single goal: $e');
    }
  }

  Future<void> saveGoals(List<dynamic> goals) async {
    debugPrint('FirestoreService: Bulk saving ${goals.length} time goals (Wiping old)');
    try {
      final batch = _db.batch();
      final existing = await _goalsRef.get();
      for (var doc in existing.docs) {
        batch.delete(doc.reference);
      }
      for (var g in goals) {
        final data = g is Map ? g : (g as dynamic).toJson();
        batch.set(_goalsRef.doc(data['id']), data);
      }
      await batch.commit();
      debugPrint('FirestoreService: Time Goals saved');
    } catch (e) {
      debugPrint('FirestoreService Error saving time goals: $e');
    }
  }

  // --- Goals Sync (Task/Binary) ---
  Stream<List<Map<String, dynamic>>> watchTaskGoals() {
    return _taskGoalsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  Future<void> saveTaskGoals(List<dynamic> goals) async {
    debugPrint('FirestoreService: Saving ${goals.length} task goals');
    try {
      final batch = _db.batch();
      final existing = await _taskGoalsRef.get();
      for (var doc in existing.docs) {
        batch.delete(doc.reference);
      }
      for (var g in goals) {
        final data = g is Map ? g : (g as dynamic).toJson();
        batch.set(_taskGoalsRef.doc(data['id']), data);
      }
      await batch.commit();
      debugPrint('FirestoreService: Task Goals saved');
    } catch (e) {
      debugPrint('FirestoreService Error saving task goals: $e');
    }
  }

  // --- Master Reset ---
  Future<void> clearAllUserData() async {
    debugPrint('FirestoreService: STARTING MASTER RESET for user $userId');
    try {
      final batch = _db.batch();

      // 1. Delete all sessions
      final sessions = await _sessionsRef.get();
      for (var doc in sessions.docs) batch.delete(doc.reference);

      // 2. Delete all goals
      final goals = await _goalsRef.get();
      for (var doc in goals.docs) batch.delete(doc.reference);

      // 3. Delete all task goals
      final taskGoals = await _taskGoalsRef.get();
      for (var doc in taskGoals.docs) batch.delete(doc.reference);

      // 4. Delete settings
      batch.delete(_settingsRef);
      batch.delete(_db.collection('users').doc(userId).collection('settings').doc('timer_state'));

      await batch.commit();
      debugPrint('FirestoreService: MASTER RESET COMPLETE');
    } catch (e) {
      debugPrint('FirestoreService: Error during master reset: $e');
      throw e;
    }
  }
}
