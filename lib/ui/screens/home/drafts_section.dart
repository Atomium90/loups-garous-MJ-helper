import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/database/app_database.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../../state/providers/roster_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/french_date_format.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/confirm_sheet.dart';
import '../../widgets/section_label.dart';
import 'draft_step.dart';

/// Home's "Brouillons": games that were started (a composition, some names) but never
/// launched. Each resumes on the setup screen it stopped at, and can be deleted.
class DraftsSection extends StatelessWidget {
  const DraftsSection({required this.games, super.key});

  final List<Game> games;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 18, AppSpacing.screen, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          const SectionLabel('Brouillons'),
          for (final game in games) _DraftRow(game: game),
        ],
      ),
    );
  }
}

class _DraftRow extends ConsumerWidget {
  const _DraftRow({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final roster = ref.watch(rosterProvider(game.id)).value ?? const <PlayerRow>[];
    final step = draftStepOf(roster);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: colors.borderControl),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.button),
          onTap: () =>
              context.goNamed(step.routeName, pathParameters: {'id': '${game.id}'}),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: colors.bgInset, shape: BoxShape.circle),
                  child: Icon(AppIcons.draft, size: 16, color: colors.textTertiary),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name ?? 'Partie du ${frenchDayMonthLabel(game.createdAt)}',
                        style: typography.rowLabel.copyWith(color: colors.textPrimary),
                      ),
                      Text(
                        step.label,
                        style: typography.meta.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: AppIcons.delete,
                  size: 30,
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showConfirmSheet(
      context,
      title: 'Supprimer ce brouillon ?',
      message:
          "Cette partie n'a pas commencé : sa composition et les noms des joueurs "
          'seront perdus.',
      confirmLabel: 'Supprimer ce brouillon',
      onConfirm: () => ref.read(gameRepositoryProvider).discardDraft(game.id),
    );
  }
}
