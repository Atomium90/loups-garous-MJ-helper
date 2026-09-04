import 'package:flutter/material.dart' show ThemeMode;

/// The MJ's app-wide preferences, persisted via `shared_preferences`.
/// Hand-written (like `SessionCursor` / `DaySnapshot`) - three fields and no
/// JSON, so freezed / json_serializable would be overhead.
class AppSettings {
  /// Manual override of the OS theme. [ThemeMode.system] follows the device.
  final ThemeMode themeMode;

  /// Keep the screen awake while the in-game shell is on screen.
  final bool keepScreenOn;

  /// Show the `?` aide-mémoire button in the in-game header (Script tab).
  final bool aideMemoireInScript;

  const AppSettings({
    required this.themeMode,
    required this.keepScreenOn,
    required this.aideMemoireInScript,
  });

  static const defaults = AppSettings(
    themeMode: ThemeMode.system,
    keepScreenOn: true,
    aideMemoireInScript: true,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? keepScreenOn,
    bool? aideMemoireInScript,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    aideMemoireInScript: aideMemoireInScript ?? this.aideMemoireInScript,
  );
}
