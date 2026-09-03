import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// A role pill (the composition screen's "Village"/"Loups" lists): selected takes `accent/bg` fill +
/// `accent/border` + `accent/text` label; unselected is a plain hairline outline, no fill.
///
/// [enabled] false dims the pill and drops the tap - used when a role's only
/// card is already spent (e.g. set aside as the Voleur's reserve); [note] then
/// renders a muted reason after the label ("en réserve").
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.note,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final Color fill;
    final Color border;
    final Color textColor;
    if (!enabled) {
      fill = Colors.transparent;
      border = colors.borderHairline;
      textColor = colors.textTertiary;
    } else if (selected) {
      fill = colors.accentBg;
      border = colors.accentBorder;
      textColor = colors.accentText;
    } else {
      fill = Colors.transparent;
      border = colors.borderHairline;
      textColor = colors.textPrimary;
    }

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: typography.chipLabel.copyWith(color: textColor)),
              if (note != null) ...[
                const SizedBox(width: 6),
                Text(
                  note!,
                  style: typography.chipLabel.copyWith(color: colors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
