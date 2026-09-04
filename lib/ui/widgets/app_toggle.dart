import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// The design's on/off switch: a 40×24 pill, 20px knob, `accent/border` track
/// when on and `border/control` when off. Used by Réglages and Mes boîtes.
class AppToggle extends StatelessWidget {
  const AppToggle({required this.value, required this.onChanged, super.key});

  final bool value;

  /// Null renders the switch but ignores taps - a decorative "always on" state
  /// (the base box in Mes boîtes).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const inset = AppSizes.toggleInset;

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: AppSizes.toggleTrackWidth,
        height: AppSizes.toggleTrackHeight,
        decoration: BoxDecoration(
          color: value ? colors.accentBorder : colors.borderControl,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 130),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: inset),
            width: AppSizes.toggleKnob,
            height: AppSizes.toggleKnob,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
