import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/category_provider.dart';

void showAddCategoryDialog(BuildContext context, WidgetRef ref) {
  String newName = '';
  Color selectedColor = const Color(0xFF6C63FF);

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => AlertDialog(
        title: Text('新增項目', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '項目名稱',
                hintText: '例如：工作、讀書、運動...',
              ),
              onChanged: (v) => newName = v,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('顏色', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final picked = await _pickColor(context, selectedColor);
                    if (picked != null) setModalState(() => selectedColor = picked);
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (newName.trim().isNotEmpty) {
                ref.read(categoryColorProvider.notifier).addCategory(newName.trim(), selectedColor);
              }
              Navigator.pop(ctx);
            },
            child: const Text('新增'),
          ),
        ],
      ),
    ),
  );
}

Future<Color?> _pickColor(BuildContext context, Color initialColor) async {
  Color currentColor = initialColor;
  return showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('選擇顏色', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: HueRingPicker(
          pickerColor: initialColor,
          onColorChanged: (c) => currentColor = c,
          enableAlpha: false,
          displayThumbColor: true,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, currentColor),
          child: const Text('確定'),
        ),
      ],
    ),
  );
}

void showCategoryOptions(BuildContext context, String cat, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Consumer(
      builder: (ctx, innerRef, _) {
        final isGlobalHidden = innerRef.watch(hiddenCategoriesProvider).contains(cat);
        final isTimerHidden = innerRef.watch(timerHiddenCategoriesProvider).contains(cat);
        final isGoalsHidden = innerRef.watch(goalsHiddenCategoriesProvider).contains(cat);
        final isStatsHidden = innerRef.watch(statsHiddenCategoriesProvider).contains(cat);
        final isHistoryHidden = innerRef.watch(historyHiddenCategoriesProvider).contains(cat);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('重新命名', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  showRenameDialog(context, cat, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: Colors.indigo),
                title: const Text('更改顏色', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  showColorPickerDialog(context, cat, ref);
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '顯示設定',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                secondary: Icon(isTimerHidden ? Icons.timer_off_outlined : Icons.timer_outlined, color: Colors.orange),
                title: const Text('於「計時器頁面」顯示', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('關閉後，該項目不會出現在計時器頁面。', style: TextStyle(fontSize: 11)),
                value: !isTimerHidden,
                onChanged: (bool value) {
                  if (value) {
                    innerRef.read(timerHiddenCategoriesProvider.notifier).unhideCategory(cat);
                  } else {
                    innerRef.read(timerHiddenCategoriesProvider.notifier).hideCategory(cat);
                  }
                },
              ),
              SwitchListTile(
                secondary: Icon(isGoalsHidden ? Icons.track_changes : Icons.track_changes_outlined, color: Colors.indigoAccent),
                title: const Text('於「專注目標頁面」顯示', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('關閉後，該項目不會出現在專注目標頁面。', style: TextStyle(fontSize: 11)),
                value: !isGoalsHidden,
                onChanged: (bool value) {
                  if (value) {
                    innerRef.read(goalsHiddenCategoriesProvider.notifier).unhideCategory(cat);
                  } else {
                    innerRef.read(goalsHiddenCategoriesProvider.notifier).hideCategory(cat);
                  }
                },
              ),
              SwitchListTile(
                secondary: Icon(isStatsHidden ? Icons.query_stats_outlined : Icons.query_stats, color: Colors.green),
                title: const Text('於「統計頁面」顯示', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('關閉後，該項目不會出現在統計頁面。', style: TextStyle(fontSize: 11)),
                value: !isStatsHidden,
                onChanged: (bool value) {
                  if (value) {
                    innerRef.read(statsHiddenCategoriesProvider.notifier).unhideCategory(cat);
                  } else {
                    innerRef.read(statsHiddenCategoriesProvider.notifier).hideCategory(cat);
                  }
                },
              ),
              SwitchListTile(
                secondary: Icon(isHistoryHidden ? Icons.history_toggle_off : Icons.history, color: Colors.deepPurple),
                title: const Text('於「歷史頁面」顯示', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('關閉後，該項目不會出現在歷史頁面。', style: TextStyle(fontSize: 11)),
                value: !isHistoryHidden,
                onChanged: (bool value) {
                  if (value) {
                    innerRef.read(historyHiddenCategoriesProvider.notifier).unhideCategory(cat);
                  } else {
                    innerRef.read(historyHiddenCategoriesProvider.notifier).hideCategory(cat);
                  }
                },
              ),
              SwitchListTile(
                secondary: Icon(isGlobalHidden ? Icons.archive : Icons.archive_outlined, color: Colors.blueGrey),
                title: const Text('封存此項目', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('封存後可從設定頁面的封存管理找回。', style: TextStyle(fontSize: 11)),
                value: isGlobalHidden,
                onChanged: (bool value) {
                  if (value) {
                    innerRef.read(hiddenCategoriesProvider.notifier).hideCategory(cat);
                    innerRef.read(timerHiddenCategoriesProvider.notifier).hideCategory(cat);
                    innerRef.read(goalsHiddenCategoriesProvider.notifier).hideCategory(cat);
                    innerRef.read(statsHiddenCategoriesProvider.notifier).hideCategory(cat);
                    innerRef.read(historyHiddenCategoriesProvider.notifier).hideCategory(cat);
                  } else {
                    innerRef.read(hiddenCategoriesProvider.notifier).unhideCategory(cat);
                  }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                title: const Text('刪除選項', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                subtitle: const Text('可選擇僅從清單移除，或徹底刪除所有資料。', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDeleteConfirmDialog(context, cat, ref);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    ),
  );
}

void showRenameDialog(BuildContext context, String oldName, WidgetRef ref) {
  String newName = oldName;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('重新命名項目'),
      content: TextField(
        autofocus: true,
        decoration: InputDecoration(hintText: oldName),
        onChanged: (v) => newName = v,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            final finalName = newName.trim();
            if (finalName.isNotEmpty && finalName != oldName) {
              ref.read(categoryColorProvider.notifier).renameCategory(oldName, finalName);
            }
            Navigator.pop(ctx);
          },
          child: const Text('更新'),
        ),
      ],
    ),
  );
}

void showColorPickerDialog(BuildContext context, String cat, WidgetRef ref) async {
  final currentColor = ref.read(categoryColorProvider)[cat] ?? Colors.indigo;
  final picked = await _pickColor(context, currentColor);
  if (picked != null) {
    ref.read(categoryColorProvider.notifier).updateColor(cat, picked);
  }
}

void showDeleteConfirmDialog(BuildContext context, String cat, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('刪除：$cat', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('請選擇你要的刪除方式：', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildDeleteOption(
            context,
            '僅從清單移除',
            '只把這個項目從可用清單移除，歷史與目標資料都會保留。',
            Icons.history,
            Colors.blue,
            () async {
              final success = ref.read(categoryColorProvider.notifier).removeCategoryFromList(cat);
              Navigator.pop(ctx);
              if (success) {
                _showSnackBar(context, '已從清單移除：$cat', Colors.blueGrey.shade800);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDeleteOption(
            context,
            '徹底刪除',
            '會刪除這個項目、所有計時紀錄與目標進度，且無法復原。',
            Icons.warning_amber_rounded,
            Colors.red,
            () async {
              final success = await ref.read(categoryColorProvider.notifier).wipeCategoryCompletely(cat);
              Navigator.pop(ctx);
              if (success) {
                _showSnackBar(context, '已徹底刪除：$cat', Colors.red);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
      ],
    ),
  );
}

Widget _buildDeleteOption(
  BuildContext context,
  String title,
  String desc,
  IconData icon,
  Color color,
  VoidCallback onTap,
) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void _showSnackBar(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
