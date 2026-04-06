import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/category_provider.dart';
import '../providers/session_provider.dart';
import '../providers/timer_provider.dart';

void showAddCategoryDialog(BuildContext context, WidgetRef ref) {
  String newName = '';
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('新增項目'),
      content: TextField(
        autofocus: true,
        decoration: const InputDecoration(labelText: '項目名稱'),
        onChanged: (v) => newName = v,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (newName.isNotEmpty) {
              ref.read(categoryColorProvider.notifier).addCategory(newName, Colors.indigoAccent);
            }
            Navigator.pop(ctx);
          },
          child: const Text('新增'),
        )
      ],
    ),
  );
}

void showCategoryOptions(BuildContext context, String cat, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final isGlobalHidden = ref.watch(hiddenCategoriesProvider).contains(cat);
        final isTimerHidden = ref.watch(timerHiddenCategoriesProvider).contains(cat);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('重命名項目名稱', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  showRenameDialog(context, cat, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: Colors.indigo),
                title: const Text('更改項目識別顏色', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  showColorPickerDialog(context, cat, ref);
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(isTimerHidden ? Icons.timer_off_outlined : Icons.timer_outlined, color: Colors.orange),
                title: const Text('計時器清單顯示', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('關閉後將不顯示在首頁，但保留目標與數據', style: TextStyle(fontSize: 12)),
                value: !isTimerHidden,
                onChanged: (bool value) {
                   if (value) {
                     ref.read(timerHiddenCategoriesProvider.notifier).unhideCategory(cat);
                   } else {
                     ref.read(timerHiddenCategoriesProvider.notifier).hideCategory(cat);
                   }
                },
              ),
              SwitchListTile(
                secondary: Icon(isGlobalHidden ? Icons.archive : Icons.archive_outlined, color: Colors.blueGrey),
                title: const Text('全域資料封存 (全球隱藏)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('隱藏後將從目標與統計中完全撤下', style: TextStyle(fontSize: 12)),
                value: !isGlobalHidden,
                onChanged: (bool value) {
                   if (value) {
                     ref.read(hiddenCategoriesProvider.notifier).unhideCategory(cat);
                   } else {
                     ref.read(hiddenCategoriesProvider.notifier).hideCategory(cat);
                     // If globally hidden, also hide from timer automatically for consistency
                     ref.read(timerHiddenCategoriesProvider.notifier).hideCategory(cat);
                   }
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text('徹底刪除 "$cat"', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: const Text('連同所有歷史紀錄一同刪除，不可復原', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
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
      title: const Text('重命名項目'),
      content: TextField(
        autofocus: true,
        decoration: InputDecoration(hintText: oldName),
        onChanged: (v) => newName = v,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (newName.isNotEmpty && newName != oldName) {
              ref.read(categoryColorProvider.notifier).renameCategory(oldName, newName);
            }
            Navigator.pop(ctx);
          },
          child: const Text('更新名稱'),
        )
      ],
    ),
  );
}

void showColorPickerDialog(BuildContext context, String cat, WidgetRef ref) {
  final List<Color> colors = [
    const Color(0xFF6C63FF), const Color(0xFF03DAC6), const Color(0xFFFF6584),
    const Color(0xFFFFA62D), const Color(0xFF42A5F5), const Color(0xFFAB47BC),
    const Color(0xFF607D8B), const Color(0xFF4CAF50), const Color(0xFFE91E63),
  ];

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('選擇識別顏色'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: colors.map((c) => GestureDetector(
          onTap: () {
            ref.read(categoryColorProvider.notifier).updateColor(cat, c);
            Navigator.pop(ctx);
          },
          child: Container(
            width: 45, height: 45,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black12)),
          ),
        )).toList(),
      ),
    ),
  );
}

void showDeleteConfirmDialog(BuildContext context, String cat, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('確定要徹底刪除？'),
        ],
      ),
      content: Text('這將會永久刪除 「$cat」 的所有專注紀錄與設定，動作無法復原。如果只想從首頁移除，請選擇「隱藏」。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            ref.read(categoryColorProvider.notifier).hardDeleteCategory(cat);
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🔥 已徹底清空：$cat'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
          child: const Text('確定徹底刪除'),
        )
      ],
    ),
  );
}
