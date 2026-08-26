import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// A generic panel (background/border/radius/padding all as parameters, rather than one fixed
/// look) used for the "en cours" game cards, the composition-role card, etc. - each screen picks
/// its own token values rather than this widget baking in a single style.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    required this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = AppRadii.button,
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final Widget child;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: child,
    );
  }
}
