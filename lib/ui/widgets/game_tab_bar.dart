import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_icons.dart';

/// The in-game bottom bar (Script / Village / Journal). 3 equal columns, top
/// hairline; the active column goes `accent/text` at weight 500. The Script
/// icon is a moon at night, a sun by day.
class GameTabBar extends StatelessWidget {
  const GameTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.scriptIsNight,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool scriptIsNight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: AppSizes.tabBar,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: Row(
        children: [
          _Tab(
            icon: scriptIsNight ? AppIcons.night : AppIcons.day,
            label: 'Script',
            selected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _Tab(
            icon: AppIcons.village,
            label: 'Village',
            selected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _Tab(
            icon: AppIcons.journal,
            label: 'Journal',
            selected: currentIndex == 2,
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = selected ? colors.accentText : colors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 3,
          children: [
            Icon(icon, size: 20, color: color),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
