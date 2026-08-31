import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/avatar_pick_cell.dart';

/// A candidate for a night action: the engine player id, and the display name.
typedef Candidate = ({String id, String name});

/// "Pick one player, then confirm" - the Wolves' victim, the Witch's poison
/// target, etc. The primary button *names the act* ("Les Loups désignent X")
/// rather than saying "Confirmer", per the design.
class TargetPick extends StatefulWidget {
  const TargetPick({
    required this.question,
    required this.candidates,
    required this.confirmLabel,
    required this.onConfirm,
    this.pendingLabel = 'Choisissez un joueur',
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  final String question;
  final List<Candidate> candidates;

  /// The primary button label once a target is picked, e.g.
  /// `(name) => 'Les Loups désignent $name'`.
  final String Function(String name) confirmLabel;
  final ValueChanged<String> onConfirm;

  /// Primary label while nothing is picked (inert).
  final String pendingLabel;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  State<TargetPick> createState() => _TargetPickState();
}

class _TargetPickState extends State<TargetPick> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = widget.candidates
        .where((c) => c.id == _selectedId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 10),
          child: Text(
            widget.question,
            style: context.typography.rowLabel.copyWith(color: colors.textPrimary),
          ),
        ),
        Expanded(
          child: GridView.count(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            crossAxisCount: AppSizes.gridColumnsDefault,
            mainAxisSpacing: AppSpacing.gridGapRow,
            crossAxisSpacing: AppSpacing.gridGapColumn,
            childAspectRatio: 1.0,
            children: [
              for (final c in widget.candidates)
                AvatarPickCell(
                  name: c.name,
                  selected: c.id == _selectedId,
                  onTap: () => setState(() => _selectedId = c.id),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            12,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              AppButton(
                label: selected == null
                    ? widget.pendingLabel
                    : widget.confirmLabel(selected.name),
                onPressed: selected == null ? null : () => widget.onConfirm(selected.id),
              ),
              if (widget.secondaryLabel != null)
                AppButton(
                  label: widget.secondaryLabel!,
                  variant: AppButtonVariant.secondary,
                  onPressed: widget.onSecondary,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
