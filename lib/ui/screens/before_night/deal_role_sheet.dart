import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/l10n.dart';

/// What the MJ chose in [DealRoleSheet]: a card, or (a null [roleId]) to forget the one noted.
typedef DealRoleChoice = ({String? roleId});

/// "Which card did [playerName] get?" A bottom sheet listing the cards of the deal not yet put on
/// another player, popping a [DealRoleChoice].
class DealRoleSheet extends StatelessWidget {
  const DealRoleSheet({
    required this.playerName,
    required this.options,
    required this.current,
    super.key,
  });

  final String playerName;

  /// The cards that can still go on this player, with how many of each are left.
  final List<({String roleId, int left})> options;

  /// The card already noted for this player, if any.
  final String? current;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 8),
            child: Text(
              context.l10n.dealRoleTitle(playerName),
              style: typography.rowLabel.copyWith(color: colors.textPrimary),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    selected: option.roleId == current,
                    selectedColor: colors.accentText,
                    title: Text(
                      context.l10n.roleName(option.roleId),
                      style: typography.body.copyWith(
                        color: option.roleId == current ? colors.accentText : colors.textPrimary,
                      ),
                    ),
                    trailing: option.left > 1
                        ? Text(
                            context.l10n.dealRoleLeft(option.left),
                            style: typography.counter.copyWith(color: colors.textTertiary),
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop<DealRoleChoice>((roleId: option.roleId)),
                  ),
                if (current != null)
                  ListTile(
                    leading: Icon(AppIcons.removeReserve, size: 18, color: colors.textSecondary),
                    title: Text(
                      context.l10n.dealRoleClear,
                      style: typography.body.copyWith(color: colors.textSecondary),
                    ),
                    onTap: () => Navigator.of(context).pop<DealRoleChoice>((roleId: null)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
