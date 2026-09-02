import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../data/database/app_database.dart';
import '../../../data/models/game_winner.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../../state/providers/roster_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/french_date_format.dart';
import '../../utils/french_role_label.dart';
import '../../utils/french_winner_label.dart';
import '../../widgets/app_button.dart';
import '../../widgets/player_avatar.dart';

/// Reopening a finished game: the winner, the run's length, and who was still
/// standing (survivors' roles only - a finished game legitimately has gaps).
Future<void> showPastGameSheet(BuildContext context, Game game) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.bgScreen,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheetTop)),
    ),
    builder: (_) => _PastGameSheet(game: game),
  );
}

class _PastGameSheet extends ConsumerWidget {
  const _PastGameSheet({required this.game});

  final Game game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final registry = RoleRegistry.base;

    final engine = _decodeEngine(game.sessionJson);
    final roster = ref.watch(rosterProvider(game.id)).value ?? const [];
    final roleOf = {for (final r in roster) '${r.id}': r.roleId};

    final players = engine?.players ?? const <Player>[];
    final survivors = players.where((p) => p.alive).toList(growable: false);
    final nights = engine?.nightIndex ?? 0;
    final days = engine == null
        ? 0
        : (engine.phase == GamePhase.day ? engine.nightIndex : engine.nightIndex - 1);
    final winner = game.winner ?? GameWinner.none;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderHairline,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name ?? 'Partie du ${frenchDayMonthLabel(game.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.rowLabel.copyWith(fontSize: 17, color: colors.textPrimary),
                      ),
                      Text(
                        frenchDayMonthLabel(game.endedAt ?? game.createdAt),
                        style: typography.meta.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 19, color: colors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: colors.bgInset,
                borderRadius: BorderRadius.circular(AppRadii.cardSmall),
              ),
              child: Row(
                spacing: 11,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: colors.bgScreen, shape: BoxShape.circle),
                    child: Icon(frenchWinnerIcon(winner), size: 17, color: colors.textPrimary),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vainqueurs',
                        style: typography.counter.copyWith(color: colors.textTertiary),
                      ),
                      Text(
                        frenchWinnerLabel(winner),
                        style: typography.rowLabel.copyWith(fontSize: 15, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              spacing: 20,
              children: [
                _Stat(value: players.length, unit: 'joueurs'),
                _Stat(value: nights, unit: 'nuits'),
                _Stat(value: days, unit: 'jours'),
              ],
            ),
            const SizedBox(height: 12),
            Text('La compo', style: typography.meta.copyWith(color: colors.textTertiary)),
            const SizedBox(height: 4),
            Text(
              frenchDeckLine(game.compositionJson ?? const {}, registry),
              style: typography.meta.copyWith(color: colors.textSecondary, height: 1.7),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Encore debout à la fin',
                  style: typography.meta.copyWith(color: colors.textTertiary),
                ),
                Text(
                  '${survivors.length} sur ${players.length}',
                  style: typography.counter.copyWith(color: colors.textTertiary),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final p in survivors)
                      _SurvivorRow(name: p.name, roleId: roleOf[p.id]),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Les rôles des ${players.length - survivors.length} éliminés restent cachés.',
                style: typography.counter.copyWith(color: colors.textTertiary, height: 1.5),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.borderHairline)),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/games/${game.id}/journal');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    spacing: 10,
                    children: [
                      Icon(AppIcons.journal, size: 15, color: colors.textSecondary),
                      Expanded(
                        child: Text(
                          'Voir le journal complet',
                          style: typography.body.copyWith(color: colors.accentText),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: colors.accentText),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Rejouer',
                    leadingIcon: AppIcons.replay,
                    onPressed: () => _replay(context, ref),
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: AppButton(
                    label: '',
                    leadingIcon: AppIcons.share,
                    variant: AppButtonVariant.secondary,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _replay(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final repo = ref.read(gameRepositoryProvider);
    final newId = await repo.createGame(initialPlayerCount: game.playerCount);
    await repo.saveComposition(
      gameId: newId,
      playerCount: game.playerCount,
      roleCounts: game.compositionJson ?? const {},
    );
    final oldRoster = await repo.getRoster(game.id);
    await repo.savePlayerNames(
      gameId: newId,
      names: [for (final r in oldRoster) r.name],
    );
    router.go('/games/$newId/before-night');
  }
}

GameState? _decodeEngine(String? sessionJson) {
  if (sessionJson == null) return null;
  final decoded = jsonDecode(sessionJson) as Map<String, dynamic>;
  return GameStateJson.decode(decoded['engine'] as Map<String, dynamic>);
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: 5,
      children: [
        Text(
          '$value',
          style: typography.rowLabel.copyWith(fontSize: 18, color: context.colors.textPrimary),
        ),
        Text(unit, style: typography.counter.copyWith(color: context.colors.textTertiary)),
      ],
    );
  }
}

class _SurvivorRow extends StatelessWidget {
  const _SurvivorRow({required this.name, required this.roleId});

  final String name;
  final String? roleId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final id = roleId;
    final wolves = id != null && RoleRegistry.base.byIdOrNull(id)?.team == Team.werewolves;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: Row(
        spacing: 10,
        children: [
          PlayerAvatar(name: name, size: AppSizes.avatarDense),
          Expanded(
            child: Text(name, style: typography.body.copyWith(color: colors.textPrimary)),
          ),
          Text(
            id == null ? 'Rôle inconnu' : RoleRegistry.base.byId(id).name,
            style: typography.counter.copyWith(
              color: wolves ? colors.accentText : colors.textSecondary,
              fontWeight: wolves ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
