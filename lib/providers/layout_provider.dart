import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

// We keep this file to maintain the storageServiceProvider bridge,
// but we remove the layout mode logic as it is now fully automatic.

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider was not overridden in ProviderScope');
});
