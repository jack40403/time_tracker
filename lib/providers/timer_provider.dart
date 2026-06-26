import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:uuid/uuid.dart';
import '../models/time_session.dart';
import '../models/active_timer_record.dart';
import 'storage_provider.dart';
import 'session_provider.dart';
import 'firestore_provider.dart';
import 'category_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/background_timer_service.dart';
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
  final DateTime? sessionStartTime;
  final String status;
  final String? recordId;
  final String? deviceId;
  final String? startDeviceId;
  final String? workspaceId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final String? note;
  final DateTime? updatedAt;

  const TimerState({
    this.isRunning = false,
    this.category = '撠?豢??',
    this.startTime,
    this.baseSeconds = 0,
    this.lastSyncTime,
    this.sessionStartTime,
    this.status = 'idle',
    this.recordId,
    this.deviceId,
    this.startDeviceId,
    this.workspaceId,
    this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.note,
    this.updatedAt,
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
    DateTime? sessionStartTime,
    String? status,
    String? recordId,
    String? deviceId,
    String? startDeviceId,
    String? workspaceId,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? note,
    DateTime? updatedAt,
  }) {
    return TimerState(
      isRunning: isRunning ?? this.isRunning,
      category: category ?? this.category,
      startTime: startTime ?? this.startTime,
      baseSeconds: baseSeconds ?? this.baseSeconds,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      status: status ?? this.status,
      recordId: recordId ?? this.recordId,
      deviceId: deviceId ?? this.deviceId,
      startDeviceId: startDeviceId ?? this.startDeviceId,
      workspaceId: workspaceId ?? this.workspaceId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'isRunning': isRunning,
        'category': category,
        'startTime': startTime?.toUtc().toIso8601String(),
        'baseSeconds': baseSeconds,
        'lastSyncTime': lastSyncTime?.toUtc().toIso8601String(),
        'sessionStartTime': sessionStartTime?.toUtc().toIso8601String(),
        'status': status,
        'recordId': recordId,
        'deviceId': deviceId,
        'startDeviceId': startDeviceId,
        'workspaceId': workspaceId,
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'endedAt': endedAt?.toUtc().toIso8601String(),
        'durationSeconds': durationSeconds,
        'note': note,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };

  factory TimerState.fromJson(Map<String, dynamic> json) => TimerState(
        isRunning: json['isRunning'] ?? false,
        category: json['category'] ?? '撠?豢??',
        startTime: json['startTime'] != null ? DateTime.parse(json['startTime']).toUtc() : null,
        baseSeconds: json['baseSeconds'] ?? 0,
        lastSyncTime: json['lastSyncTime'] != null ? DateTime.parse(json['lastSyncTime']).toUtc() : null,
        sessionStartTime: json['sessionStartTime'] != null
            ? DateTime.parse(json['sessionStartTime']).toUtc()
            : (json['startTime'] != null ? DateTime.parse(json['startTime']).toUtc() : null),
        status: json['status']?.toString() ?? (json['isRunning'] == true ? 'running' : 'idle'),
        recordId: json['recordId']?.toString(),
        deviceId: json['deviceId']?.toString(),
        startDeviceId: json['startDeviceId']?.toString() ?? json['deviceId']?.toString(),
        workspaceId: json['workspaceId']?.toString(),
        startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']).toUtc() : null,
        endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']).toUtc() : null,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        note: json['note']?.toString(),
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']).toUtc() : null,
      );
}

class TimerNotifier extends Notifier<TimerState> {
  Timer? _timer;
  bool _isSyncingFromCloud = false;
  bool _isFinalizingStop = false;
  DateTime? _lastManualActionTime;
  String? _cachedDeviceId;

  String get debugId {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return '?';
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

  String get _deviceId {
    _cachedDeviceId ??= ref.read(storageServiceProvider).loadOrCreateDeviceId();
    return _cachedDeviceId!;
  }

  Map<String, dynamic> _activeRecordPayload({
    required String status,
    DateTime? stoppedAt,
    int? durationSeconds,
    String? note,
  }) {
    final nowUtc = DateTime.now().toUtc();
    final effectiveStart = state.startedAt ?? state.sessionStartTime ?? state.startTime ?? nowUtc;
    final effectiveDuration = durationSeconds ?? (state.isRunning ? state.currentElapsed : state.baseSeconds);
    final recordId = state.recordId ?? const Uuid().v4();
    final startDeviceId = state.startDeviceId ?? state.deviceId ?? _deviceId;
    final payload = ActiveTimerRecord(
      recordId: recordId,
      userId: ref.read(firestoreServiceProvider)?.userId ?? '',
      workspaceId: state.workspaceId,
      startDeviceId: startDeviceId,
      deviceId: _deviceId,
      category: state.category,
      status: status,
      startedAt: effectiveStart,
      endedAt: stoppedAt,
      durationSeconds: effectiveDuration < 0 ? 0 : effectiveDuration,
      updatedAt: stoppedAt ?? nowUtc,
      note: note ?? state.note,
    );
    return {
      ...payload.toJson(),
      'isRunning': status == 'running',
      'baseSeconds': status == 'running' ? state.currentElapsed : state.baseSeconds,
      'startTime': effectiveStart.toIso8601String(),
      'sessionStartTime': effectiveStart.toIso8601String(),
    };
  }

  Future<void> _writeActiveRecordToCloud({required String status, String? note}) async {
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;
    final payload = _activeRecordPayload(
      status: status,
      note: note,
    );
    debugPrint('TimerNotifier: Writing active timer state -> status=$status recordId=${payload['recordId']} category=${payload['category']} device=${payload['deviceId']}');
    await firestore.upsertActiveTimerState(payload);
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

      // ?靽桀儔嚗蜓???蝡臬?憪潘??踹? listen ?舫?撌脣??函?敹怎
      Future.microtask(() async {
        try {
          final serverState = await firestore.fetchActiveTimerState(fromServer: true);
          if (serverState != null) {
            _syncFromRemote(TimerState.fromJson(serverState));
            return;
          }
        } catch (e) {
          debugPrint('TimerNotifier: server-first timer sync failed, falling back to stream/cache: $e');
        }

        final current = ref.read(cloudTimerProvider);
        if (current.hasValue && current.value != null) {
          _syncFromRemote(TimerState.fromJson(current.value!));
        }
      });
    }

    if (localJson != null) {
      final local = TimerState.fromJson(localJson);
      final currentCloud = ref.read(cloudTimerProvider);
      final cloudState = currentCloud.hasValue && currentCloud.value != null
          ? TimerState.fromJson(currentCloud.value!)
          : null;

      if (cloudState == null && local.isRunning) {
        // ZOMBIE RECOVERY AGE CHECK: If the start time is too old (e.g. > 12 hours),
        // it's likely a zombie state from a crash. Don't auto-restart.
        bool isTooOld = false;
        if (local.startTime != null) {
          final age = DateTime.now().toUtc().difference(local.startTime!).inHours;
          if (age > 12) isTooOld = true;
        }

        if (!isTooOld) {
          Future.microtask(() => _startTicker());
          // ZOMBIE RECOVERY: Ensure service is actually running if state says so
          Future.microtask(() => _restartServiceIfNeeded());
        } else {
          debugPrint('TimerNotifier: Detected very old zombie state (>12h). Not restarting.');
          // Reset state to avoid repeated detection
          Future.microtask(() => resetTimer());
        }
      } else if (cloudState != null && local.isRunning && !cloudState.isRunning) {
        debugPrint('TimerNotifier: Cloud is paused; skipping local auto-restart.');
        _timer?.cancel();
      }
      
      // Ensure initial widget sync
      Future.microtask(() => _syncToWidget());
    }

    // Listen for background service events (Android Notification Actions) ALWAYS
    if (!kIsWeb) {
      FlutterBackgroundService().on('statusChange').listen((event) {
        if (event != null && !kIsWeb) {
          if (_isFinalizingStop) return;
          final bool remoteRunning = event['isRunning'];
          final int remoteSeconds = event['currentElapsed'];
          
          if (remoteRunning != state.isRunning) {
            if (remoteRunning) {
              state = state.copyWith(
                isRunning: true, 
                startTime: DateTime.now().toUtc().subtract(Duration(seconds: remoteSeconds)),
                baseSeconds: 0,
                sessionStartTime: state.sessionStartTime ?? DateTime.now().toUtc().subtract(Duration(seconds: remoteSeconds)),
                status: 'running',
                durationSeconds: remoteSeconds,
              );
              _startTicker();
            } else {
              if (_isFinalizingStop) return;
              _timer?.cancel();

              state = state.copyWith(
                isRunning: false,
                baseSeconds: remoteSeconds,
                startTime: null,
                status: remoteSeconds > 0 ? 'paused' : 'idle',
                durationSeconds: remoteSeconds,
              );
            }
            unawaited(_pushToCloud());
          }
        }
      });

      FlutterBackgroundService().on('stopFromNotification').listen((event) {
        unawaited(stopAndSave());
      });
    }

    final currentCloud = ref.read(cloudTimerProvider);
    if (currentCloud.hasValue && currentCloud.value != null) {
      return TimerState.fromJson(currentCloud.value!);
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

    final localUpdatedAt = state.updatedAt;
    final remoteUpdatedAt = remote.updatedAt;
    if (remote.isRunning &&
        localUpdatedAt != null &&
        remoteUpdatedAt != null &&
        remoteUpdatedAt.isBefore(localUpdatedAt) &&
        state.status == 'stopped') {
      debugPrint('TimerNotifier: Ignoring stale running cloud timer state. remoteUpdatedAt=$remoteUpdatedAt localUpdatedAt=$localUpdatedAt');
      return;
    }

    if (_lastManualActionTime != null) {
      if (DateTime.now().difference(_lastManualActionTime!).inSeconds < 3) return;
    }

    final bool shouldSync = remote.status == 'stopped' ||
        remote.status != state.status ||
        remote.category != state.category ||
        (remote.isRunning && remote.startTime != null && !remote.startTime!.isAtSameMomentAs(state.startTime ?? DateTime(0))) ||
        remote.baseSeconds != state.baseSeconds;
        
    if (shouldSync) {
      debugPrint('TimerNotifier: Syncing from Cloud...');
      _isSyncingFromCloud = true;
      state = remote;
      if (remote.isRunning) {
        _startTicker();
      } else {
        _timer?.cancel();
      }
      _isSyncingFromCloud = false;
    }
  }

  void _syncToBackground() async {
    if (kIsWeb) return;
    try {
      final timerStartedAtEpochMs = state.isRunning
          ? (state.startTime ?? state.startedAt)?.millisecondsSinceEpoch
          : null;
      final timerStateLabel = state.isRunning
          ? '正在計時'
          : (state.currentElapsed > 0 ? '計時已暫停' : '計時準備中');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bg_handoff_state', jsonEncode({
        'seconds': state.currentElapsed,
        'category': state.category,
        'isRunning': state.isRunning,
        'isTimerActive': state.isRunning || state.currentElapsed > 0,
        'timerStateLabel': timerStateLabel,
        'timerStartedAtEpochMs': timerStartedAtEpochMs,
      }));

      FlutterBackgroundService().invoke('setTimerData', {
        'seconds': state.currentElapsed,
        'category': state.category,
        'isRunning': state.isRunning,
        'isTimerActive': state.isRunning || state.currentElapsed > 0,
        'timerStateLabel': timerStateLabel,
        'timerStartedAtEpochMs': timerStartedAtEpochMs,
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
        unawaited(_pushToCloud());
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
    state = state.copyWith(
      isRunning: false,
      category: newCategory,
      startTime: null,
      baseSeconds: 0,
      status: 'idle',
      durationSeconds: 0,
    );
    unawaited(_pushToCloud());
  }

  void resetState() {
    _timer?.cancel();
    state = const TimerState();
  }

  void handleCategoryRename(String oldCat, String newCat) {
    if (state.category == oldCat) {
      state = state.copyWith(category: newCat);
      _syncToWidget();
      unawaited(_pushToCloud());
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
        fallback = '撠?豢??';
      }
      
      debugPrint('TimerNotifier: Switching fallback to: "$fallback"');
      state = TimerState(category: fallback);
      unawaited(_pushToCloud());
    }
  }

  void toggleTimer() {
    _lastManualActionTime = DateTime.now();
    // Avoid system haptics here because some Bluetooth media routes treat
    // feedback events as an interruption and pause playback.

    if (state.isRunning) {
      final snapshot = state;
      _timer?.cancel();

      final totalElapsed = snapshot.currentElapsed;
      state = snapshot.copyWith(
        isRunning: false,
        baseSeconds: totalElapsed,
        startTime: null,
        status: 'paused',
        durationSeconds: totalElapsed,
        recordId: snapshot.recordId ?? const Uuid().v4(),
        startedAt: snapshot.startedAt ?? snapshot.sessionStartTime ?? snapshot.startTime ?? DateTime.now().toUtc(),
        deviceId: _deviceId,
        startDeviceId: snapshot.startDeviceId ?? snapshot.deviceId ?? _deviceId,
      );
      if (kIsWeb) {
        MediaSessionService.setPlaybackState(false);
        MediaSessionService.updateMetadata(snapshot.category, '00:00');
      }
    } else {
      final nowUtc = DateTime.now().toUtc();
      final isResumingPausedRecord = state.status == 'paused' && state.recordId != null;
      final recordId = isResumingPausedRecord ? state.recordId! : const Uuid().v4();
      final startedAt = isResumingPausedRecord
          ? (state.startedAt ?? state.sessionStartTime ?? nowUtc)
          : nowUtc;
      state = state.copyWith(
        isRunning: true,
        startTime: nowUtc,
        sessionStartTime: isResumingPausedRecord ? (state.sessionStartTime ?? startedAt) : nowUtc,
        status: 'running',
        recordId: recordId,
        deviceId: _deviceId,
        startDeviceId: isResumingPausedRecord
            ? (state.startDeviceId ?? state.deviceId ?? _deviceId)
            : _deviceId,
        startedAt: startedAt,
        durationSeconds: state.baseSeconds,
      );
      if (!kIsWeb) {
        try {
          unawaited(ensureBackgroundTimerServiceRunning());
        } catch (e) {
          debugPrint('TimerNotifier: startService failed: $e');
        }
      }
      _startTicker();
    }
    _syncToBackground();
    _syncToLiveActivity();
    _syncToWidget();
    unawaited(_pushToCloud());
  }

  Future<void> stopAndSave({String? note}) async {
    _isFinalizingStop = true;
    final snapshot = state;
    _timer?.cancel();

    try {
      final firestore = ref.read(firestoreServiceProvider);
      final stoppedAt = DateTime.now().toUtc();
      Map<String, dynamic>? authoritativeRecord;
      if (firestore != null) {
        try {
          authoritativeRecord = await firestore.stopActiveTimerRecord(
            deviceId: _deviceId,
            workspaceId: snapshot.workspaceId,
            stoppedAt: stoppedAt,
            note: note,
          );
        } catch (e) {
          debugPrint('TimerNotifier: stopActiveTimerRecord failed, falling back to local snapshot: $e');
        }
      }

      final record = authoritativeRecord ?? _activeRecordPayload(
        status: 'stopped',
        stoppedAt: stoppedAt,
        durationSeconds: snapshot.currentElapsed,
        note: note,
      );
      final recordData = ActiveTimerRecord.fromJson(record);
      final duration = recordData.durationSeconds > 0 ? recordData.durationSeconds : snapshot.currentElapsed;
      debugPrint(
        'TimerNotifier: stop finalized -> recordId=${recordData.recordId} '
        'startDeviceId=${recordData.startDeviceId} stopDeviceId=$_deviceId '
        'duration=$duration startedAt=${recordData.startedAt.toUtc().toIso8601String()}',
      );
      if (duration > 0) {
        final session = TimeSession(
          category: snapshot.category,
          durationSeconds: duration,
          date: recordData.startedAt.toLocal(),
          note: note,
        );
        await ref.read(sessionsProvider.notifier).addSession(session);
      }
      if (kIsWeb) {
        MediaSessionService.setPlaybackState(false);
        MediaSessionService.updateMetadata(snapshot.category, '00:00');
      }
      state = TimerState(category: snapshot.category);
      if (!kIsWeb) {
        unawaited(stopBackgroundTimerService());
      }
      _syncToLiveActivity();
      _syncToWidget();
      _saveLocally();
    } finally {
      _isFinalizingStop = false;
    }
  }

  void resetTimer() {
    _timer?.cancel();
    state = state.copyWith(
      isRunning: false,
      baseSeconds: 0,
      startTime: null,
      status: 'idle',
      durationSeconds: 0,
    );
    if (kIsWeb) {
      MediaSessionService.setPlaybackState(false);
      MediaSessionService.updateMetadata(state.category, '00:00');
    }
    _syncToBackground();
    _syncToLiveActivity();
    _syncToWidget();
    unawaited(_pushToCloud());
  }

  Future<void> _pushToCloud() async {
    _saveLocally();
    if (_isSyncingFromCloud) return;
    if (state.status == 'stopped' || (!state.isRunning && state.currentElapsed <= 0)) return;
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore != null) {
      final nowUtc = DateTime.now().toUtc();
      final newState = state.copyWith(
        lastSyncTime: nowUtc,
        updatedAt: nowUtc,
        deviceId: _deviceId,
        startDeviceId: state.startDeviceId ?? state.deviceId ?? _deviceId,
        recordId: state.recordId ?? const Uuid().v4(),
        startedAt: state.startedAt ?? state.sessionStartTime ?? state.startTime ?? nowUtc,
        status: state.isRunning ? 'running' : (state.currentElapsed > 0 ? 'paused' : 'idle'),
        durationSeconds: state.currentElapsed,
      );
      await firestore.upsertActiveTimerState(newState.toJson());
    }
  }

  void _saveLocally() {
    ref.read(storageServiceProvider).saveTimerState(state.toJson());
  }

  Future<void> syncTimerFromServer() async {
    if (_isFinalizingStop) return;
    final firestore = ref.read(firestoreServiceProvider);
    if (firestore == null) return;

    try {
      final serverState = await firestore.fetchActiveTimerState(fromServer: true);
      if (serverState == null) {
        debugPrint('TimerNotifier: Server reports no active timer. Resetting local state.');
        _timer?.cancel();
        state = TimerState(category: state.category);
        _saveLocally();
        _syncToBackground();
        _syncToWidget();
        if (!kIsWeb) {
          try {
            await stopBackgroundTimerService();
          } catch (e) {
            debugPrint('TimerNotifier: stopService after empty server sync failed: $e');
          }
        }
        return;
      }

      final remote = TimerState.fromJson(serverState);
      _syncFromRemote(remote);

      if (!remote.isRunning && !kIsWeb) {
        try {
          await stopBackgroundTimerService();
        } catch (e) {
          debugPrint('TimerNotifier: stopService after remote stop failed: $e');
        }
      }
    } catch (e) {
      debugPrint('TimerNotifier: syncTimerFromServer failed: $e');
    }
  }

  Future<void> forceSync() async {
    await syncTimerFromServer();
  }

  void disposeTimer() {
    _timer?.cancel();
  }

  void requestBackgroundSync() {
    if (kIsWeb) return;
    if (_isFinalizingStop) return;
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
      await ensureBackgroundTimerServiceRunning();
    }
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(
  () => TimerNotifier(),
);
