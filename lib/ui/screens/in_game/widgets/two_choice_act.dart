import 'package:material_ui/material_ui.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';

/// A question with two answers and nothing to pick: the Wolf-Hound's side, the Cursed
/// Wolf-Father's bite or not. The first answer is the primary button.
class TwoChoiceAct extends StatelessWidget {
  const TwoChoiceAct({
    required this.question,
    required this.firstLabel,
    required this.onFirst,
    required this.secondLabel,
    required this.onSecond,
    super.key,
  });

  final String question;
  final String firstLabel;
  final VoidCallback onFirst;
  final String secondLabel;
  final VoidCallback onSecond;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 8),
          child: Text(
            question,
            style: typography.rowLabel.copyWith(color: colors.textPrimary, height: 1.4),
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              AppButton(label: firstLabel, onPressed: onFirst),
              AppButton(
                label: secondLabel,
                variant: AppButtonVariant.secondary,
                onPressed: onSecond,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
