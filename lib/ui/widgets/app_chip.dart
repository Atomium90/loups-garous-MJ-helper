import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// A role pill (E2's "Village"/"Loups" lists): selected takes `accent/bg` fill +
/// `accent/border` + `accent/text` label; unselected is a plain hairline outline, no fill.
class AppChip extends StatelessWidget {
  const AppChip({required this.label, required this.selected, required this.onTap, super.key});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Material(
      color: selected ? colors.accentBg : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: selected ? colors.accentBorder : colors.borderHairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: typography.chipLabel.copyWith(
              color: selected ? colors.accentText : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
