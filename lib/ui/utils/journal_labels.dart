import '../../data/database/app_database.dart';
import '../../data/models/night_log_entry.dart';
import '../../l10n/localizations.dart';

/// The header a journal line groups under: "NUIT 1" / "NIGHT 1". A line written before the
/// journal was structured carries its French header and is shown as it was written.
String journalPhaseLabel(AppLocalizations l10n, NightLogRow row) {
  final phase = row.phase;
  final index = row.phaseIndex;
  if (row.kind == null || phase == null || index == null) return row.phaseLabel;
  return l10n.journalPhaseHeader(phase, index);
}

/// The sentence of a journal line, in the app's language. A line written before the
/// journal was structured is French text and is shown as it was written.
String journalLine(AppLocalizations l10n, NightLogRow row) {
  final kind = JournalKind.fromName(row.kind);
  if (kind == null) return row.line;
  final args = NightLogEntry.decodeArgs(row.argsJson);
  final player = args['player'] ?? '';
  return switch (kind) {
    JournalKind.wolvesTarget => l10n.journalWolvesTarget(player),
    JournalKind.witchSave => l10n.journalWitchSave(player),
    JournalKind.witchPoison => l10n.journalWitchPoison(player),
    JournalKind.cupidPair => l10n.journalCupidPair(player, args['other'] ?? ''),
    JournalKind.thiefKeep => l10n.journalThiefKeep,
    JournalKind.thiefSwap => l10n.journalThiefSwap(l10n.roleName(args['role'] ?? '')),
    JournalKind.captainElected => l10n.journalCaptainElected(player),
    JournalKind.captainSuccessor => l10n.journalCaptainSuccessor(player),
    JournalKind.villageEliminates => l10n.journalVillageEliminates(player),
    JournalKind.voteTie => l10n.journalVoteTie,
    JournalKind.hunterNoShot => l10n.journalHunterNoShot,
    JournalKind.hunterShoots => l10n.journalHunterShoots(player),
    JournalKind.seerObserves => l10n.journalSeerObserves(player),
    JournalKind.heartbreakDeath => l10n.journalHeartbreakDeath(player),
    JournalKind.foxFindsWolf => l10n.journalFoxFindsWolf(player),
    JournalKind.foxFindsNone => l10n.journalFoxFindsNone(player),
    JournalKind.sistersMeet => l10n.journalSistersMeet,
    JournalKind.brothersMeet => l10n.journalBrothersMeet,
    JournalKind.bearGrowls => l10n.journalBearGrowls,
    JournalKind.wildChildModel => l10n.journalWildChildModel(player, args['other'] ?? ''),
    JournalKind.chienLoupWolf => l10n.journalChienLoupWolf(player),
    JournalKind.chienLoupVillage => l10n.journalChienLoupVillage(player),
    JournalKind.infection => l10n.journalInfection(player),
    JournalKind.bigBadWolfTarget => l10n.journalBigBadWolfTarget(player),
    JournalKind.whiteWolfEats => l10n.journalWhiteWolfEats(player),
    JournalKind.elderSurvives => l10n.journalElderSurvives(player),
    JournalKind.villagersLosePowers => l10n.journalVillagersLosePowers(player),
    JournalKind.knightContaminates => l10n.journalKnightContaminates(player),
    JournalKind.diseaseDeath => l10n.journalDiseaseDeath(player),
    JournalKind.judgeSign => l10n.journalJudgeSign,
    JournalKind.villageDivided => l10n.journalVillageDivided(player, args['other'] ?? ''),
    JournalKind.defenderProtects => l10n.journalDefenderProtects(player),
    JournalKind.defenderSaves => l10n.journalDefenderSaves(player),
    JournalKind.idiotPardoned => l10n.journalIdiotPardoned(player),
    JournalKind.scapegoatBlamed => l10n.journalScapegoatBlamed(player),
    JournalKind.scapegoatVoters => player.isEmpty
        ? l10n.journalScapegoatNobodyVotes
        : l10n.journalScapegoatVoters(player),
    JournalKind.piperCharms =>
      (args['other'] ?? '').isEmpty
          ? l10n.journalPiperCharmsOne(player)
          : l10n.journalPiperCharms(player, args['other']!),
  };
}
