import 'package:material_ui/material_ui.dart' show Locale, ThemeMode;
import 'package:rules_engine/rules_engine.dart' show baseBoxId;

/// The language of the app: follow the device, or force one of the two it speaks.
enum AppLanguage {
  system(null),
  french('fr'),
  english('en');

  const AppLanguage(this.code);

  /// The stored language code, null for [system].
  final String? code;

  /// The locale to force, or null to follow the device.
  Locale? get locale => code == null ? null : Locale(code!);

  static AppLanguage fromCode(String? code) =>
      values.firstWhere((l) => l.code == code, orElse: () => system);
}

/// How much of the script the MJ gets to read aloud: nothing, only the essential line of each
/// moment, or all of it.
enum NarrationLevel {
  off,
  short,
  full;

  static NarrationLevel fromName(String? name) =>
      values.firstWhere((l) => l.name == name, orElse: () => defaults);

  static const defaults = full;
}

/// What happens when the village vote is tied (the Scapegoat, when he is in play, always comes first).
enum VoteTieRule {
  /// Nobody is eliminated (the Base and Pact booklets).
  nobody,

  /// The Capitaine decides between the tied players.
  captainDecides,

  /// A second vote among the tied players (the Best Of booklet).
  revote;

  static VoteTieRule fromName(String? name) =>
      values.firstWhere((r) => r.name == name, orElse: () => nobody);
}

/// The MJ's app-wide preferences, persisted via `shared_preferences`.
/// Hand-written (like `SessionCursor` / `DaySnapshot`) - a handful of fields and no
/// JSON, so freezed / json_serializable would be overhead.
class AppSettings {
  /// Manual override of the OS theme. [ThemeMode.system] follows the device.
  final ThemeMode themeMode;

  /// Keep the screen awake while the in-game shell is on screen.
  final bool keepScreenOn;

  /// Show the `?` aide-mémoire button in the in-game header (Script tab).
  final bool aideMemoireInScript;

  /// The app's language. [AppLanguage.system] follows the device.
  final AppLanguage language;

  /// How much narration the script shows.
  final NarrationLevel narrationLevel;

  /// Whether the in-game hint about limiting the narration has been dealt with.
  final bool narrationHintSeen;

  /// Ids of the boxes the MJ owns. Always holds the base box.
  final Set<String> ownedBoxes;

  /// House rule: the MJ picks the Thief's two reserve cards at the composition. Off (the
  /// booklet's rule): the reserve is whatever two cards are left after the deal, noted on night 1.
  final bool thiefReserveChosen;

  /// The Fox is called after the Witch (the Best Of booklet) instead of after the Seer (the Pact
  /// booklet, the default). The booklets disagree.
  final bool foxAfterWitch;

  /// The White Werewolf's solo night falls on the odd nights (1, 3, 5...) instead of the even ones
  /// (2, 4, 6..., the default). The booklets do not say which.
  final bool whiteWolfOddNights;

  /// The Knight's disease strikes at the end of the next night (the Characters booklet) instead of
  /// its beginning (the Best Of booklet, the default). Same effect for the players.
  final bool knightDiseaseAtNightEnd;

  /// What a tied village vote does.
  final VoteTieRule voteTieRule;

  /// The MJ lets the app send anonymous crash reports. Off until they say so.
  final bool crashReports;

  /// The app only asks the MJ to note each player's role at the deal when the composition holds a
  /// role that needs it (the Fox, the Elder...). Off: it always offers to.
  final bool dealNotesOnlyIfNeeded;

  /// The dead turn their card over in front of the table (the usual rule). Off, the roles stay
  /// secret: the MJ is told not to have them shown, and notes a dead player's card in private.
  final bool revealDeadCards;

  const AppSettings({
    required this.themeMode,
    required this.keepScreenOn,
    required this.aideMemoireInScript,
    required this.language,
    required this.narrationLevel,
    required this.narrationHintSeen,
    required this.ownedBoxes,
    required this.thiefReserveChosen,
    required this.foxAfterWitch,
    required this.whiteWolfOddNights,
    required this.knightDiseaseAtNightEnd,
    required this.voteTieRule,
    required this.crashReports,
    required this.dealNotesOnlyIfNeeded,
    required this.revealDeadCards,
  });

  static const defaults = AppSettings(
    themeMode: ThemeMode.system,
    keepScreenOn: true,
    aideMemoireInScript: true,
    language: AppLanguage.system,
    narrationLevel: NarrationLevel.defaults,
    narrationHintSeen: false,
    ownedBoxes: {baseBoxId},
    thiefReserveChosen: false,
    foxAfterWitch: false,
    whiteWolfOddNights: false,
    knightDiseaseAtNightEnd: false,
    voteTieRule: VoteTieRule.nobody,
    crashReports: false,
    dealNotesOnlyIfNeeded: false,
    revealDeadCards: true,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? keepScreenOn,
    bool? aideMemoireInScript,
    AppLanguage? language,
    NarrationLevel? narrationLevel,
    bool? narrationHintSeen,
    Set<String>? ownedBoxes,
    bool? thiefReserveChosen,
    bool? foxAfterWitch,
    bool? whiteWolfOddNights,
    bool? knightDiseaseAtNightEnd,
    VoteTieRule? voteTieRule,
    bool? crashReports,
    bool? dealNotesOnlyIfNeeded,
    bool? revealDeadCards,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    aideMemoireInScript: aideMemoireInScript ?? this.aideMemoireInScript,
    language: language ?? this.language,
    narrationLevel: narrationLevel ?? this.narrationLevel,
    narrationHintSeen: narrationHintSeen ?? this.narrationHintSeen,
    ownedBoxes: ownedBoxes ?? this.ownedBoxes,
    thiefReserveChosen: thiefReserveChosen ?? this.thiefReserveChosen,
    foxAfterWitch: foxAfterWitch ?? this.foxAfterWitch,
    whiteWolfOddNights: whiteWolfOddNights ?? this.whiteWolfOddNights,
    knightDiseaseAtNightEnd: knightDiseaseAtNightEnd ?? this.knightDiseaseAtNightEnd,
    voteTieRule: voteTieRule ?? this.voteTieRule,
    crashReports: crashReports ?? this.crashReports,
    dealNotesOnlyIfNeeded: dealNotesOnlyIfNeeded ?? this.dealNotesOnlyIfNeeded,
    revealDeadCards: revealDeadCards ?? this.revealDeadCards,
  );
}
