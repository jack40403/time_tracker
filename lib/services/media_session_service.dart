import 'package:flutter/foundation.dart';
import 'media_session/media_session_base.dart';
import 'media_session/media_session_stub.dart'
    if (dart.library.js) 'media_session/media_session_web.dart';

class MediaSessionService {
  static final _helper = getHelper();

  static void updateMetadata(String category, String elapsedDisplay) {
    _helper.updateMetadata(category, elapsedDisplay);
  }

  static void setPlaybackState(bool isRunning) {
    _helper.setPlaybackState(isRunning);
  }

  static void initHandlers(VoidCallback onToggle) {
    _helper.initHandlers(onToggle);
  }
}
