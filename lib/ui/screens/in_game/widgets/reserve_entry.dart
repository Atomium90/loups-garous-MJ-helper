import 'package:material_ui/material_ui.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/l10n.dart';
import '../../../widgets/app_button.dart';

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
      builder: (_) => _PickerSheet(roleIds: _options(slot)),
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
                _Slot(
                  index: slot,
                  roleId: _picked[slot],
                  onTap: () => _pick(slot),
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

class _Slot extends StatelessWidget {
  const _Slot({required this.index, required this.roleId, required this.onTap});

  final int index;
  final String? roleId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final filled = roleId != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: filled ? colors.accentBg : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          side: BorderSide(color: filled ? colors.accentBorder : colors.borderControl),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                Icon(AppIcons.thief, size: 15, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.roleIds});

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
