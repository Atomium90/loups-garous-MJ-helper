import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../../widgets/bientot_pill.dart';

/// The Village tab (V): the alive/dead snapshot. Placeholder for now - the full
/// screen (team pills, captain crown, dead styling, "Terminer la partie")
/// lands with the day loop.
class VillageTab extends StatelessWidget {
  const VillageTab({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 4),
          child: Text(
            'Le village',
            style: context.typography.screenTitle.copyWith(color: colors.textPrimary),
          ),
        ),
        const Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Text('État du village'),
                BientotPill(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
