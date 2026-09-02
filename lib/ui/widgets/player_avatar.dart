import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// How a [PlayerAvatar]/[AvatarPickCell] paints its selected state. `accent`
/// (blue) is the default everywhere; `captain` (amber) is the J2 captain
/// election and the succession panel - "status, not role", per the design.
enum AvatarSelectedStyle { accent, captain }

/// The player avatar used across the app - A2's roster chips now, and the in-game selection
/// grids, roster lists and recap screens later. No photos, no colour-hashing (design handoff,
/// "Assets"): the first two letters of the name, uppercased, in a circle.
///
/// - unselected: [fillColor] (default `bg/inset`) + a hairline outline
/// - [selected]: 2px ring + tinted fill + tinted initials at 500, blue by
///   default ([AvatarSelectedStyle.accent]) or amber ([AvatarSelectedStyle.captain])
///
/// An empty name renders a blank circle (no initials) - e.g. a seat not yet named.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.name,
    this.size = 28,
    this.selected = false,
    this.selectedStyle = AvatarSelectedStyle.accent,
    this.fillColor,
    super.key,
  });

  final String name;
  final double size;
  final bool selected;
  final AvatarSelectedStyle selectedStyle;

  /// Overrides the unselected fill - e.g. A2's chips sit on `bg/inset`, so their avatars pass
  /// `bg/screen` for contrast. Ignored when [selected].
  final Color? fillColor;

  static String initialsOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.characters.take(2).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final initials = initialsOf(name);
    final amber = selectedStyle == AvatarSelectedStyle.captain;
    final ring = amber ? colors.warnText : colors.accentBorder;
    final tint = amber ? colors.warnBg : colors.accentBg;
    final ink = amber ? colors.warnText : colors.accentText;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? tint : (fillColor ?? colors.bgInset),
        border: Border.all(
          color: selected ? ring : colors.borderHairline,
          width: selected ? 2 : 0.5,
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w500,
          color: selected ? ink : colors.textSecondary,
        ),
      ),
    );
  }
}
