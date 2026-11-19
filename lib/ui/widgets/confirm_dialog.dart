import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shows a confirmation dialog and resolves to `true` only when the user
/// explicitly confirms. Dismissing the dialog resolves to `false`.
///
/// When [destructive] is set the confirm action is rendered in the error
/// colour. The cancel action is focused by default so an accidental Enter
/// press never triggers a destructive action.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon,
              color: destructive ? AppColors.error : AppColors.warning),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Text(message),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
      actions: [
        OutlinedButton(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.background,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
