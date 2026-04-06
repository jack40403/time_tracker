import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../providers/goal_provider.dart';
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
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('導入 Jiffy JSON 數據'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('請貼上從 Jiffy 導出的 JSON 內容：', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '{ "time_entries": [...], "time_owners": [...] }',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final jsonStr = textController.text.trim();
              if (jsonStr.isEmpty) return;
              
              Navigator.pop(ctx);
              
              final sessions = JiffyImportService.parseJiffyJson(jsonStr);
              if (sessions.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ 解析失敗：請確認 JSON 格式正確'), behavior: SnackBarBehavior.floating));
                return;
              }
              
              final count = await ref.read(sessionsProvider.notifier).importSessions(sessions);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 成功導入 $count 筆新紀錄！'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
              }
            },
            child: const Text('執行導入'),
          ),
        ],
      ),
    );
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
              ref.read(categoryColorProvider.notifier).resetToTrueZero();
              ref.read(hiddenCategoriesProvider.notifier).clearAll();
              await ref.read(goalProvider.notifier).clearAllGoals();
              ref.read(timerProvider.notifier).resetTimer();
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

  void _showAddCategoryDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增自定義類別'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '輸入類別名稱 (例如: 冥想 🧘)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(categoryColorProvider.notifier).addCategory(name, Colors.blueAccent);
                Navigator.pop(ctx);
              }
            },
            child: const Text('新增項目'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryConfirmDialog(BuildContext context, String cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('刪除類別：$cat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('您要如何處理此類別及其歷史紀錄？', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('🔹 僅刪除標籤 (保留歷史)', style: TextStyle(fontSize: 14)),
            const Text('首頁按鈕會消失，但統計圖表仍會保留過去的追蹤紀錄。', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(height: 24),
            const Text('🔸 徹底刪除 (連同歷史)', style: TextStyle(fontSize: 14, color: Colors.red)),
            Text('此操作會永久刪除所有與 $cat 相關的專注紀錄，無法復原。', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ref.read(categoryColorProvider.notifier).deleteCategory(cat);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 已移除類別按鈕：$cat'), behavior: SnackBarBehavior.floating));
            },
            child: const Text('僅刪除標籤'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ref.read(categoryColorProvider.notifier).hardDeleteCategory(cat);
              ref.read(sessionsProvider.notifier).deleteByCategory(cat);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔥 已徹底清空類別與紀錄：$cat'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            child: const Text('徹底刪除 (不可恢復)'),
          ),
        ],
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('設定', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
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
                onPressed: () => ref.read(authServiceProvider).signOut(),
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
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('正在啟動強制同步...'), duration: Duration(milliseconds: 1000))
                          );
                          try {
                            final error = await ref.read(sessionsProvider.notifier).handleInitialSync();
                            if (mounted) {
                              if (error == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✅ 同步成功！'), 
                                    backgroundColor: Colors.green, 
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(milliseconds: 1500),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('❌ 同步失敗: $error'), 
                                    backgroundColor: Colors.red, 
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
                                  content: Text('❌ 同步發生異常: $e'), 
                                  backgroundColor: Colors.red, 
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(milliseconds: 1500),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.sync, size: 18),
                        label: const Text('手動強制同步'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Divider(indent: 20, endIndent: 20),
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
                  onPressed: () => _showAddCategoryDialog(context),
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
                  for (var entry in catColors.entries)
                    ListTile(
                      onTap: () => showModernColorPicker(context, '設定 ${entry.key} 的顏色', entry.value, (c) => ref.read(categoryColorProvider.notifier).updateColor(entry.key, c)),
                      leading: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: entry.value.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(backgroundColor: entry.value, radius: 8),
                      ),
                      title: Row(
                        children: [
                          Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                          if (hiddenCategories.contains(entry.key))
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                child: const Text('隱藏中', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hiddenCategories.contains(entry.key))
                            IconButton(
                              icon: const Icon(Icons.visibility_off_outlined, size: 18, color: Colors.blue),
                              onPressed: () => ref.read(categoryColorProvider.notifier).addCategory(entry.key, entry.value),
                              tooltip: '取消隱藏',
                            )
                          else
                            const Icon(Icons.palette_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                            onPressed: () => _showDeleteCategoryConfirmDialog(context, entry.key),
                          ),
                        ],
                      ),
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
            onChanged: (v) => ref.read(themeModeProvider.notifier).toggle(v),
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
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.input_rounded, color: Colors.orange, size: 22),
                ),
                title: const Text('導入 Jiffy 數據', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: const Text('由 JSON 文件導入歷史紀錄', style: TextStyle(fontSize: 14)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showImportJiffyDialog(context),
              ),
            ),
          ),
          const Divider(indent: 20, endIndent: 20),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text('危險區域', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: const Text('清空所有計時數據', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text('此操作無法復原，將同步刪除雲端紀錄', style: TextStyle(fontSize: 12)),
                onTap: () => _showClearAllConfirmationDialog(context),
              ),
            ),
          ),
          
          const Divider(indent: 20, endIndent: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.bug_report_outlined, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text('開發者調試工具', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purple.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt_outlined, color: Colors.purple),
                    title: const Text('建立數據快照', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('儲存當前所有本地數據狀態', style: TextStyle(fontSize: 12)),
                    onTap: () async {
                      final prefs = ref.read(storageServiceProvider).prefs;
                      await DebugHelper.createSnapshot(prefs);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📸 快照已建立成功'), behavior: SnackBarBehavior.floating));
                        setState(() {}); // Refresh to show restore button if it was hidden
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    enabled: DebugHelper.hasSnapshot(ref.read(storageServiceProvider).prefs),
                    leading: const Icon(Icons.restore_outlined, color: Colors.purple),
                    title: const Text('還原快照', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('回到上一個儲存的數據版本', style: TextStyle(fontSize: 12)),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('確定要還原嗎？'),
                          content: const Text('這將覆蓋當前所有本地數據，並可能導致雲端同步衝突。建議僅在開發調試時使用。'),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
