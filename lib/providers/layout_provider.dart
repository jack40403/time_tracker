import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import 'auth_provider.dart';

// We keep this file to maintain the storageServiceProvider bridge,
// but we remove the layout mode logic as it is now fully automatic.

final sharedPreferencesProvider = Provider<dynamic>((ref) {
  throw UnimplementedError('sharedPreferencesProvider was not overridden in ProviderScope');
});

final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  
  return StorageService(prefs, uid: uid);
});
