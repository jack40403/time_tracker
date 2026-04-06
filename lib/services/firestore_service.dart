import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/time_session.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  FirestoreService(this.userId);

  // --- Collection Path Helpers ---
  CollectionReference get _sessionsRef =>
      _db.collection('users').doc(userId).collection('sessions');
  
  CollectionReference get _goalsRef =>
      _db.collection('users').doc(userId).collection('goals');
  
  DocumentReference get _settingsRef =>
      _db.collection('users').doc(userId).collection('settings').doc('app_config');

  // Standardized ID generation (Seconds precision for cross-platform stability)
  String _getSessionId(TimeSession s) {
    final fixedTime = (s.date.toUtc().millisecondsSinceEpoch ~/ 1000) * 1000;
    return '${s.category}_$fixedTime';
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
        return TimeSession.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();
    });
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

  Future<void> deleteSession(TimeSession session) async {
    final docId = _getSessionId(session);
    debugPrint('FirestoreService: Deleting session $docId');
    try {
      await _sessionsRef.doc(docId).delete();
    } catch (e) {
      debugPrint('FirestoreService Error deleting session: $e');
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
    return _db.collection('users').doc(userId).collection('settings').doc('timer_state')
        .snapshots()
        .map((snapshot) {
          debugPrint('FirestoreService: Received timer state update');
          return snapshot.data() as Map<String, dynamic>?;
        });
  }

  Future<void> updateTimerState(Map<String, dynamic> state) async {
    debugPrint('FirestoreService: Updating timer state');
    try {
      await _db.collection('users').doc(userId).collection('settings').doc('timer_state')
          .set(state);
    } catch (e) {
      debugPrint('FirestoreService Error updating timer state: $e');
    }
  }

  // --- Goals Sync ---
  Stream<List<Map<String, dynamic>>> watchGoals() {
    return _goalsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
  }

  Future<void> saveGoals(List<dynamic> goals) async {
    debugPrint('FirestoreService: Saving ${goals.length} goals');
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
      debugPrint('FirestoreService: Goals saved');
    } catch (e) {
      debugPrint('FirestoreService Error saving goals: $e');
    }
  }
}
