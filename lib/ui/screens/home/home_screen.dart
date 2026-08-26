import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/game_status.dart';
import '../../../state/providers/game_list_provider.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/french_date_format.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon_button.dart';
import '../../widgets/section_label.dart';

/// E0 (empty state) and E1 (games list) are the same route ("Accueil"), branching on whether
/// [gameListProvider] is empty - not two separate routes, so the "which screen" decision lives
/// where the data does.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gameListProvider);
    return Scaffold(
      body: SafeArea(
        child: gamesAsync.when(
          data: (games) =>
              games.isEmpty ? const _EmptyState() : _GamesList(games: games),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Text(
                'Impossible de charger vos parties.',
                textAlign: TextAlign.center,
                style: context.typography.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _startNewGame(BuildContext context, WidgetRef ref) async {
  final gameId = await ref.read(gameRepositoryProvider).createGame();
  if (context.mounted) {
    context.goNamed('composition', pathParameters: {'id': '$gameId'});
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.showNewGameButton});

  final bool showNewGameButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        24,
        AppSpacing.screen,
        showNewGameButton ? 14 : 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mes parties',
            style: context.typography.screenTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          Row(
            spacing: 8,
            children: [
              // Réglages isn't built this session - a normal-looking button that doesn't
              // respond yet, not the inert visual (that's reserved for "needs more input").
              AppIconButton(icon: AppIcons.settings, onTap: null),
              if (showNewGameButton)
                AppIconButton(
                  icon: AppIcons.newGame,
                  onTap: () => _startNewGame(context, ref),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    return Column(
      children: [
        const _Header(showNewGameButton: false),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 14,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colors.bgInset,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.borderHairline),
                    ),
                    child: Icon(
                      AppIcons.emptyState,
                      size: 24,
                      color: colors.textTertiary,
                    ),
                  ),
                  Text(
                    'Aucune partie',
                    textAlign: TextAlign.center,
                    style: typography.rowLabel.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    "Composez le village, distribuez les cartes, et laissez l'app tenir le fil "
                    'de la nuit.',
                    textAlign: TextAlign.center,
                    style: typography.body.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: AppButton(
            label: 'Nouvelle partie',
            leadingIcon: AppIcons.newGame,
            onPressed: () => _startNewGame(context, ref),
          ),
        ),
      ],
    );
  }
}

class _GamesList extends ConsumerWidget {
  const _GamesList({required this.games});

  final List<Game> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enCours = games
        .where(
          (g) =>
              g.status == GameStatus.inProgress ||
              g.status == GameStatus.paused,
        )
        .toList(growable: false);
    final historique = games
        .where((g) => g.status == GameStatus.completed)
        .toList(growable: false);

    return Column(
      children: [
        const _Header(showNewGameButton: true),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 14),
            children: [
              if (enCours.isNotEmpty) _EnCoursSection(games: enCours),
              if (historique.isNotEmpty) _HistoriqueSection(games: historique),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            14,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(
            label: 'Nouvelle partie',
            leadingIcon: AppIcons.newGame,
            onPressed: () => _startNewGame(context, ref),
          ),
        ),
      ],
    );
  }
}

class _EnCoursSection extends StatelessWidget {
  const _EnCoursSection({required this.games});

  final List<Game> games;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        0,
        AppSpacing.screen,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          const SectionLabel('En cours'),
          for (final (index, game) in games.indexed)
            _EnCoursCard(game: game, isMostRecent: index == 0),
        ],
      ),
    );
  }
}

class _EnCoursCard extends StatelessWidget {
  const _EnCoursCard({required this.game, required this.isMostRecent});

  final Game game;
  final bool isMostRecent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final daysElapsed = DateTime.now().difference(game.createdAt).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: isMostRecent ? colors.accentBg : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(
          color: isMostRecent ? colors.accentBorder : colors.borderControl,
        ),
      ),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isMostRecent ? colors.bgScreen : colors.bgInset,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMostRecent ? AppIcons.resumeActive : AppIcons.resumeOther,
              size: 16,
              color: isMostRecent ? colors.accentText : colors.textTertiary,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.name ??
                      'Partie du ${frenchDayMonthLabel(game.createdAt)}',
                  style: typography.rowLabel.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                // No phase/step is tracked yet (Phase 4), so the mockup's precise resume line
                // ("Nuit 3 · la Sorcière") can't be derived - a flat fallback in text/secondary
                // (not accent/text, reserved for real precise status) instead.
                Text(
                  'Partie en cours',
                  style: typography.meta.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '$daysElapsed j.',
            style: typography.micro.copyWith(
              color: isMostRecent ? colors.textSecondary : colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoriqueSection extends StatelessWidget {
  const _HistoriqueSection({required this.games});

  final List<Game> games;

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<Game>)>[];
    for (final game in games) {
      final label = frenchMonthYearLabel(game.createdAt);
      if (groups.isNotEmpty && groups.last.$1 == label) {
        groups.last.$2.add(game);
      } else {
        groups.add((label, [game]));
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        18,
        AppSpacing.screen,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: SectionLabel('Historique'),
          ),
          for (final (index, group) in groups.indexed) ...[
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 4 : 10, bottom: 4),
              child: Text(
                group.$1,
                style: context.typography.micro.copyWith(
                  color: context.colors.textTertiary,
                ),
              ),
            ),
            for (final game in group.$2) _HistoriqueRow(game: game),
          ],
        ],
      ),
    );
  }
}

class _HistoriqueRow extends StatelessWidget {
  const _HistoriqueRow({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.borderHairline)),
      ),
      // No leading phase icon and no trailing winning-side label: `Games` has no `winner`
      // field yet, and the design's own philosophy (see E1b's survivors-only rule) is that
      // missing data is an editorial omission, not a guess.
      child: Text(
        game.name ?? 'Partie du ${frenchDayMonthLabel(game.createdAt)}',
        style: context.typography.body.copyWith(
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}
