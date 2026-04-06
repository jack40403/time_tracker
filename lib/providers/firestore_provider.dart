import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return FirestoreService(user.uid);
});

// Stream for cloud sessions
final cloudSessionsProvider = StreamProvider<List<dynamic>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchSessions();
});

// Stream for cloud settings
final cloudSettingsProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return Stream.value(null);
  return service.watchSettings();
});

// Stream for real-time timer state
final cloudTimerProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return Stream.value(null);
  return service.watchTimerState();
});

// Stream for cloud goals
final cloudGoalsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  if (service == null) return Stream.value([]);
  return service.watchGoals();
});
