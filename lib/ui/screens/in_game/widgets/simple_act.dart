import 'package:flutter/material.dart';

import '../../../theme/app_dimensions.dart';
import '../../../widgets/app_button.dart';

/// A role whose action needs no target picker - the Seer (the MJ shows a card,
/// then "Continuer") or a role whose action isn't built yet (Cupidon / Voleur,
/// "Passer ce rôle"). The instruction is already on the script card above.
class SimpleAct extends StatelessWidget {
  const SimpleAct({
    required this.primaryLabel,
    required this.onPrimary,
    super.key,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            0,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(label: primaryLabel, onPressed: onPrimary),
        ),
      ],
    );
  }
}
