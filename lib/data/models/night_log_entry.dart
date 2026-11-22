import 'dart:convert';

/// Which half of a game a journal line belongs to.
enum JournalPhase { night, day }

/// What a journal line says happened. The words come from the app's language at
/// display time; the line itself stores only this and its [NightLogEntry.args].
///
/// Args keys: `player` (a player's name), `other` (a second one), `role` (a role id).
enum JournalKind {
  wolvesTarget('wolves'),
  witchSave('flask'),
  witchPoison('flask'),
  cupidPair('cupid'),
  thiefKeep('thief'),
  thiefSwap('thief'),
  captainElected('crown'),
  captainSuccessor('crown'),
  villageEliminates('vote'),
  voteTie('scale'),
  hunterNoShot('hunter'),
  hunterShoots('hunter'),
  seerObserves('seer'),
  heartbreakDeath('skull'),
  foxFindsWolf('fox'),
  foxFindsNone('fox'),
  sistersMeet('sisters'),
  brothersMeet('sisters'),
  bearGrowls('bear'),
  wildChildModel('wildChild'),
  chienLoupWolf('dog'),
  chienLoupVillage('dog'),
  infection('infect'),
  bigBadWolfTarget('wolves'),
  whiteWolfEats('wolves'),
  elderSurvives('elder'),
  villagersLosePowers('elder'),
  knightContaminates('sword'),
  diseaseDeath('skull'),
  piperCharms('piper'),
  defenderProtects('defender'),
  defenderSaves('defender'),
  idiotPardoned('vote'),
  scapegoatBlamed('scale'),
  scapegoatVoters('vote');

  const JournalKind(this.iconName);

  /// Semantic key the UI maps to an `AppIcons` entry.
  final String iconName;

  static JournalKind? fromName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// A journal line to append, before it has a `seq` or an id. The state layer
/// builds these from engine events; [GameRepository.appendNightLog] assigns
/// the ordering and persists them as `NightLogRow`s. Pure data: turning one into a sentence
/// is the UI's job, in the language the MJ has chosen.
class NightLogEntry {
  final JournalPhase phase;

  /// The night number the phase header counts (night 1, day 1, night 2, ...).
  final int phaseIndex;
  final JournalKind kind;
  final Map<String, String> args;

  const NightLogEntry({
    required this.phase,
    required this.phaseIndex,
    required this.kind,
    this.args = const {},
  });

  String get iconName => kind.iconName;

  String get argsJson => jsonEncode(args);

  /// The args of a stored line; empty if there are none or they can't be read.
  static Map<String, String> decodeArgs(String? json) {
    if (json == null) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return const {};
      return {for (final e in decoded.entries) '${e.key}': '${e.value}'};
    } on FormatException {
      return const {};
    }
  }
}
