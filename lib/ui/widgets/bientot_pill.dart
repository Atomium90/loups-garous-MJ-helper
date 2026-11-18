import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../utils/l10n.dart';

/// The "bientôt" (coming soon) badge on deliberately-unfinished rows - the "Carnet
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
        context.l10n.soonPill,
        style: context.typography.counter.copyWith(color: colors.warnText),
      ),
    );
  }
}
