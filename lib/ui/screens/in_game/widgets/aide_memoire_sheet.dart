import 'package:flutter/material.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';

/// The wake-order aide-mémoire: one line per role, this game's composition in
/// order first, the rest dimmed and grouped last. Reached from the `?` in the
/// night header (later nights only). It never enters the flow.
Future<void> showAideMemoireSheet(
  BuildContext context,
  Map<String, int> composition,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.bgScreen,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadii.sheetTop),
      ),
    ),
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
    final registry = RoleRegistry.base;

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
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderHairline,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ordre de réveil',
                        style: typography.screenTitle.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Votre compo, dans l\'ordre',
                        style: typography.meta.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
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
                  'Une ligne par rôle, jamais plus. Pour le détail, la règle papier reste sur la table.',
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
                    role.name,
                    style: typography.body.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    role.ruleText,
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
