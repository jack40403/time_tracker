import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import '../models/time_session.dart';
import 'storage_provider.dart';
import 'session_provider.dart';
import 'firestore_provider.dart';
import 'category_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/media_session_service.dart';

class TimerColorNotifier extends Notifier<Color> {
  @override
  Color build() {
    final storage = ref.watch(storageServiceProvider);
    final local = storage.loadTimerColor(const Color(0xFF03DAC6));
    final firestore = ref.watch(firestoreServiceProvider);

    if (firestore != null) {
      ref.listen(cloudSettingsProvider, (previous, next) {
        final cloudSettings = next.value;
        if (cloudSettings != null && cloudSettings.containsKey('timer_color')) {
          final val = cloudSettings['timer_color'] as int;
          if (val != state.value) {
            state = Color(val);
            _saveLocally(state);
          }
        }
      });
      Future.microtask(() => _saveToCloud(state));
    }
    return local;
  }

  void updateColor(Color newColor) {
    state = newColor;
    _saveLocally(newColor);
    _saveToCloud(newColor);
  }

  void resetToDefault() {
    updateColor(const Color(0xFF03DAC6));
  }

  void _saveLocally(Color color) {
    ref.read(storageServiceProvider).saveTimerColor(color);
  }

  void _saveToCloud(Color color) {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      firestore.updateSettings({'timer_color': color.value});
    }
  }
}

final timerColorProvider = NotifierProvider<TimerColorNotifier, Color>(
  () => TimerColorNotifier(),
);

class TimerState {
  final bool isRunning;
  final String category;
  final DateTime? startTime;
  final int baseSeconds;
  final DateTime? lastSyncTime;

  const TimerState({
    this.isRunning = false,
    this.category = '尚未選擇項目',
    this.startTime,
    this.baseSeconds = 0,
    this.lastSyncTime,
  });

  int get currentElapsed {
    if (!isRunning || startTime == null) return baseSeconds;
    final now = DateTime.now().toUtc();
    return baseSeconds + now.difference(startTime!).inSeconds;
  }

  TimerState copyWith({
    bool? isRunning,
    String? category,
    DateTime? startTime,
    int? baseSeconds,
    DateTime? lastSyncTime,
  }) {
    return TimerState(
      isRunning: isRunning ?? this.isRunning,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      baseSeconds: baseSeconds ?? this.baseSeconds,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  Map<String, dynamic> toJson() => {
        'isRunning': isRunning,
        'category': category,
        'startTime': startTime?.toUtc().toIso8601String(),
        'baseSeconds': baseSeconds,
        'lastSyncTime': lastSyncTime?.toUtc().toIso8601String(),
      };

  factory TimerState.fromJson(Map<String, dynamic> json) => TimerState(
        isRunning: json['isRunning'] ?? false,
        category: json['category'] ?? '尚未選擇項目',
        startTime: json['startTime'] != null ? DateTime.parse(json['startTime']).toUtc() : null,
        baseSeconds: json['baseSeconds'] ?? 0,
        lastSyncTime: json['lastSyncTime'] != null ? DateTime.parse(json['lastSyncTime']).toUtc() : null,
      );
}

class TimerNotifier extends Notifier<TimerState> {
  Timer? _timer;
  bool _isSyncingFromCloud = false;
  DateTime? _lastManualActionTime;

  String get debugId {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return '未登入';
    final uid = firestore.userId;
    // v3.UltraSync_MASTER_UI_BRANDED: Official Design & Legacy Pro Suite
    final idPart = uid.length > 8 ? uid.substring(uid.length - 8) : uid;
    return idPart;
  }

  String _formatTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hrs > 0) return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  TimerState build() {
    final storage = ref.watch(storageServiceProvider);
    final localJson = storage.loadTimerState();
    final firestore = ref.watch(firestoreServiceProvider);

    if (kIsWeb) {
      MediaSessionService.initHandlers(toggleTimer);
    }

    if (firestore != null) {
      ref.listen(cloudTimerProvider, (previous, next) {
        next.whenData((cloudState) {
          if (cloudState != null) {
            _syncFromRemote(TimerState.fromJson(cloudState));
          }
        });
      });
    }

    if (localJson != null) {
      final local = TimerState.fromJson(localJson);
      if (local.isRunning) {
        Future.microtask(() => _startTicker());
        // ZOMBIE RECOVERY: Ensure service is actually running if state says so
        Future.microtask(() => _restartServiceIfNeeded());
      }
      
      // Ensure initial widget sync
      Future.microtask(() => _syncToWidget());
    }

    // Listen for background service events (Android Notification Actions) ALWAYS
    if (!kIsWeb) {
      FlutterBackgroundService().on('statusChange').listen((event) {
        if (event != null && !kIsWeb) {
          final bool remoteRunning = event['isRunning'];
          final int remoteSeconds = event['currentElapsed'];
          
          if (remoteRunning != state.isRunning) {
            _lastManualActionTime = DateTime.now(); // Prevent cloud bounce overwrite!
            if (remoteRunning) {
              state = state.copyWith(
                isRunning: true, 
                startTime: DateTime.now().toUtc().subtract(Duration(seconds: remoteSeconds)),
                baseSeconds: 0,
              );
              _startTicker();
            } else {
              _timer?.cancel();
              
              final delta = state.startTime != null 
                  ? DateTime.now().toUtc().difference(state.startTime!).inSeconds 
                  : 0;
                  
              if (delta > 0) {
                final session = TimeSession(
                  category: state.category,
                  durationSeconds: delta,
                  date: DateTime.now().toLocal().subtract(Duration(seconds: delta)),
                );
                ref.read(sessionsProvider.notifier).addSession(session);
              }

              state = state.copyWith(isRunning: false, baseSeconds: remoteSeconds, startTime: null);
            }
            _pushToCloud();
          }
        }
      });

      FlutterBackgroundService().on('stopFromNotification').listen((event) {
        stopAndSave();
      });
    }

    if (localJson != null) {
      return TimerState.fromJson(localJson);
    }

    return const TimerState();
  }

  void _syncFromRemote(TimerState remote) {
    if (remote.isRunning && remote.startTime != null) {
      final nowUtc = DateTime.now().toUtc();
      final age = nowUtc.difference(remote.startTime!).inHours;
      if (age > 12) return;
    }

    if (_lastManualActionTime != null) {
      if (DateTime.now().difference(_lastManualActionTime!).inSeconds < 3) return;
    }

    final bool shouldSync = remote.isRunning != state.isRunning || 
        remote.category != state.category ||
        (remote.isRunning && remote.startTime != null && !remote.startTime!.isAtSameMomentAs(state.startTime ?? DateTime(0))) ||
        remote.baseSeconds != state.baseSeconds;
        
    if (shouldSync) {
      debugPrint('TimerNotifier: Syncing from Cloud...');
      TimerState adjustedRemote = remote;
      if (remote.isRunning && remote.startTime != null && remote.lastSyncTime != null) {
        final offset = remote.lastSyncTime!.difference(DateTime.now().toUtc());
        final adjustedStartTime = remote.startTime!.subtract(offset);
        adjustedRemote = remote.copyWith(startTime: adjustedStartTime);
        debugPrint('TimerNotifier: Syncing Clock Skew Offset: ${offset.inMilliseconds}ms');
      }

      _isSyncingFromCloud = true;
      state = adjustedRemote; 
      if (adjustedRemote.isRunning) _startTicker(); else _timer?.cancel();
      _isSyncingFromCloud = false;
    }
  }

  void _syncToBackground() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bg_handoff_state', jsonEncode({
        'seconds': state.currentElapsed,
        'category': state.category,
        'isRunning': state.isRunning,
      }));

      FlutterBackgroundService().invoke('setTimerData', {
        'seconds': state.currentElapsed,
        'category': state.category,
        'isRunning': state.isRunning,
      });
    } catch (e) {
       debugPrint('Background sync failed: $e');
    }
  }

  void _syncToWidget() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      HomeWidget.saveWidgetData<String>('task_name', state.category);
      HomeWidget.saveWidgetData<String>('timer_text', _formatTime(state.currentElapsed));
      HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.example.time_tracker.MasterWidgetProvider',
      );
    } catch (e) {
      debugPrint('Widget sync failed: $e');
    }
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      state = state.copyWith();
      if (kIsWeb) {
        MediaSessionService.updateMetadata(state.category, _formatTime(state.currentElapsed));
      }
      
      // Auto-save every 5 ticks (approx 2.5 seconds) to handle background killing
      if (timer.tick % 5 == 0) {
        // Removed _syncToBackground() here to prevent the UI from recursively overriding the background service state
        _pushToCloud();
        _syncToWidget();
      }
    });
    _syncToBackground();
    _syncToLiveActivity();
    _syncToWidget();
    if (kIsWeb) {
      MediaSessionService.setPlaybackState(state.isRunning);
      MediaSessionService.updateMetadata(state.category, _formatTime(state.currentElapsed));
    }
  }

  Future<void> _syncToLiveActivity() async {
    // Disabled
  }

  void changeCategory(String newCategory) {
    if (state.category == newCategory) return;
    _timer?.cancel();
    state = state.copyWith(isRunning: false, category: newCategory, startTime: null);
    _pushToCloud();
  }

  void resetState() {
    _timer?.cancel();
    state = const TimerState();
  }

  void handleCategoryRename(String oldCat, String newCat) {
    if (state.category == oldCat) {
      state = state.copyWith(category: newCat);
      _syncToWidget();
      _pushToCloud();
    }
  }

  void handleCategoryDelete(String category) {
    if (state.category == category) {
      debugPrint('TimerNotifier: Current category "$category" was deleted. Finding fallback...');
      _timer?.cancel();
      
      final currentMap = ref.read(categoryColorProvider);
      final allCats = currentMap.keys.toList();
      final hidden = ref.read(hiddenCategoriesProvider);
      final visible = allCats.where((c) => !hidden.contains(c)).toList();
      
      String fallback;
      if (visible.isNotEmpty) {
        fallback = visible.first;
      } else if (allCats.isNotEmpty) {
        fallback = allCats.first;
      } else {
        fallback = '尚未選擇項目';
      }
      
      debugPrint('TimerNotifier: Switching fallback to: "$fallback"');
      state = TimerState(category: fallback);
      _pushToCloud();
    }
  }

  void toggleTimer() {
    _lastManualActionTime = DateTime.now();
    HapticFeedback.selectionClick(); // 開始或暫停時的輕微震動

    if (state.isRunning) {
      _timer?.cancel();
      
      final delta = state.startTime != null 
          ? DateTime.now().toUtc().difference(state.startTime!).inSeconds 
          : 0;
          
      // AUTO-SPLIT: Save current segment as a session immediately
      if (delta > 0) {
        final session = TimeSession(
          category: state.category,
          durationSeconds: delta,
          date: DateTime.now().toLocal().subtract(Duration(seconds: delta)),
        );
        ref.read(sessionsProvider.notifier).addSession(session);
      }

      final totalElapsed = state.currentElapsed;
      state = state.copyWith(isRunning: false, baseSeconds: totalElapsed, startTime: null);
      if (kIsWeb) {
        MediaSessionService.setPlaybackState(false);
        MediaSessionService.updateMetadata(state.category, '00:00');
      }
    } else {
      state = state.copyWith(isRunning: true, startTime: DateTime.now().toUtc());
      if (!kIsWeb) {
        try {
          FlutterBackgroundService().startService();
        } catch (e) {}
      }
      _startTicker();
    }
    _syncToBackground();
    _syncToLiveActivity();
    _syncToWidget();
    _pushToCloud();
  }

  void stopAndSave({String? note}) async {
    _timer?.cancel();
    
    // 強效震動兩下
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 300, 200, 300]);
    }
    
    final delta = state.isRunning && state.startTime != null
          ? DateTime.now().toUtc().difference(state.startTime!).inSeconds 
          : 0;
    if (delta > 0) {
      final session = TimeSession(
        category: state.category,
        durationSeconds: delta,
        date: DateTime.now().toLocal().subtract(Duration(seconds: delta)),
        note: note,
      );
      ref.read(sessionsProvider.notifier).addSession(session);
    }
    if (kIsWeb) {
      MediaSessionService.setPlaybackState(false);
      MediaSessionService.updateMetadata('已停止', '00:00');
    }
    final allCats = ref.read(categoryColorProvider).keys.toList();
    final hidden = ref.read(hiddenCategoriesProvider);
    final visible = allCats.where((c) => !hidden.contains(c)).toList();
    final String nextCategory = visible.isNotEmpty ? visible.first : (allCats.isNotEmpty ? allCats.first : '尚未選擇項目');
    
    state = TimerState(category: nextCategory);
    if (!kIsWeb) FlutterBackgroundService().invoke('stopService');
    _syncToLiveActivity();
    _syncToWidget();
    _pushToCloud();
  }

  void resetTimer() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false, baseSeconds: 0, startTime: null);
    if (kIsWeb) {
      MediaSessionService.setPlaybackState(false);
      MediaSessionService.updateMetadata(state.category, '00:00');
    }
    _syncToBackground();
    _syncToLiveActivity();
    _syncToWidget();
    _pushToCloud();
  }

  void _pushToCloud() {
    _saveLocally();
    if (_isSyncingFromCloud) return; 
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      final newState = state.copyWith(lastSyncTime: DateTime.now().toUtc());
      firestore.updateTimerState(newState.toJson());
    }
  }

  void _saveLocally() {
    ref.read(storageServiceProvider).saveTimerState(state.toJson());
  }

  void forceSync() {
    ref.invalidate(cloudTimerProvider);
    final currentCloud = ref.read(cloudTimerProvider).value;
    if (currentCloud != null) _syncFromRemote(TimerState.fromJson(currentCloud));
  }

  void disposeTimer() {
    _timer?.cancel();
  }

  void requestBackgroundSync() {
    if (kIsWeb) return;
    try {
      FlutterBackgroundService().invoke('requestSync');
      // On resume, also double check if service is alive
      _restartServiceIfNeeded();
    } catch (_) {}
  }

  Future<void> _restartServiceIfNeeded() async {
    if (kIsWeb) return;
    final service = FlutterBackgroundService();
    final bool isRunning = await service.isRunning();
    if (state.isRunning && !isRunning) {
      debugPrint('TimerNotifier: Zombie detected! Restarting killed background service...');
      // Ensure handoff buffer is fresh before starting
      _syncToBackground();
      await service.startService();
    }
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);
