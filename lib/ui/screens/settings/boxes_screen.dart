import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/settings/settings_providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/l10n.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/section_label.dart';

/// Mes boîtes. The MJ ticks what they own; the composition and its suggestions then only offer
/// the roles those boxes can supply. The base box is ticked by default; any box can be unticked
/// as long as one stays.
class BoxesScreen extends ConsumerWidget {
  const BoxesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final pool = ref.watch(cardPoolProvider);
    final notifier = ref.read(settingsProvider.notifier);
    // the last box ticked cannot be unticked: nobody plays without one
    final lastOwned = pool.ownedBoxIds.length == 1 ? pool.ownedBoxIds.single : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(AppIcons.back, size: 18, color: colors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.settingsMyBoxes,
                    style: typography.screenTitle.copyWith(color: colors.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 4),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.accentBg,
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                    child: Row(
                      spacing: 10,
                      children: [
                        Icon(AppIcons.boxes, size: 18, color: colors.accentText),
                        Expanded(
                          child: Text(
                            context.l10n.boxesRolesAvailable(pool.availableRoleCount),
                            style: typography.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: colors.accentText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionLabel(context.l10n.boxesList),
                  for (final (index, box) in gameBoxes.indexed)
                    _BoxRow(
                      boxId: box.id,
                      pool: pool,
                      owned: pool.ownedBoxIds.contains(box.id),
                      showDivider: index > 0,
                      onChanged: box.id == lastOwned
                          ? null
                          : (owned) => notifier.setBoxOwned(box.id, owned),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              padding: const EdgeInsets.fromLTRB(0, 12, 0, AppSpacing.screen),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.borderHairline)),
              ),
              child: Text(
                context.l10n.boxesFooter,
                style: typography.counter.copyWith(color: colors.textTertiary, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoxRow extends StatelessWidget {
  const _BoxRow({
    required this.boxId,
    required this.pool,
    required this.owned,
    required this.onChanged,
    this.showDivider = false,
  });

  final String boxId;
  final CardPool pool;
  final bool owned;

  /// Null for a box that cannot be unticked.
  final ValueChanged<bool>? onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      decoration: showDivider
          ? BoxDecoration(border: Border(top: BorderSide(color: colors.borderHairline)))
          : null,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.rowSettings),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.boxName(boxId),
                  style: typography.rowLabel.copyWith(color: colors.textPrimary),
                ),
                Text(
                  context.l10n.boxDetail(boxId, pool.roleCountOf(boxId)),
                  style: typography.meta.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          AppToggle(value: owned, onChanged: onChanged),
        ],
      ),
    );
  }
}
