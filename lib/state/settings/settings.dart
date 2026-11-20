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
  );
}
