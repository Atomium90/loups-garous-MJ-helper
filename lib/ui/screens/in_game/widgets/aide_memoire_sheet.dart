import 'package:material_ui/material_ui.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/l10n.dart';
import '../../../widgets/app_sheet.dart';

/// The wake-order aide-mémoire: one line per role, this game's composition in
/// order first, the rest dimmed and grouped last. Reached from the `?` in the
/// night header (later nights only). It never enters the flow.
Future<void> showAideMemoireSheet(
  BuildContext context,
  Map<String, int> composition,
) {
  return showAppSheet<void>(
    context,
    builder: (_) => _AideMemoire(composition: composition),
  );
}

class _AideMemoire extends StatelessWidget {
  const _AideMemoire({required this.composition});

  final Map<String, int> composition;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final registry = RoleRegistry.all;

    final inComposition = registry.roles
        .where((r) => (composition[r.id] ?? 0) > 0)
        .toList(growable: false);
    final others = registry.roles
        .where((r) => (composition[r.id] ?? 0) == 0)
        .toList(growable: false);

    // Waking roles are numbered in call order; the rest get a dash.
    var wakeNo = 0;
    String indexFor(Role r) => r.hasNightCall ? '${++wakeNo}' : '—';

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            12,
            AppSpacing.screen,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(bottomGap: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.aideTitle,
                          style: typography.screenTitle.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          context.l10n.aideSubtitle,
                          style: typography.meta.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in inComposition)
                        _RoleLine(index: indexFor(r), role: r),
                      for (final r in others)
                        _RoleLine(index: '—', role: r, dimmed: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.borderHairline)),
                ),
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  context.l10n.aideFooter,
                  style: typography.counter.copyWith(
                    color: colors.textTertiary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleLine extends StatelessWidget {
  const _RoleLine({
    required this.index,
    required this.role,
    this.dimmed = false,
  });

  final String index;
  final Role role;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.borderHairline)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            SizedBox(
              width: 14,
              child: Text(
                index,
                style: typography.counter.copyWith(color: colors.textTertiary),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.roleName(role.id),
                    style: typography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    context.l10n.roleRuleText(role.id),
                    style: typography.meta.copyWith(
                      color: colors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
