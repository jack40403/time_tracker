import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'media_session_base.dart';

class MediaSessionImpl implements MediaSessionInternal {
  @override
  void updateMetadata(String category, String elapsedDisplay) {
    if (!kIsWeb) return;

    try {
      js.context.callMethod('eval', ["""
        if ('mediaSession' in navigator) {
          navigator.mediaSession.metadata = new MediaMetadata({
            title: '計時中: $category',
            artist: 'WHERE DOES THE TIME GO?',
            album: '目前累計: $elapsedDisplay',
            artwork: [
              { src: 'icons/Icon-192.png', sizes: '192x192', type: 'image/png' }
            ]
          });
        }
      """]);
    } catch (e) {
      debugPrint('MediaSession Metadata Error: $e');
    }
  }

  @override
  void setPlaybackState(bool isRunning) {
    if (!kIsWeb) return;

    try {
      js.context.callMethod('eval', ["""
        if ('mediaSession' in navigator) {
          navigator.mediaSession.playbackState = '${isRunning ? 'playing' : 'paused'}';
        }
      """]);
    } catch (e) {
      debugPrint('MediaSession Playback Error: $e');
    }
  }

  @override
  void initHandlers(VoidCallback onToggle) {
    if (!kIsWeb) return;

    try {
      // We store the callback in a global JS variable to be called from JS actions
      js.context['flutter_media_toggle'] = onToggle;

      js.context.callMethod('eval', ["""
        if ('mediaSession' in navigator) {
          navigator.mediaSession.setActionHandler('play', function() {
            if (window.flutter_media_toggle) window.flutter_media_toggle();
          });
          navigator.mediaSession.setActionHandler('pause', function() {
            if (window.flutter_media_toggle) window.flutter_media_toggle();
          });
        }
      """]);
    } catch (e) {
      debugPrint('MediaSession Handler Error: $e');
    }
  }
}

MediaSessionInternal getHelper() => MediaSessionImpl();
