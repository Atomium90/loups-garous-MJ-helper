import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/settings/settings.dart';
import 'package:loup_garou_mj/state/settings/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWith((ref) async => prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to system theme and both toggles on when nothing is stored', () async {
    final container = await containerWith({});
    final settings = await container.read(settingsProvider.future);

    expect(settings.themeMode, ThemeMode.system);
    expect(settings.keepScreenOn, isTrue);
    expect(settings.aideMemoireInScript, isTrue);
  });

  test('reads stored values', () async {
    final container = await containerWith({
      'theme_mode': 'dark',
      'keep_screen_on': false,
      'aide_memoire': false,
    });
    final settings = await container.read(settingsProvider.future);

    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.keepScreenOn, isFalse);
    expect(settings.aideMemoireInScript, isFalse);
  });

  test('a setter updates the state and persists', () async {
    final container = await containerWith({});
    await container.read(settingsProvider.future);
    final notifier = container.read(settingsProvider.notifier);

    await notifier.setThemeMode(ThemeMode.light);
    await notifier.setKeepScreenOn(false);

    expect(container.read(settingsProvider).value?.themeMode, ThemeMode.light);
    expect(container.read(settingsProvider).value?.keepScreenOn, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
    expect(prefs.getBool('keep_screen_on'), isFalse);
  });

  test('AppSettings.copyWith leaves other fields intact', () {
    const s = AppSettings.defaults;
    expect(s.copyWith(keepScreenOn: false).themeMode, ThemeMode.system);
    expect(s.copyWith(keepScreenOn: false).aideMemoireInScript, isTrue);
  });
}
