import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateInfo {
  final bool isUpdateAvailable;
  final String? newVersion;
  final String? currentVersion;
  final bool isPatch; // True for Shorebird, false for Web/Full
  final bool isReadyToRestart; // True if patch is downloaded and ready

  UpdateInfo({
    required this.isUpdateAvailable,
    this.newVersion,
    this.currentVersion,
    this.isPatch = false,
    this.isReadyToRestart = false,
  });
}

class UpdateService extends Notifier<UpdateInfo?> {
  final _shorebird = ShorebirdUpdater();
  static const _webVersionUrl = 'app_version.json'; // Relative to index.html
  static const _localVersionKey = 'last_known_web_version';

  @override
  UpdateInfo? build() => null;

  Future<void> checkUpdates({bool showNotification = false}) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentFullVersion = '${packageInfo.version}+${packageInfo.buildNumber}';

    if (kIsWeb) {
      await _checkWebUpdate(currentFullVersion);
    } else if (_shorebird.isAvailable) {
      await _checkShorebirdUpdate(currentFullVersion);
    }
  }

  Future<void> _checkWebUpdate(String currentVersion) async {
    try {
      // Use cache buster to avoid getting old version.json
      final response = await http.get(Uri.parse('$_webVersionUrl?t=${DateTime.now().millisecondsSinceEpoch}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final serverVersion = data['version'] as String;
        
        final prefs = await SharedPreferences.getInstance();
        final localStored = prefs.getString(_localVersionKey) ?? currentVersion;

        if (serverVersion != localStored) {
          state = UpdateInfo(
            isUpdateAvailable: true,
            newVersion: serverVersion,
            currentVersion: localStored,
            isPatch: false,
          );
        }
      }
    } catch (e) {
      debugPrint('UpdateService: Web update check failed: $e');
    }
  }

  Future<void> _checkShorebirdUpdate(String currentVersion) async {
    try {
      final status = await _shorebird.checkForUpdate();
      if (status == UpdateStatus.restartRequired) {
        state = UpdateInfo(
          isUpdateAvailable: true,
          newVersion: 'Patch 已準備就緒', 
          currentVersion: currentVersion,
          isPatch: true,
          isReadyToRestart: true,
        );
      } else if (status == UpdateStatus.outdated) {
        state = UpdateInfo(
          isUpdateAvailable: true,
          newVersion: '發現新熱更新補丁', 
          currentVersion: currentVersion,
          isPatch: true,
          isReadyToRestart: false,
        );
      }
    } catch (e) {
      debugPrint('UpdateService: Shorebird update check failed: $e');
    }
  }

  Future<void> performUpdate() async {
    if (state == null || !state!.isUpdateAvailable) return;

    if (state!.isPatch) {
      if (state!.isReadyToRestart) {
        // Handled by UI showing Restart button
        return;
      }
      // Mobile Shorebird update download
      debugPrint('UpdateService: Downloading Shorebird Patch...');
      await _shorebird.update();
      // Re-check after update to set isReadyToRestart
      await checkUpdates();
    } else {
      // Web Update: Save new version to avoid infinite prompt and reload
      final prefs = await SharedPreferences.getInstance();
      if (state!.newVersion != null) {
        await prefs.setString(_localVersionKey, state!.newVersion!);
      }
      // UI will handle reload
    }
  }
}

final updateProvider = NotifierProvider<UpdateService, UpdateInfo?>(() => UpdateService());
