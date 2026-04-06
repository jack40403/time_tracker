import 'package:flutter/foundation.dart';
import 'media_session_base.dart';

class MediaSessionImpl implements MediaSessionInternal {
  @override
  void updateMetadata(String category, String elapsedDisplay) {
    // No-op on mobile
  }

  @override
  void setPlaybackState(bool isRunning) {
    // No-op on mobile
  }

  @override
  void initHandlers(VoidCallback onToggle) {
    // No-op on mobile
  }
}

MediaSessionInternal getHelper() => MediaSessionImpl();
