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
        title: Text('Add Category', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category name',
                hintText: 'Work, Study, Exercise...',
              ),
              onChanged: (v) => newName = v,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Color', style: TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newName.trim().isNotEmpty) {
                ref.read(categoryColorProvider.notifier).addCategory(newName.trim(), selectedColor);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
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
      title: Text('Pick color', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: HueRingPicker(
          pickerColor: initialColor,
          onColorChanged: (c) => currentColor = c,
          enableAlpha: false,
          displayThumbColor: true,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, currentColor),
          child: const Text('OK'),
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
                title: const Text('Rename', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  showRenameDialog(context, cat, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: Colors.indigo),
                title: const Text('Change color', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  showColorPickerDialog(context, cat, ref);
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'Display settings',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                ),
              ),
              SwitchListTile(
                secondary: Icon(isTimerHidden ? Icons.timer_off_outlined : Icons.timer_outlined, color: Colors.orange),
                title: const Text('Timer page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Show this category on the timer page.', style: TextStyle(fontSize: 11)),
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
                title: const Text('Goals page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Show this category on the goals page.', style: TextStyle(fontSize: 11)),
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
                title: const Text('Statistics page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Show this category on statistics charts and lists.', style: TextStyle(fontSize: 11)),
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
                title: const Text('History page', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Show this category on history charts and lists.', style: TextStyle(fontSize: 11)),
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
                title: const Text('Archive category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Archived items can be restored from the settings page.', style: TextStyle(fontSize: 11)),
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
                title: const Text('Delete options', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                subtitle: const Text('Choose between removing from the list or deleting everything.', style: TextStyle(fontSize: 11)),
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
      title: const Text('Rename category'),
      content: TextField(
        autofocus: true,
        decoration: InputDecoration(hintText: oldName),
        onChanged: (v) => newName = v,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final finalName = newName.trim();
            if (finalName.isNotEmpty && finalName != oldName) {
              ref.read(categoryColorProvider.notifier).renameCategory(oldName, finalName);
            }
            Navigator.pop(ctx);
          },
          child: const Text('Rename'),
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
      title: Text('Delete: $cat', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Choose how you want to delete this category.', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildDeleteOption(
            context,
            'Remove from list',
            'Keeps history and goals, only removes the category from the active list.',
            Icons.history,
            Colors.blue,
            () async {
              final success = ref.read(categoryColorProvider.notifier).removeCategoryFromList(cat);
              Navigator.pop(ctx);
              if (success) {
                _showSnackBar(context, 'Removed from list: $cat', Colors.blueGrey.shade800);
              }
            },
          ),
          const SizedBox(height: 12),
          _buildDeleteOption(
            context,
            'Delete completely',
            'Deletes the category, all sessions, and goal progress. This cannot be undone.',
            Icons.warning_amber_rounded,
            Colors.red,
            () async {
              final success = await ref.read(categoryColorProvider.notifier).wipeCategoryCompletely(cat);
              Navigator.pop(ctx);
              if (success) {
                _showSnackBar(context, 'Deleted completely: $cat', Colors.red);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
