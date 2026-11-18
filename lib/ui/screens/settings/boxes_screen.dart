import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/l10n.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/bientot_pill.dart';
import '../../widgets/section_label.dart';

/// Mes boîtes. Informational for V1: the base box is the only one that exists,
/// extensions are listed as coming soon. Nothing here is persisted or feeds the
/// composition screen (which uses `RoleRegistry.base` directly).
class BoxesScreen extends StatelessWidget {
  const BoxesScreen({super.key});

  /// Expansion names are proper nouns: shown as they are in both languages. Placeholders until
  /// the expansions are really supported.
  static const _extensions = [
    ('Nouvelle Lune', 6),
    ('La Bouche du Loup', 6),
    ('Village aux Loups-Garous', 12),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

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
                        Text(
                          context.l10n.boxesRolesAvailable(8),
                          style: typography.body.copyWith(
                            fontWeight: FontWeight.w500,
                            color: colors.accentText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SectionLabel(context.l10n.boxesOwned),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.rowSettings),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.boxBaseName,
                                style: typography.rowLabel.copyWith(color: colors.textPrimary),
                              ),
                              Text(
                                context.l10n.boxBaseDetail(8),
                                style: typography.meta.copyWith(color: colors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        // Decorative: you can't own zero boxes, so this doesn't toggle.
                        const AppToggle(value: true, onChanged: null),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SectionLabel(context.l10n.boxesExpansions),
                  for (final (name, cards) in _extensions)
                    Opacity(
                      opacity: 0.55,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: colors.borderHairline)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.rowSettings),
                        child: Row(
                          spacing: 12,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: typography.rowLabel.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    context.l10n.boxExpansionDetail(cards),
                                    style: typography.meta.copyWith(color: colors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            const BientotPill(),
                          ],
                        ),
                      ),
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
