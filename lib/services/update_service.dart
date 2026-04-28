import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateInfo {
  final String version;
  final String buildNumber;
  final String url;
  final String changelog;

  UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.url,
    required this.changelog,
  });

  // 為了與 SettingsPage 相容所增加的 Getter
  // 為了與 SettingsPage 相容所增加的實用屬性
  bool get isUpdateAvailable {
    // 這裡只是作為封裝，實際比對邏輯在 checkUpdate 中完成
    // 但如果在其它地方使用，這裡應該反應真實狀態
    return true; 
  }
  
  bool get isPatch => false;
  String get newVersion => version;
  bool get isReadyToRestart => false;
  
  // 支援直接下載 URL 的偵測
  String get downloadUrl => url;

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] ?? '1.0.0',
      // 同時支援 build 與 buildNumber 欄位以增強相容性
      buildNumber: (json['buildNumber'] ?? json['build'] ?? '0').toString(),
      url: json['url'] ?? 'https://metimegoalgoal.web.app/',
      changelog: json['changelog'] ?? '系統優化與穩定性提升',
    );
  }
}

class UpdateService {
  static const _ignoreKey = 'update_ignore_date';
  static const _versionUrl = 'https://metimegoalgoal.web.app/version.json';

  static Future<UpdateInfo?> checkUpdate({bool force = false}) async {
    try {
      // 1. 檢查今天是否已經忽略過 (如果是手動強制檢查則跳過)
      final prefs = await SharedPreferences.getInstance();
      final ignoreDate = prefs.getString(_ignoreKey);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (!force && ignoreDate == today) return null;

      // 2. 獲取本地版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // 3. 獲取遠端版本 (加入時間戳強制繞過快取)
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final bustUrl = '$_versionUrl?t=$timestamp';
      final response = await http.get(Uri.parse(bustUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final remoteInfo = UpdateInfo.fromJson(data);
        final remoteBuildNumber = int.tryParse(remoteInfo.buildNumber) ?? 0;

        // 4. 比對版號 (遠端 > 本地 則建議更新)
        if (remoteBuildNumber > currentBuildNumber) {
          return remoteInfo;
        }
      }
    } catch (e) {
      debugPrint('UpdateService Error: $e');
    }
    return null;
  }

  static Future<void> ignoreToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_ignoreKey, today);
  }

  static void showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Colors.blue),
            SizedBox(width: 10),
            Text('發現新版本！'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: ${info.version} (Build ${info.buildNumber})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('更新內容:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            Text(info.changelog),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ignoreToday();
              Navigator.pop(ctx);
            },
            child: const Text('今日不再提醒', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse(info.url), mode: LaunchMode.externalApplication),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('立即下載更新'),
          ),
        ],
      ),
    );
  }
}


final updateProvider = NotifierProvider<UpdateNotifier, UpdateState>(() {
  return UpdateNotifier();
});

class UpdateState {
  final UpdateInfo? info;
  final bool isChecking;
  final String? error;

  UpdateState({this.info, this.isChecking = false, this.error});

  bool get isUpdateAvailable => info != null;
}

class UpdateNotifier extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    return UpdateState();
  }

  Future<void> checkUpdates({bool force = false}) async {
    state = UpdateState(isChecking: true);
    try {
      final info = await UpdateService.checkUpdate(force: force);
      state = UpdateState(info: info, isChecking: false);
    } catch (e) {
      state = UpdateState(isChecking: false, error: e.toString());
    }
  }

  Future<void> performUpdate() async {
    if (state.info != null) {
      debugPrint('UpdateNotifier: Launching update URL: ${state.info!.url}');
      final uri = Uri.parse(state.info!.url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
