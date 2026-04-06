import 'package:flutter/foundation.dart';

abstract class MediaSessionInternal {
  void updateMetadata(String category, String elapsedDisplay);
  void setPlaybackState(bool isRunning);
  void initHandlers(VoidCallback onToggle);
}
