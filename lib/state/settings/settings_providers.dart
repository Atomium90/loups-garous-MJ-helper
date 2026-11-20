import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rules_engine/rules_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings.dart';

part 'settings_providers.g.dart';

const _kThemeMode = 'theme_mode';
const _kKeepScreenOn = 'keep_screen_on';
const _kAideMemoire = 'aide_memoire';
const _kLanguage = 'language';
const _kNarrationLevel = 'narration_level';
const _kNarrationHintSeen = 'narration_hint_seen';
const _kOwnedBoxes = 'owned_boxes';
const _kThiefReserveChosen = 'thief_reserve_chosen';
const _kFoxAfterWitch = 'fox_after_witch';

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
      language: AppLanguage.fromCode(prefs.getString(_kLanguage)),
      narrationLevel: NarrationLevel.fromName(prefs.getString(_kNarrationLevel)),
      narrationHintSeen: prefs.getBool(_kNarrationHintSeen) ?? false,
      ownedBoxes: _readOwnedBoxes(prefs.getStringList(_kOwnedBoxes)),
      thiefReserveChosen: prefs.getBool(_kThiefReserveChosen) ?? false,
      foxAfterWitch: prefs.getBool(_kFoxAfterWitch) ?? false,
    );
  }

  Future<void> setFoxAfterWitch(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kFoxAfterWitch, value);
    state = AsyncData((state.value ?? AppSettings.defaults).copyWith(foxAfterWitch: value));
  }

  Future<void> setThiefReserveChosen(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kThiefReserveChosen, value);
    state = AsyncData(
      (state.value ?? AppSettings.defaults).copyWith(thiefReserveChosen: value),
    );
  }

  /// Ticks or unticks a box. The base box stays owned: the app cannot deal without it.
  Future<void> setBoxOwned(String boxId, bool owned) async {
    if (boxId == baseBoxId || gameBoxById(boxId) == null) return;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    final current = (state.value ?? AppSettings.defaults).ownedBoxes;
    final next = {...current, boxId};
    if (!owned) next.remove(boxId);
    await prefs.setStringList(_kOwnedBoxes, [...next]);
    state = AsyncData((state.value ?? AppSettings.defaults).copyWith(ownedBoxes: next));
  }

  Future<void> setNarrationLevel(NarrationLevel level) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_kNarrationLevel, level.name);
    state = AsyncData((state.value ?? AppSettings.defaults).copyWith(narrationLevel: level));
  }

  /// The MJ has seen the hint about limiting the narration (closed it or opened Réglages).
  Future<void> dismissNarrationHint() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(_kNarrationHintSeen, true);
    state = AsyncData((state.value ?? AppSettings.defaults).copyWith(narrationHintSeen: true));
  }

  Future<void> setLanguage(AppLanguage language) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (language.code == null) {
      await prefs.remove(_kLanguage);
    } else {
      await prefs.setString(_kLanguage, language.code!);
    }
    state = AsyncData((state.value ?? AppSettings.defaults).copyWith(language: language));
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

/// The stored ids, minus the unknown ones, plus the base box. Anything unreadable falls back to
/// the base box alone.
Set<String> _readOwnedBoxes(List<String>? stored) => {
  baseBoxId,
  for (final id in stored ?? const <String>[])
    if (gameBoxById(id) != null) id,
};

/// The boxes the MJ owns, as a [CardPool] over every role the app runs: what the composition
/// and the advisor can offer. Falls back to the base box while the settings load.
@riverpod
CardPool cardPool(Ref ref) {
  final owned = ref.watch(settingsProvider).value?.ownedBoxes;
  return CardPool(registry: RoleRegistry.all, ownedBoxIds: owned ?? const [baseBoxId]);
}
