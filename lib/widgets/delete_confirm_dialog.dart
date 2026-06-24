import 'package:flutter/material.dart';

Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = '取消',
  String deleteLabel = '刪除',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colorScheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.delete_outline, color: colorScheme.error),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.errorContainer,
              foregroundColor: colorScheme.onErrorContainer,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(deleteLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

Future<void> confirmDeleteRecord({
  required BuildContext context,
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
  String successMessage = '已刪除紀錄',
  String cancelLabel = '取消',
  String deleteLabel = '刪除',
}) async {
  final shouldDelete = await showDeleteConfirmDialog(
    context,
    title: title,
    message: message,
    cancelLabel: cancelLabel,
    deleteLabel: deleteLabel,
  );
  if (!shouldDelete || !context.mounted) {
    return;
  }

  await onConfirm();
  if (!context.mounted) {
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(successMessage),
      duration: const Duration(seconds: 2),
    ),
  );
}
