import 'package:flutter/material.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

part 'settings_providers.g.dart';

const _kThemeMode = 'theme_mode';
const _kKeepScreenOn = 'keep_screen_on';
const _kAideMemoire = 'aide_memoire';

/// The one `SharedPreferences` handle. Override in tests with an instance from
/// `SharedPreferences.setMockInitialValues({})`.
@Riverpod(keepAlive: true)
Future<SharedPreferences> sharedPreferences(Ref ref) => SharedPreferences.getInstance();

/// The MJ's persisted preferences. `build` reads them once; each setter writes
/// its key and updates the state so the UI reacts immediately.
@riverpod
class Settings extends _$Settings {
  @override
  Future<AppSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return AppSettings(
      themeMode: switch (prefs.getString(_kThemeMode)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      keepScreenOn: prefs.getBool(_kKeepScreenOn) ?? AppSettings.defaults.keepScreenOn,
      aideMemoireInScript:
          prefs.getBool(_kAideMemoire) ?? AppSettings.defaults.aideMemoireInScript,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_kThemeMode, mode.name);
    state = AsyncData((state.value ?? AppSettings.defaults).copyWith(themeMode: mode));
  }

  Future<void> setKeepScreenOn(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kKeepScreenOn, value);
    state = AsyncData((state.value ?? AppSettings.defaults).copyWith(keepScreenOn: value));
  }

  Future<void> setAideMemoireInScript(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kAideMemoire, value);
    state = AsyncData(
      (state.value ?? AppSettings.defaults).copyWith(aideMemoireInScript: value),
    );
  }
}
