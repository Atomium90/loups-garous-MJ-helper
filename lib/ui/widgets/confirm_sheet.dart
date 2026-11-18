import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../utils/l10n.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'app_sheet.dart';

/// A bottom sheet that asks before doing something that can't be undone: a [title], a
/// [message], a primary [confirmLabel] button and an "Annuler" one.
///
/// [onConfirm] runs when the primary button is pressed; the sheet closes once it is done.
/// Completes with true if the MJ confirmed, false (or null) if they dismissed the sheet.
Future<bool?> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
}) {
  return showAppSheet<bool>(
    context,
    builder: (_) => _ConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
    ),
  );
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(
              title,
              style: typography.rowLabel.copyWith(fontSize: 17, color: colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(message, style: typography.body.copyWith(color: colors.textSecondary)),
            const SizedBox(height: 16),
            AppButton(
              label: confirmLabel,
              onPressed: () async {
                // Grab the navigator before the await: the sheet may be rebuilt meanwhile.
                final navigator = Navigator.of(context);
                await onConfirm();
                navigator.pop(true);
              },
            ),
            const SizedBox(height: 8),
            AppButton(
              label: context.l10n.commonCancel,
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
