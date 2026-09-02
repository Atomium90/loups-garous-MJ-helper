import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../state/session/game_session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/french_death_cause.dart';
import '../../widgets/app_button.dart';
import '../../widgets/player_avatar.dart';

/// The Village tab: the alive/dead snapshot. "Who's still alive?" is the
/// most-asked question of a real session, so this is a plain lookup - the
/// Journal is the chronology, this is the state.
class VillageTab extends ConsumerWidget {
  const VillageTab({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(gameSessionProvider(gameId));
    return sessionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => _centered(context, 'Impossible de charger le village.'),
      data: (session) => _VillageBody(gameId: gameId, session: session),
    );
  }

  Widget _centered(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: context.typography.body.copyWith(color: context.colors.textSecondary),
      ),
    ),
  );
}

class _VillageBody extends StatelessWidget {
  const _VillageBody({required this.gameId, required this.session});

  final int gameId;
  final GameSessionState session;

  /// The confirmed card for a player, or null when it was never recorded. The
  /// engine placeholder-fills un-identified players, so the roster is the truth.
  String? _confirmedRole(String engineId) {
    for (final r in session.roster) {
      if ('${r.id}' == engineId) return r.roleId;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final players = session.engine.players;
    final alive = players.where((p) => p.alive).toList(growable: false);
    final dead = players.where((p) => !p.alive).toList(growable: false);
    final captainId = session.engine.captainPlayerId;

    var villageAlive = 0;
    var wolvesAlive = 0;
    for (final p in alive) {
      final roleId = _confirmedRole(p.id);
      final team = roleId == null
          ? Team.village
          : (RoleRegistry.base.byIdOrNull(roleId)?.team ?? Team.village);
      team == Team.werewolves ? wolvesAlive++ : villageAlive++;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, AppSpacing.screen),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Le village',
                    style: typography.screenTitle.copyWith(color: colors.textPrimary),
                  ),
                  Text(
                    '${alive.length} vivants sur ${players.length}',
                    style: typography.meta.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            _TeamPill(label: 'Village $villageAlive', accent: true),
            const SizedBox(width: 6),
            _TeamPill(label: 'Loups $wolvesAlive', accent: false),
          ],
        ),
        const SizedBox(height: 10),
        if (alive.isNotEmpty) ...[
          _SectionLabel('Vivants'),
          for (final p in alive)
            _PlayerRow(
              name: p.name,
              roleId: _confirmedRole(p.id),
              isCaptain: p.id == captainId,
              dead: false,
            ),
        ],
        if (dead.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionLabel('Éliminés'),
          for (final p in dead)
            _PlayerRow(
              name: p.name,
              roleId: _confirmedRole(p.id),
              isCaptain: p.id == captainId,
              dead: true,
              deathLine: _deathLine(p),
            ),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'Terminer la partie',
          variant: AppButtonVariant.secondary,
          leadingIcon: AppIcons.endGame,
          onPressed: () => context.push('/games/$gameId/end'),
        ),
      ],
    );
  }

  String? _deathLine(Player p) {
    final cause = p.causeOfDeath;
    final night = p.diedOnNight;
    if (cause == null || night == null) return null;
    final phase = p.diedOnPhase == GamePhase.day ? 'Jour' : 'Nuit';
    return '$phase $night · ${frenchDeathCauseShort(cause)}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(
      text.toUpperCase(),
      style: context.typography.sectionLabel.copyWith(color: context.colors.textTertiary),
    ),
  );
}

class _TeamPill extends StatelessWidget {
  const _TeamPill({required this.label, required this.accent});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? colors.accentBg : colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: accent ? null : Border.all(color: colors.borderHairline),
      ),
      child: Text(
        label,
        style: context.typography.counter.copyWith(
          color: accent ? colors.accentText : colors.textSecondary,
          fontWeight: accent ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.name,
    required this.roleId,
    required this.isCaptain,
    required this.dead,
    this.deathLine,
  });

  final String name;
  final String? roleId;
  final bool isCaptain;
  final bool dead;
  final String? deathLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final id = roleId;
    final wolves = id != null && RoleRegistry.base.byIdOrNull(id)?.team == Team.werewolves;
    final roleText = id == null ? 'Rôle inconnu' : RoleRegistry.base.byId(id).name;

    return Opacity(
      opacity: dead ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.rowList),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.borderHairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PlayerAvatar(
              name: name,
              size: AppSizes.avatarRoster,
              selected: isCaptain,
              selectedStyle: AvatarSelectedStyle.captain,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 5,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.body.copyWith(
                            color: colors.textPrimary,
                            decoration: dead ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (isCaptain) Icon(AppIcons.captain, size: 13, color: colors.warnText),
                    ],
                  ),
                  if (deathLine != null)
                    Text(
                      deathLine!,
                      style: typography.micro.copyWith(color: colors.textTertiary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              roleText,
              style: typography.counter.copyWith(
                color: wolves
                    ? colors.accentText
                    : (roleId == null ? colors.textTertiary : colors.textSecondary),
                fontWeight: wolves ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
