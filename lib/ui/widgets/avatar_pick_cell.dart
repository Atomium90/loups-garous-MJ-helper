import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'player_avatar.dart';

/// One tappable cell of a player-selection grid: a [PlayerAvatar] over the
/// name, both going accent when selected. Shared by the identification step and
/// the night-action target pickers.
class AvatarPickCell extends StatelessWidget {
  const AvatarPickCell({
    required this.name,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatar(name: name, size: AppSizes.avatarSelectionGrid, selected: selected),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              color: selected ? colors.accentText : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
