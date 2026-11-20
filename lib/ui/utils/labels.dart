import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import 'package:material_ui/material_ui.dart' show IconData;
import 'package:rules_engine/rules_engine.dart';

import '../../data/database/app_database.dart';
import '../../data/models/game_winner.dart';
import '../../l10n/localizations.dart';
import '../../state/session/session_summary_provider.dart';
import '../theme/app_icons.dart';

/// "Voyante", "2 Loups-Garous", "2 Villageois" (or "Seer", "2 Werewolves" in English).
String roleCountLabel(AppLocalizations l10n, String roleId, int count) =>
    count <= 1 ? l10n.roleName(roleId) : '$count ${l10n.rolePlural(roleId)}';

/// The "Dans la pioche" line before night 1 (and the recap sheet later):
/// "2 Loups-Garous · Voyante · Sorcière · Cupidon · Chasseur · 2 Villageois".
/// Loups-Garous first, plain Villageois last, everything else in the registry's
/// declared order in between.
String deckLine(AppLocalizations l10n, Map<String, int> composition, RoleRegistry registry) {
  final entries = composition.entries.where((e) => e.value > 0).toList();

  int rank(String roleId) {
    if (registry.byIdOrNull(roleId)?.team == Team.werewolves) return 0;
    if (roleId == 'villageois') return 2;
    return 1;
  }

  entries.sort((a, b) {
    final byRank = rank(a.key).compareTo(rank(b.key));
    if (byRank != 0) return byRank;
    return registry.roles
        .indexWhere((r) => r.id == a.key)
        .compareTo(registry.roles.indexWhere((r) => r.id == b.key));
  });

  return entries.map((e) => roleCountLabel(l10n, e.key, e.value)).join(' · ');
}

/// The Voleur's two reserve cards, spelled out with articles so the MJ sets
/// the matching physical cards aside: "le Chasseur · la Voyante".
String reserveLine(AppLocalizations l10n, List<String> reserveRoleIds) =>
    reserveRoleIds.map(l10n.roleWithArticle).join(' · ');

/// A game's title: its own name, or "Partie du 14 août" / "Game of August 14" from its date.
String gameTitle(AppLocalizations l10n, Game game) =>
    game.name ?? l10n.gameDefaultName(game.createdAt);

/// "Août 2026" - the month-group label above Accueil's Historique rows.
String monthYearLabel(AppLocalizations l10n, DateTime date) {
  final label = l10n.monthYearLabel(date);
  return toBeginningOfSentenceCase(label, l10n.localeName);
}

/// The winning side, as the MJ declared it on the end-of-game screen.
String winnerLabel(AppLocalizations l10n, GameWinner winner) => l10n.winnerLabel(winner.name);

/// Terse form for a right-aligned history row: "Village", "Loups", "Amoureux", "Annulée".
String winnerShort(AppLocalizations l10n, GameWinner winner) => l10n.winnerShort(winner.name);

IconData winnerIcon(GameWinner winner) => switch (winner) {
  GameWinner.village => AppIcons.home,
  GameWinner.wolves => AppIcons.wolves,
  GameWinner.lovers => AppIcons.cupid,
  GameWinner.none => AppIcons.cancelled,
  GameWinner.piper => AppIcons.piper,
  GameWinner.whiteWolf => AppIcons.whiteWolf,
  GameWinner.angel => AppIcons.angel,
  GameWinner.sectarian => AppIcons.sectarian,
};

String _causeKey(DeathCause cause) => switch (cause) {
  WolvesKill() => 'wolves',
  WitchDeathPotionKill() => 'witchPoison',
  DayVoteKill() => 'dayVote',
  HunterShotKill() => 'hunterShot',
  LoversCascadeKill() => 'loversGrief',
};

/// The day recap's cause line: "Victime des Loups", "Potion de mort de la Sorcière".
String deathCauseLabel(AppLocalizations l10n, DeathCause cause) =>
    l10n.deathCauseLabel(_causeKey(cause));

/// The Village tab's terse sub-line, after the phase: "Nuit 3 · potion de mort".
String deathCauseShort(AppLocalizations l10n, DeathCause cause) =>
    l10n.deathCauseShort(_causeKey(cause));

/// Home's resume line for a game in progress: "Nuit 1 · Voyante", "Day 2 · village vote".
String sessionSummaryLine(AppLocalizations l10n, SessionSummary summary) {
  final phase = l10n.summaryPhase(summary.phase.name, summary.nightIndex);
  final step = switch (summary.step) {
    SummaryStep.role => l10n.roleName(summary.roleId ?? ''),
    SummaryStep.nightEnd => l10n.summaryStepNightEnd,
    SummaryStep.recap => l10n.summaryStepRecap,
    SummaryStep.captainElection => l10n.summaryStepCaptainElection,
    SummaryStep.villageVote => l10n.summaryStepVillageVote,
    SummaryStep.dayDone => l10n.summaryStepDayDone,
    SummaryStep.chainEffect => l10n.summaryStepChainEffect,
  };
  return '$phase · $step';
}
