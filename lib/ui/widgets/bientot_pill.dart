import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// The "bientôt" (coming soon) badge on deliberately-unfinished rows - A1's "Carnet
/// d'habitués", later Réglages and Mes boîtes. `warn/bg` fill, `warn/text` label, 11pt, pill.
class BientotPill extends StatelessWidget {
  const BientotPill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.warnBg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        'bientôt',
        style: context.typography.counter.copyWith(color: colors.warnText),
      ),
    );
  }
}
