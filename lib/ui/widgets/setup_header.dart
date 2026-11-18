import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';

/// The header of the game setup screens (composition, players, before the night): a back
/// arrow, the screen [title] and a [subtitle] line under it.
class SetupHeader extends StatelessWidget {
  const SetupHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(AppIcons.back, size: 18, color: colors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            onPressed: onBack,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: typography.screenTitle.copyWith(color: colors.textPrimary)),
              Text(subtitle, style: typography.meta.copyWith(color: colors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}
