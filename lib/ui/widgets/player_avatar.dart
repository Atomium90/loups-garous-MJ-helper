import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The player avatar used across the app - A2's roster chips now, then every Phase 4 selection
/// grid, roster list and recap. No photos, no colour-hashing (design handoff, "Assets"): the
/// first two letters of the name, uppercased, in a circle.
///
/// - unselected: [fillColor] (default `bg/inset`) + a hairline outline
/// - [selected]: 2px `accent/border` ring, `accent/bg` fill, `accent/text` initials at 500
///   (the N1 / vote-grid selection state)
///
/// An empty name renders a blank circle (no initials) - e.g. a seat not yet named.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.name,
    this.size = 28,
    this.selected = false,
    this.fillColor,
    super.key,
  });

  final String name;
  final double size;
  final bool selected;

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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.accentBg : (fillColor ?? colors.bgInset),
        border: Border.all(
          color: selected ? colors.accentBorder : colors.borderHairline,
          width: selected ? 2 : 0.5,
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w500,
          color: selected ? colors.accentText : colors.textSecondary,
        ),
      ),
    );
  }
}
