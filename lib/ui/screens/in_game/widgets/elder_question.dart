import 'package:material_ui/material_ui.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/l10n.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_sheet.dart';

/// Asks the MJ whether the player the wolves just picked is the Elder. True when it is, false
/// when it is not (or null when the sheet is dismissed, which counts as "not").
Future<bool?> showElderQuestion(BuildContext context, {required String name}) =>
    showCardQuestion(
      context,
      title: context.l10n.scriptElderAskTitle,
      body: context.l10n.scriptElderAskBody(name),
      yes: context.l10n.scriptElderYes,
      no: context.l10n.scriptElderNo,
    );

/// Asks the MJ whether the player the village is about to eliminate is the Village Idiot.
Future<bool?> showIdiotQuestion(BuildContext context, {required String name}) =>
    showCardQuestion(
      context,
      title: context.l10n.scriptIdiotAskTitle,
      body: context.l10n.scriptIdiotAskBody(name),
      yes: context.l10n.scriptIdiotYes,
      no: context.l10n.scriptElderNo,
    );

/// A yes/no question about a player's hidden card, as a bottom sheet.
Future<bool?> showCardQuestion(
  BuildContext context, {
  required String title,
  required String body,
  required String yes,
  required String no,
}) {
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
                title,
                style: typography.rowLabel.copyWith(color: colors.textPrimary),
              ),
              Text(
                body,
                style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 4),
              AppButton(
                label: yes,
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              AppButton(
                label: no,
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
