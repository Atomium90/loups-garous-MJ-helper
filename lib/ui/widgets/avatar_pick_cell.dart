import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'player_avatar.dart';

/// One tappable cell of a player-selection grid: a [PlayerAvatar] over the
/// name, both going to the selection tint when selected. Shared by the
/// identification step, the night-action target pickers, the captain election
/// and the village vote.
class AvatarPickCell extends StatelessWidget {
  const AvatarPickCell({
    required this.name,
    required this.selected,
    required this.onTap,
    this.enabled = true,
    this.avatarSize = AppSizes.avatarSelectionGrid,
    this.selectedStyle = AvatarSelectedStyle.accent,
    this.badge,
    super.key,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  /// False for a fixed cell - already decided, not up for the current pick
  /// (the Voleur, locked into a role he stole). Dimmed and non-tappable.
  final bool enabled;

  /// Diameter of the avatar. The vote grid uses the largest (44).
  final double avatarSize;

  final AvatarSelectedStyle selectedStyle;

  /// Small overlay pinned to the avatar's top-right corner (the captain's
  /// crown in the vote grid).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amber = selectedStyle == AvatarSelectedStyle.captain;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                PlayerAvatar(
                  name: name,
                  size: avatarSize,
                  selected: selected,
                  selectedStyle: selectedStyle,
                ),
                if (badge != null) Positioned(top: -3, right: -3, child: badge!),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: selected
                    ? (amber ? colors.warnText : colors.accentText)
                    : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
