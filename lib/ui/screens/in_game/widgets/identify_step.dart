import 'package:flutter/material.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/french_role_label.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/avatar_pick_cell.dart';

/// The "learn who holds this role" step, reused by every night-calling role.
/// A 4-column avatar grid; exactly [count] must be picked before "Enregistrer".
class IdentifyStep extends StatefulWidget {
  const IdentifyStep({
    required this.role,
    required this.count,
    required this.candidates,
    required this.onConfirm,
    required this.onDefer,
    super.key,
  });

  final Role role;
  final int count;

  /// (rowId, name) for every player who could hold the role - all living
  /// players. `rowId` is what [onConfirm] returns.
  final List<({int rowId, String name})> candidates;
  final ValueChanged<List<int>> onConfirm;
  final VoidCallback onDefer;

  @override
  State<IdentifyStep> createState() => _IdentifyStepState();
}

class _IdentifyStepState extends State<IdentifyStep> {
  final _selected = <int>{};

  void _toggle(int rowId) {
    setState(() {
      if (_selected.contains(rowId)) {
        _selected.remove(rowId);
      } else if (widget.count == 1) {
        // single-select: tapping another player switches to them
        _selected
          ..clear()
          ..add(rowId);
      } else if (_selected.length < widget.count) {
        _selected.add(rowId);
      }
      // multi-select at capacity: refuse the extra (design's rule); deselect
      // one first to change it.
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final registry = RoleRegistry.base;
    final question = widget.count == 1
        ? 'Qui est ${widget.role.name} ?'
        : 'Qui sont les ${frenchRolePlural(widget.role.id, registry)} ?';
    final complete = _selected.length == widget.count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  question,
                  style: typography.rowLabel.copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selected.length} sur ${widget.count}',
                style: typography.counter.copyWith(color: colors.accentText),
              ),
            ],
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
                  selected: _selected.contains(c.rowId),
                  onTap: () => _toggle(c.rowId),
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
                label: complete ? 'Enregistrer' : 'Choisissez ${widget.count} ${widget.count == 1 ? 'joueur' : 'joueurs'}',
                onPressed: complete ? () => widget.onConfirm(_selected.toList()) : null,
              ),
              AppButton(
                label: 'Je noterai plus tard',
                variant: AppButtonVariant.secondary,
                onPressed: widget.onDefer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

