import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/cartoon_theme.dart';
import 'package:vibration/vibration.dart';
import '../services/update_service.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/task_goal_provider.dart';
import '../providers/goal_order_provider.dart';
import '../models/goal.dart';
import '../providers/session_provider.dart';
import '../providers/background_provider.dart';
import '../providers/firestore_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/storage_provider.dart';
import '../helpers/export_helper.dart';
import '../services/import_service.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/category_dialogs.dart';
import '../helpers/debug_helper.dart';
import '../services/backup_service.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType; // 顯式導入關鍵類型
import '../helpers/platform_helper.dart'; // 引入自定義平台輔助
import '../theme/app_themes.dart';
import '../providers/app_theme_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isLoggingIn = false;
  bool _isAnonLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoggingIn = true);
    try {
      final cred = await ref.read(authServiceProvider).signInWithGoogle();
      if (mounted) {
        if (cred != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ 登入成功！'), 
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1500),
            ),
          );
        } else {
          // 使用者可能點擊了外面或關閉了視窗
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ 登入被取消：請確認彈出視窗已完成驗證'), 
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 登入發生錯誤：$e'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1500),
            action: SnackBarAction(label: '查看解決方案', textColor: Colors.white, onPressed: () {
              showDialog(context: context, builder: (ctx) => AlertDialog(
                title: const Text('如何解決登入失敗？'),
                content: const Text('1. 請確認已將 wdttgqq.web.app 加入 Firebase 授權網域。\n2. 請確認 Google Cloud 已設定正確的重新導向 URI。'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('了解'))],
              ));
            }),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  Future<void> _handleAnonymousSignIn() async {
    setState(() => _isAnonLoading = true);
    try {
      await ref.read(authServiceProvider).signInAnonymously();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 登入出錯: $e'), 
            backgroundColor: Colors.red, 
            behavior: SnackBarBehavior.floating,
            duration: Duration(milliseconds: 1500),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAnonLoading = false);
    }
  }

  void _showImportJiffyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.indigo),
            const SizedBox(width: 8),
            const Text('全能數據恢復工具'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('您可以選擇 Elite 通用備份檔案，或是 Jiffy 導出的 JSON 檔案。系統將自動識別並還原數據。', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('💡 建議：匯入大型檔案可能需要幾秒鐘，請耐心等待。', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              _handleUniversalImport(context);
            },
            icon: const Icon(Icons.file_open_rounded),
            label: const Text('從檔案中選取'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUniversalImport(BuildContext context) async {
    try {
      final jsonString = await pickJsonFile();
      if (jsonString == null) return;

      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏳ 正在解析數據檔案...'), duration: Duration(seconds: 2))
        );
      }

      final decoded = jsonDecode(jsonString);

      bool isEliteBackup = decoded is Map<String, dynamic> && 
                         decoded.containsKey('payload') && 
                         decoded['version'] != null;
      
      bool isJiffyBackup = decoded is Map<String, dynamic> && 
                          decoded.containsKey('time_entries');

      if (isEliteBackup) {
        final success = await BackupService(ref).restoreFromBackup(jsonString);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '✅ 全備份恢復成功！' : '❌ 備份恢復失敗'),
              backgroundColor: success ? Colors.green : Colors.red,
            )
          );
        }
      } else if (isJiffyBackup) {
        final sessions = JiffyImportService.parseJiffyJson(jsonString);
        if (sessions.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Jiffy 資料解析結果為空')));
          return;
        }
        final count = await ref.read(sessionsProvider.notifier).importSessions(sessions);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ 成功從 Jiffy 救回 $count 筆紀錄！'),
              backgroundColor: Colors.green,
            )
          );
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 無法識別的 JSON 檔案格式'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ 導入出錯: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showClearAllConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 確定要清空嗎？'),
        content: const Text('這將永久刪除您的所有本地與雲端計時紀錄。此動作將同步抹除 Firebase 數據，且無法復原。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showFinalClearConfirmation(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            child: const Text('下一步'),
          ),
        ],
      ),
    );
  }

  void _showFinalClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🚨 執行全系統歸零'),
        content: const Text('請再次確認：這將會抹除所有專注紀錄、目標設定，並「永久刪除所有項目分類」。完成後 App 將完全空白，需重新手動新增項目。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('考慮一下')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // 執行全量歸零
              await ref.read(sessionsProvider.notifier).clearAll();
              ref.read(categoryColorProvider.notifier).resetState();
              ref.read(hiddenCategoriesProvider.notifier).resetState();
              ref.read(goalProvider.notifier).resetState();
              ref.read(timerProvider.notifier).resetState();
              ref.read(timerColorProvider.notifier).resetToDefault();
              ref.read(backgroundProvider.notifier).reset();
              ref.read(themeModeProvider.notifier).resetToDefault();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔥 全機數據已完全抹除（含項目）'), 
                    backgroundColor: Colors.red, 
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(milliseconds: 2000),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            child: const Text('確定清空，不留痕跡'),
          ),
        ],
      ),
    );
  }

  void _showAddCategory(BuildContext context) {
    showAddCategoryDialog(context, ref);
  }

  void _showArchivedFolderDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final hidden = ref.watch(hiddenCategoriesProvider).toList();
          final catColors = ref.watch(categoryColorProvider);
          
          return Container(
            padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.folder_zip_outlined, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Text('封存項目資料夾', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('這些項目已從全域隱藏。您可以在此將其還原回主清單。', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 20),
                if (hidden.isEmpty)
                   const Padding(
                     padding: EdgeInsets.symmetric(vertical: 40),
                     child: Text('目前資料夾中沒有任何封存項目', style: TextStyle(color: Colors.grey, fontSize: 13)),
                   )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: hidden.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 40),
                      itemBuilder: (ctx, index) {
                        final cat = hidden[index];
                        final color = catColors[cat] ?? Colors.grey;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: CircleAvatar(backgroundColor: color, radius: 8),
                          title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w500)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  ref.read(hiddenCategoriesProvider.notifier).unhideCategory(cat);
                                  if (hidden.length <= 1) Navigator.pop(ctx);
                                },
                                icon: const Icon(Icons.unarchive_outlined, size: 18),
                                label: const Text('還原'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                                onPressed: () => showDeleteConfirmDialog(context, cat, ref),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final authUser = ref.watch(authStateProvider).value;
    final catColors = ref.watch(categoryColorProvider);
    final hiddenCategories = ref.watch(hiddenCategoriesProvider);
    final timerColor = ref.watch(timerColorProvider);
    final visibleEntries = catColors.entries.where((e) => !hiddenCategories.contains(e.key)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CartoonAppBar(title: '設定 ⚙️'),
      body: ListView(
        children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('帳戶與同步', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            ),
          if (authUser == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('啟用雲端備份', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text('登入後即可在多台裝置間同步資料', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoggingIn)
                           const CircularProgressIndicator()
                        else ...[
                           ElevatedButton.icon(
                            onPressed: _handleGoogleSignIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Google 登入'),
                          ),
                          const SizedBox(width: 12),
                          if (_isAnonLoading)
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            ElevatedButton.icon(
                              onPressed: _handleAnonymousSignIn,
                              icon: const Icon(Icons.account_circle_outlined),
                              label: const Text('訪客測試 (跳過認證)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.withOpacity(0.15),
                                foregroundColor: Colors.orange,
                                elevation: 0,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          if (authUser != null) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: CircleAvatar(
                radius: 24,
                backgroundImage: authUser.photoURL != null ? NetworkImage(authUser.photoURL!) : null,
                child: authUser.photoURL == null ? const Icon(Icons.person) : null,
              ),
              title: Text(authUser.displayName ?? '已登入用戶', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(authUser.email ?? '', style: const TextStyle(fontSize: 15)),
              trailing: TextButton(
                onPressed: () => _handleLogout(context, ref),
                child: const Text('登出', style: TextStyle(color: Colors.red)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text('同步診斷', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('用戶識別碼 (UID)'),
                        Text((authUser?.uid ?? '').substring(0, 8) + '...', style: GoogleFonts.shareTechMono(fontSize: 12, color: Colors.blue)),
                      ],
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('雲端紀錄數'),
                        Text('${ref.watch(cloudSessionsProvider).value?.length ?? 0} 筆', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('本地紀錄數'),
                        Text('${ref.watch(sessionsProvider).length} 筆', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      child: Column(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🔄 正在同步雲端數據 (包含目標與歷史)...'), duration: Duration(seconds: 2))
                              );
                              try {
                                final firestore = ref.read(firestoreServiceProvider);
                                if (firestore == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 請先登入雲端帳戶')));
                                  return;
                                }
                                
                                // 1. 強制讀取計時紀錄
                                await ref.read(sessionsProvider.notifier).forceSyncFromCloud();
                                
                                // 2. 強制讀取時間型目標
                                final timeGoalsData = await firestore.fetchGoalsOnce();
                                if (timeGoalsData.isNotEmpty) {
                                  final remote = timeGoalsData.map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList();
                                  ref.read(goalProvider.notifier).forceMergeFromCloud(remote);
                                }
                                
                                // 3. 強制讀取任務型目標
                                final taskGoalsData = await firestore.fetchTaskGoalsOnce();
                                if (taskGoalsData.isNotEmpty) {
                                  final remote = taskGoalsData.map((e) => Goal.fromJson(e as Map<String, dynamic>)).toList();
                                  ref.read(taskGoalProvider.notifier).forceMergeFromCloud(remote);
                                }

                                if (mounted) {
                                  final totalSessions = ref.read(sessionsProvider).length;
                                  final totalGoals = ref.read(goalProvider).length + ref.read(taskGoalProvider).length;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('✅ 同步完成！共 $totalSessions 筆紀錄與 $totalGoals 個目標'), 
                                    backgroundColor: Colors.green, 
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 3),
                                  ));
                                }
                              } catch (e) {
                                if (mounted) {
                                  String errorMsg = e.toString();
                                  if (errorMsg.contains('unavailable') || errorMsg.contains('deadline')) {
                                    errorMsg = '網路訊號不穩定，請移動到收訊較好的地方再試一次 (或是檢查網路連接)';
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('❌ 同步失敗: $errorMsg'), 
                                    backgroundColor: Colors.red, 
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ));
                                }
                              }
                            },
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('手動強制同步'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Divider(indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.system_update_alt_outlined, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                Text('應用程式更新', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                   Consumer(
                    builder: (context, ref, _) {
                      final updateState = ref.watch(updateProvider);
                      final isChecking = updateState.isChecking;
                      final hasUpdate = updateState.isUpdateAvailable;
                      
                      return FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final version = snapshot.data?.version ?? '1.0.0';
                          final buildNumber = snapshot.data?.buildNumber ?? '1';
                          
                          return Column(
                            children: [
                              ListTile(
                                leading: isChecking 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Icon(hasUpdate ? Icons.system_update_rounded : Icons.info_outline, color: hasUpdate ? Colors.orange : Colors.indigo),
                                title: Row(
                                  children: [
                                    Text(hasUpdate ? '發現新版本' : '目前版本', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    if (!hasUpdate) Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                      child: const Text('正式版', style: TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasUpdate ? 'v${updateState.info!.version} (Build ${updateState.info!.buildNumber})' : 'v$version (Build $buildNumber)',
                                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: hasUpdate ? Colors.orange : Colors.indigo.shade700),
                                    ),
                                    Text(
                                      isChecking ? '正在檢查雲端版本...' : (hasUpdate ? '發現一項重要更新' : '已是最新版本'), 
                                      style: TextStyle(fontSize: 12, color: hasUpdate ? Colors.orange : Colors.grey)
                                    ),
                                  ],
                                ),
                                trailing: OutlinedButton(
                                  onPressed: isChecking ? null : () async {
                                    Vibration.vibrate(duration: 50);
                                    await ref.read(updateProvider.notifier).checkUpdates(force: true);
                                    final status = ref.read(updateProvider);
                                    if (mounted) {
                                      if (!status.isUpdateAvailable && status.error == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('✅ 目前已是最新版本'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)
                                        );
                                      }
                                    }
                                  },
                                  child: Text(isChecking ? '檢查中' : '檢查更新'),
                                ),
                              ),
                              if (hasUpdate)
                                Container(
                                  margin: const EdgeInsets.all(12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              updateState.info!.changelog,
                                              style: const TextStyle(fontSize: 13, color: Colors.orange),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            Vibration.vibrate(duration: 100);
                                            if (kIsWeb) {
                                              await ref.read(updateProvider.notifier).performUpdate();
                                              reloadApp();
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('📥 正在啟動一鍵下載...'), duration: Duration(seconds: 2))
                                              );
                                              await ref.read(updateProvider.notifier).performUpdate();
                                            }
                                          },
                                          icon: const Icon(Icons.download_for_offline_rounded),
                                          label: Text(kIsWeb ? '立即重新整理' : '一鍵下載並安裝最新版'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange, 
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const Divider(indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.storage_outlined, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Text('資料管理與備份', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.backup_outlined, color: Colors.teal),
                    title: const Text('匯出完整備份 (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('包含分類、計時紀錄與目標設定', style: TextStyle(fontSize: 12)),
                    onTap: () async {
                      final backupService = ref.read(backupServiceProvider(ref));
                      final json = backupService.createFullBackup();
                      final date = DateTime.now().toIso8601String().split('T')[0];
                      await saveAndShareFile(json, 'EliteTracker_Backup_$date.json');
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 備份檔已產生並準備下載/分享')));
                      }
                    },
                  ),
                  const Divider(indent: 70, height: 1),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_rounded, color: Colors.indigo),
                    title: const Text('全能數據匯入與恢復 (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('支援 Elite 備份與 Jiffy 歷史導出檔案', style: TextStyle(fontSize: 12)),
                    onTap: () => _showImportJiffyDialog(context),
                  ),
                  const Divider(indent: 70, height: 1),
                   ListTile(
                    leading: const Icon(Icons.table_chart_outlined, color: Colors.blue),
                    title: const Text('匯出時段日誌 (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('產生人類可讀的計時細節表格', style: TextStyle(fontSize: 12)),
                    onTap: () async {
                      final backupService = ref.read(backupServiceProvider(ref));
                      final csv = backupService.createSessionsCsv();
                      final date = DateTime.now().toIso8601String().split('T')[0];
                      await saveAndShareFile(csv, 'EliteTracker_History_$date.csv');
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📊 CSV 日誌已產生')));
                      }
                    },
                  ),
                  const Divider(indent: 70, height: 1),
                  ListTile(
                    leading: const Icon(Icons.stars_outlined, color: Colors.amber),
                    title: const Text('匯出目標紀錄 (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('包含目標設定與每日達成歷史', style: TextStyle(fontSize: 12)),
                    onTap: () async {
                      final backupService = ref.read(backupServiceProvider(ref));
                      final csv = backupService.createGoalsCsv();
                      final date = DateTime.now().toIso8601String().split('T')[0];
                      await saveAndShareFile(csv, 'EliteTracker_Goals_$date.csv');
                      if (mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎯 目標紀錄 CSV 已產生')));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('🎨 外觀主題', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
          ),
          const _ThemeSelectorCard(),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('客製化外觀', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('自定義背景顏色', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      Row(
                        children: [
                          for (var color in [Colors.blue, Colors.purple, Colors.green, Colors.orange, Colors.pink])
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: InkWell(
                                onTap: () => ref.read(backgroundProvider.notifier).updateColor(color.withOpacity(0.1)),
                                child: CircleAvatar(radius: 12, backgroundColor: color.withOpacity(0.3)),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: IconButton(
                              onPressed: () => showModernColorPicker(context, '選擇自定義背景疊加色', Colors.blue, (c) => ref.read(backgroundProvider.notifier).updateColor(c.withOpacity(0.15))),
                              icon: const Icon(Icons.add_circle_outline, size: 24, color: Colors.blue),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('計時器文字顏色', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      InkWell(
                        onTap: () => showModernColorPicker(context, '選擇計時器顏色', timerColor, (c) => ref.read(timerColorProvider.notifier).updateColor(c)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: timerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: timerColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 8, backgroundColor: timerColor),
                              const SizedBox(width: 8),
                              Text('#${timerColor.value.toRadixString(16).substring(2).toUpperCase()}', style: TextStyle(fontWeight: FontWeight.bold, color: timerColor)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('背景浮水印深淺', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                          Text('${(ref.watch(backgroundProvider).opacity * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      Slider(
                        value: ref.watch(backgroundProvider).opacity,
                        min: 0.05,
                        max: 1.0,
                        divisions: 19,
                        onChanged: (v) => ref.read(backgroundProvider.notifier).updateOpacity(v),
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('自定義背景圖片', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(backgroundProvider.notifier).pickImage(),
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text('選擇圖片'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Divider(indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('類別與顏色管理', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                TextButton.icon(
                  onPressed: () => _showAddCategory(context),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('新增項目'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  for (var entry in visibleEntries)
                    ListTile(
                      onTap: () => showCategoryOptions(context, entry.key, ref),
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: entry.value.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(backgroundColor: entry.value, radius: 8),
                      ),
                      title: Text(
                        entry.key, 
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.more_vert),
                        onPressed: () => showCategoryOptions(context, entry.key, ref),
                      ),
                    ),
                  if (visibleEntries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('目前沒有任何活躍項目', style: TextStyle(color: Colors.grey)),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    onTap: () => _showArchivedFolderDialog(context),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.folder_zip_outlined, color: Colors.blueGrey, size: 16),
                    ),
                    title: const Text('封存項目資料夾', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                    subtitle: Text('目前共有 ${hiddenCategories.length} 個封存項目', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ),

          const Divider(indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('系統與偏好', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: const Text('深色模式'),
            value: themeMode == ThemeMode.dark,
            onChanged: (v) => (ref.read(themeModeProvider.notifier) as dynamic).setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
          ),
          
          const Divider(indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('資料管理', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.download_outlined, color: Colors.green, size: 22),
                ),
                title: const Text('匯出 CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: const Text('將所有專注紀錄匯出為 CSV 檔案', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  final sessions = ref.read(sessionsProvider);
                  if (sessions.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('目前尚無紀錄可匯出'), 
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(milliseconds: 1500),
                      ),
                    );
                    return;
                  }
                  final lines = <String>[];
                  lines.add('日期,時間,分類,時長(分鐘),時長(秒)');
                  final sorted = [...sessions]..sort((a, b) => b.date.compareTo(a.date));
                  for (final s in sorted) {
                    final date = '${s.date.year}-${s.date.month.toString().padLeft(2,'0')}-${s.date.day.toString().padLeft(2,'0')}';
                    final time = '${s.date.hour.toString().padLeft(2,'0')}:${s.date.minute.toString().padLeft(2,'0')}';
                    final mins = (s.durationSeconds / 60).toStringAsFixed(1);
                    lines.add('$date,$time,"${s.category}",$mins,${s.durationSeconds}');
                  }
                  final csvContent = lines.join('\n');
                  final now = DateTime.now();
                  final filename = 'time_tracker_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.csv';
                  
                  exportCSV(csvContent, filename);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ 已匯出 ${sessions.length} 筆紀錄到 $filename'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(indent: 20, endIndent: 20),
          const Divider(indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.settings_suggest_outlined, color: Colors.indigo),
                title: Text('進階系統工具與危險區域', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                subtitle: const Text('包含雲端清理、調試工具與重置選項', style: TextStyle(fontSize: 12)),
                children: [
                  // --- 1. 雲端維護與救援 ---
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_rounded, color: Colors.blue),
                    title: const Text('雲端數據原子級去重', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('掃除重複紀錄並優化雲端空間 (解決數據翻倍問題)', style: TextStyle(fontSize: 11)),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('原子級雲端修復'),
                          content: const Text('此操作將執行深層去重清理：\n1. 從雲端下載所有紀錄\n2. 自動移除重複與格式錯誤的數據\n3. 重置雲端並重新上傳乾淨的副本\n\n適用於解決「數據翻倍」或「同步錯亂」問題。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text('開始修復')),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🚀 啟動原子級修復程式... 請勿關閉 App'), duration: Duration(seconds: 5))
                        );
                        final count = await ref.read(sessionsProvider.notifier).forceCloudCleanup();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ 清理完成！已從雲端移除 $count 筆冗餘紀錄'),
                              backgroundColor: Colors.green,
                            )
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.medical_services_rounded, color: Colors.red),
                    title: const Text('全方位數據救援診斷', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('深度掃描所有可能的雲端路徑以救回遺失資料', style: TextStyle(fontSize: 11)),
                    onTap: () async {
                      final firestore = ref.read(firestoreServiceProvider);
                      if (firestore == null) return;
                      
                      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

                      try {
                        final uid = firestore.userId;
                        final results = <String, dynamic>{};
                        final db = FirebaseFirestore.instance;
                        
                        final List<Map<String, String>> scanTasks = [
                          {'label': 'users/{uid}/sessions', 'path': 'users/$uid/sessions'},
                          {'label': 'user/{uid}/sessions', 'path': 'user/$uid/sessions'},
                          {'label': 'sessions/{uid}', 'path': 'sessions/$uid'},
                          {'label': 'users_v2/{uid}/sessions', 'path': 'users_v2/$uid/sessions'},
                        ];
                        
                        for (var task in scanTasks) {
                          final label = task['label']!;
                          final path = task['path']!;
                          try {
                            final parts = path.split('/');
                            if (parts.length == 2) {
                              final snap = await db.collection(parts[0]).where('userId', isEqualTo: uid).get(GetOptions(source: Source.server));
                              results[label] = snap.docs.length;
                            } else {
                              final snap = await db.collection(parts[0]).doc(parts[1]).collection(parts[2]).get(GetOptions(source: Source.server));
                              results[label] = snap.docs.length;
                            }
                          } catch (e) {
                            results[label] = -2;
                          }
                        }

                        if (mounted) Navigator.pop(context);

                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('數據救援診斷報告'),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: scanTasks.map((t) {
                                    final label = t['label']!;
                                    final count = results[label];
                                    return ListTile(
                                      title: Text(label, style: const TextStyle(fontSize: 10)),
                                      trailing: Text(count == -2 ? '❌' : '$count 筆'),
                                      dense: true,
                                    );
                                  }).toList(),
                                ),
                              ),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉'))],
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: const Icon(Icons.security_rounded, color: Colors.blueGrey),
                    title: const Text('測試雲端寫入權限', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('檢查當前帳號是否有權限寫入 Firestore', style: TextStyle(fontSize: 11)),
                    onTap: () async {
                      final firestore = ref.read(firestoreServiceProvider);
                      if (firestore == null) return;
                      final uid = firestore.userId;
                      final db = FirebaseFirestore.instance;
                      try {
                        await db.collection('users').doc(uid).collection('test_permission').doc('test').set({
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 寫入權限測試成功！'), backgroundColor: Colors.green));
                        }
                      } catch (e) {
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('寫入權限失敗'),
                              content: Text('錯誤訊息: $e'),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('確定'))],
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 50),
                  
                  // --- 2. 開發者工具 ---
                  ListTile(
                    leading: const Icon(Icons.bug_report_outlined, color: Colors.purple),
                    title: const Text('建立數據快照 (Snapshot)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('儲存當前所有本地數據狀態以供還原', style: TextStyle(fontSize: 11)),
                    onTap: () async {
                      final prefs = ref.read(storageServiceProvider).prefs;
                      await DebugHelper.createSnapshot(prefs);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📸 快照已建立成功'), behavior: SnackBarBehavior.floating));
                      }
                    },
                  ),
                  ListTile(
                    enabled: DebugHelper.hasSnapshot(ref.read(storageServiceProvider).prefs),
                    leading: const Icon(Icons.restore_outlined, color: Colors.purple),
                    title: const Text('還原快照', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('回到上一個儲存的數據版本', style: TextStyle(fontSize: 11)),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('確定要還原嗎？'),
                          content: const Text('這將覆蓋當前所有本地數據。建議僅在開發調試時使用。'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final prefs = ref.read(storageServiceProvider).prefs;
                                final success = await DebugHelper.restoreSnapshot(prefs);
                                if (success && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 數據已還原，請重啟應用程式以生效'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                              child: const Text('確定還原'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  // --- 3. 危險區域 ---
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.red.withOpacity(0.05),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('危險區域', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 2)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                          title: const Text('清空計時數據 (Sync)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('同步刪除雲端與本地的所有專注歷史紀錄', style: TextStyle(fontSize: 11)),
                          onTap: () => _showClearAllConfirmationDialog(context),
                        ),
                        const Divider(height: 1, indent: 50, color: Colors.redAccent),
                        ListTile(
                          leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          title: const Text('系統歸一重置 (Master Reset)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('抹除所有紀錄、目標與分類 (需要 RESET 確認)', style: TextStyle(fontSize: 11)),
                          onTap: () => _showResetConfirmation(context, ref),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ 確定要重置所有數據嗎？'),
        content: const Text('這將永久刪除雲端與本地的所有時段記錄、目標設定以及自定義分類，此操作不可撤銷。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showFinalResetGuard(context, ref);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('下一步'),
          ),
        ],
      ),
    );
  }

  void _showFinalResetGuard(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('請再次確認'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('請在下方輸入 "RESET" 以確認執行歸零重置：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'RESET',
                border: OutlineInputBorder(),
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().toUpperCase() == 'RESET') {
                Navigator.pop(ctx);
                await _performMasterReset(context, ref);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('輸入錯誤，操作取消')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('執行歸零重置'),
          ),
        ],
      ),
    );
  }

  Future<void> _performMasterReset(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Wipe Cloud
      final firestore = ref.read(firestoreServiceProvider);
      if (firestore != null) {
        await firestore.clearAllUserData();
      }

      // 2. Wipe Local Storage
      final storage = ref.read(storageServiceProvider);
      await storage.clearAllLocalData();

      // 3. Reset all memory states
      ref.read(goalProvider.notifier).resetState();
      ref.read(taskGoalProvider.notifier).resetState();
      ref.read(sessionsProvider.notifier).resetState();
      ref.read(categoryColorProvider.notifier).resetState();
      ref.read(hiddenCategoriesProvider.notifier).resetState();
      ref.read(timerHiddenCategoriesProvider.notifier).resetState();
      ref.read(goalsHiddenCategoriesProvider.notifier).resetState();
      ref.read(goalOrderProvider.notifier).resetState();
      ref.read(timerProvider.notifier).resetState();

      if (mounted) {
        Navigator.pop(context); // Pop loading
        Navigator.of(context).popUntil((route) => route.isFirst); // Go back home
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ 數據已成功歸零，帳號清空完成'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ 重置失敗: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    // 1. 顯示處理中彈窗
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. 執行最後一次同步 (確保隱私前資料已入雲)
      final firestore = ref.read(firestoreServiceProvider);
      if (firestore != null) {
        await ref.read(sessionsProvider.notifier).syncNow();
        await ref.read(goalProvider.notifier).syncNow();
        await ref.read(taskGoalProvider.notifier).syncNow();
      }

      // 3. 【關鍵安全鎖】先執行正式簽退，斷開與雲端所有連線權限
      await ref.read(authServiceProvider).signOut();

      // 4. 正式斷開後，徹底抹除本地持久化儲存 (此時已無權限誤傷雲端資料)
      final storage = ref.read(storageServiceProvider);
      await storage.clearAllLocalData();

      // 5. 重置各 Provider 的記憶體狀態，立即反映到 UI
      ref.read(sessionsProvider.notifier).resetState();
      ref.read(goalProvider.notifier).resetState();
      ref.read(taskGoalProvider.notifier).resetState();
      ref.read(categoryColorProvider.notifier).resetState();
      ref.read(hiddenCategoriesProvider.notifier).resetState();
      ref.read(timerProvider.notifier).resetState();
      ref.read(timerColorProvider.notifier).resetToDefault();
      ref.read(backgroundProvider.notifier).reset();
      ref.read(themeModeProvider.notifier).resetToDefault();

      // 6. 關閉讀取彈窗並提示
      if (context.mounted) {
        Navigator.pop(context); // 關閉 Loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已安全登出並抹除本地數據'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // 關閉 Loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登出過程發生錯誤: $e')),
        );
      }
    }
  }
}

// ─── Theme selector card ──────────────────────────────────────────────────────

class _ThemeSelectorCard extends ConsumerWidget {
  const _ThemeSelectorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(appThemeIdProvider);
    final currentTheme = ref.watch(currentAppThemeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('目前：', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(
                  currentTheme.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: currentTheme.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kThemeOrder.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final id = kThemeOrder[index];
                  final t = kAppThemes[id]!;
                  final selected = currentId == id;
                  return GestureDetector(
                    onTap: () => ref.read(appThemeIdProvider.notifier).set(id),
                    child: _ThemeSwatch(theme: t, selected: selected),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  final AppTheme theme;
  final bool selected;

  const _ThemeSwatch({required this.theme, required this.selected});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? t.accent : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: selected
            ? [BoxShadow(color: t.accent.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Preview: background + mini card + dot
            Expanded(
              child: Container(
                decoration: t.bgIsGradient
                    ? BoxDecoration(
                        gradient: LinearGradient(
                          begin: t.bgBegin,
                          end: t.bgEnd,
                          colors: t.bgColor3 != const Color(0xFF000000) && t.bgColor3 != t.bgColor1
                              ? [t.bgColor1, t.bgColor2, t.bgColor3]
                              : [t.bgColor1, t.bgColor2],
                        ),
                      )
                    : BoxDecoration(color: t.bgColor1),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 28,
                        decoration: BoxDecoration(
                          color: t.surface,
                          borderRadius: BorderRadius.circular(t.cardRadius / 3),
                          border: t.borderW > 0 ? Border.all(color: t.border, width: 1) : null,
                        ),
                        child: Center(
                          child: Container(
                            width: 16,
                            height: 6,
                            decoration: BoxDecoration(
                              color: t.accent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.action,
                          border: t.borderW > 0 ? Border.all(color: t.border, width: 1) : null,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 2),
                        Icon(Icons.check_circle, size: 10, color: t.accent),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Label
            Container(
              color: t.navBg,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: Text(
                  t.displayName,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: t.navInk,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
