import 'package:material_ui/material_ui.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/l10n.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_sheet.dart';

/// Asks the MJ whether the player the wolves just picked is the Elder. True when it is, false
/// when it is not (or null when the sheet is dismissed, which counts as "not").
Future<bool?> showElderQuestion(BuildContext context, {required String name}) {
  return showAppSheet<bool>(
    context,
    builder: (sheetContext) {
      final colors = sheetContext.colors;
      final typography = sheetContext.typography;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              Text(
                sheetContext.l10n.scriptElderAskTitle,
                style: typography.rowLabel.copyWith(color: colors.textPrimary),
              ),
              Text(
                sheetContext.l10n.scriptElderAskBody(name),
                style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 4),
              AppButton(
                label: sheetContext.l10n.scriptElderYes,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              AppButton(
                label: sheetContext.l10n.scriptElderNo,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
}
