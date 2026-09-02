import 'package:rules_engine/rules_engine.dart';

/// The day recap's cause line: "Victime des Loups", "Potion de mort de la
/// Sorcière".
String frenchDeathCauseLabel(DeathCause cause) => switch (cause) {
  WolvesKill() => 'Victime des Loups',
  WitchDeathPotionKill() => 'Potion de mort de la Sorcière',
  DayVoteKill() => 'Vote du village',
  HunterShotKill() => 'Tir du Chasseur',
  LoversCascadeKill() => 'Mort de chagrin',
};

/// The Village tab's terse sub-line, after the phase: "Nuit 3 · potion de mort".
String frenchDeathCauseShort(DeathCause cause) => switch (cause) {
  WolvesKill() => 'Loups',
  WitchDeathPotionKill() => 'potion de mort',
  DayVoteKill() => 'vote du village',
  HunterShotKill() => 'tir du Chasseur',
  LoversCascadeKill() => 'mort de chagrin',
};
