import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_icons.dart';
import '../theme/app_typography.dart';
import '../utils/l10n.dart';

/// One of the Voleur's two reserve cards: "Carte 1 - a role, or Choisir". Shared by the
/// composition (where the MJ picks them) and the game (where they are noted after the deal).
/// With [onClear] a filled slot shows a remove icon; otherwise [icon] ends the row.
class ReserveSlot extends StatelessWidget {
  const ReserveSlot({
    required this.index,
    required this.roleId,
    required this.onTap,
    required this.icon,
    this.onClear,
    this.verticalPadding = 12,
    super.key,
  });

  final int index;
  final String? roleId;
  final VoidCallback onTap;
  final IconData icon;
  final VoidCallback? onClear;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final filled = roleId != null;
    return Material(
      color: filled ? colors.accentBg : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        side: BorderSide(color: filled ? colors.accentBorder : colors.borderControl),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: verticalPadding),
          child: Row(
            children: [
              Text(
                context.l10n.reserveCard(index + 1),
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  filled ? context.l10n.roleName(roleId!) : context.l10n.reservePick,
                  style: typography.rowLabel.copyWith(
                    color: filled ? colors.accentText : colors.textSecondary,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(AppIcons.removeReserve, size: 16, color: colors.accentText),
                  ),
                )
              else
                Icon(icon, size: 15, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Which card? A bottom sheet listing [roleIds], popping the one picked.
class ReserveRolePickerSheet extends StatelessWidget {
  const ReserveRolePickerSheet({required this.roleIds, super.key});

  final List<String> roleIds;

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
              context.l10n.reserveWhichCard,
              style: typography.rowLabel.copyWith(color: colors.textPrimary),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final id in roleIds)
                  ListTile(
                    title: Text(
                      context.l10n.roleName(id),
                      style: typography.body.copyWith(color: colors.textPrimary),
                    ),
                    onTap: () => Navigator.of(context).pop(id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
