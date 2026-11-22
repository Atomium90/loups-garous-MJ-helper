import 'package:material_ui/material_ui.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/l10n.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/reserve_card.dart';

/// The Voleur's two leftover cards, noted once the deal is done. The app needs them to know who
/// can still hold what - and to force the swap when both are Loups-Garous.
class ReserveEntry extends StatefulWidget {
  const ReserveEntry({
    required this.pack,
    required this.onConfirm,
    required this.onDefer,
    super.key,
  });

  /// Role id -> how many cards of it are in the pack, in the order the picker lists them.
  final List<({String roleId, int count})> pack;

  /// The two role ids the MJ read off the cards.
  final ValueChanged<List<String>> onConfirm;
  final VoidCallback onDefer;

  @override
  State<ReserveEntry> createState() => _ReserveEntryState();
}

class _ReserveEntryState extends State<ReserveEntry> {
  final _picked = <String?>[null, null];

  /// The pack cards still free for [slot]: what is in the pack, minus the other slot's pick.
  List<String> _options(int slot) {
    final other = _picked[1 - slot];
    return [
      for (final entry in widget.pack)
        if (entry.count - (entry.roleId == other ? 1 : 0) > 0) entry.roleId,
    ];
  }

  Future<void> _pick(int slot) async {
    final roleId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.bgScreen,
      builder: (_) => ReserveRolePickerSheet(roleIds: _options(slot)),
    );
    if (roleId != null && mounted) setState(() => _picked[slot] = roleId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final complete = _picked.every((r) => r != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 6),
          child: Text(
            context.l10n.reserveEntryTitle,
            style: typography.rowLabel.copyWith(color: colors.textPrimary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, 12),
          child: Text(
            context.l10n.reserveEntryBody,
            style: typography.meta.copyWith(color: colors.textSecondary, height: 1.5),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            children: [
              for (var slot = 0; slot < 2; slot++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ReserveSlot(
                    index: slot,
                    roleId: _picked[slot],
                    onTap: () => _pick(slot),
                    icon: AppIcons.thief,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            4,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              AppButton(
                label: context.l10n.reserveEntryConfirm,
                onPressed: complete
                    ? () => widget.onConfirm([for (final r in _picked) r!])
                    : null,
              ),
              AppButton(
                label: context.l10n.identifyLater,
                variant: AppButtonVariant.secondary,
                onPressed: widget.onDefer,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
