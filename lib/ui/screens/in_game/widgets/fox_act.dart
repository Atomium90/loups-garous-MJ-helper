import 'package:material_ui/material_ui.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/l10n.dart';
import '../../../utils/narration.dart';
import '../../../widgets/app_button.dart';
import 'target_pick.dart';

/// The Fox's turn: the MJ points at the middle player, the app names the three he sniffs and
/// says what the roles it knows suggest, and the MJ tells whether a wolf is really among them
/// (the app may not know every card yet). With none, the Fox loses his power: said before the
/// MJ answers.
class FoxAct extends StatefulWidget {
  const FoxAct({
    required this.candidates,
    required this.trioFor,
    required this.appKnowsWolf,
    required this.onAnswer,
    required this.onSkip,
    super.key,
  });

  /// The living players the Fox may point at.
  final List<Candidate> candidates;

  /// The names of the three players sniffed when [middleId] is the middle one.
  final List<String> Function(String middleId) trioFor;

  /// Whether the roles the app knows put a wolf among those three.
  final bool Function(String middleId) appKnowsWolf;

  /// The MJ's answer: the middle player, and whether a wolf is among the three.
  final void Function(String middleId, bool wolfFound) onAnswer;

  /// The Fox passes tonight (his call is optional).
  final VoidCallback onSkip;

  @override
  State<FoxAct> createState() => _FoxActState();
}

class _FoxActState extends State<FoxAct> {
  String? _middleId;

  @override
  Widget build(BuildContext context) {
    final middleId = _middleId;
    if (middleId == null) {
      return TargetPick(
        question: context.l10n.scriptFoxQuestion,
        candidates: widget.candidates,
        confirmLabel: context.l10n.scriptFoxSniff,
        onConfirm: (id) => setState(() => _middleId = id),
        secondaryLabel: context.l10n.scriptSkipRole,
        onSecondary: widget.onSkip,
      );
    }

    final colors = context.colors;
    final typography = context.typography;
    final names = joinNames(context.l10n, widget.trioFor(middleId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 6),
          child: Text(
            context.l10n.scriptFoxTrio(names),
            style: typography.rowLabel.copyWith(color: colors.textPrimary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 6),
          child: Text(
            context.l10n.scriptFoxAsk,
            style: typography.body.copyWith(color: colors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 6),
          child: Text(
            context.l10n.scriptFoxHint('${widget.appKnowsWolf(middleId)}'),
            style: typography.meta.copyWith(color: colors.textTertiary, height: 1.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 0),
          child: Text(
            context.l10n.scriptFoxLoses,
            style: typography.meta.copyWith(color: colors.warnText, height: 1.5),
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
              AppButton(
                label: context.l10n.scriptFoxYes,
                onPressed: () => widget.onAnswer(middleId, true),
              ),
              AppButton(
                label: context.l10n.scriptFoxNo,
                variant: AppButtonVariant.secondary,
                onPressed: () => widget.onAnswer(middleId, false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
