import 'package:material_ui/material_ui.dart' show ThemeMode;
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
    expect(settings.language, AppLanguage.system);
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

  group('the language', () {
    test('is read from the stored code', () async {
      final container = await containerWith({'language': 'en'});

      expect((await container.read(settingsProvider.future)).language, AppLanguage.english);
    });

    test('an unknown stored code means follow the device', () async {
      final container = await containerWith({'language': 'xx'});

      expect((await container.read(settingsProvider.future)).language, AppLanguage.system);
    });

    test('is stored by code, and removed when going back to the device language', () async {
      final container = await containerWith({});
      await container.read(settingsProvider.future);
      final notifier = container.read(settingsProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      await notifier.setLanguage(AppLanguage.french);
      expect(container.read(settingsProvider).value?.language, AppLanguage.french);
      expect(prefs.getString('language'), 'fr');

      await notifier.setLanguage(AppLanguage.system);
      expect(container.read(settingsProvider).value?.language, AppLanguage.system);
      expect(prefs.containsKey('language'), isFalse);
    });

    test('each choice maps to the locale to force', () {
      expect(AppLanguage.system.locale, isNull);
      expect(AppLanguage.french.locale?.languageCode, 'fr');
      expect(AppLanguage.english.locale?.languageCode, 'en');
    });
  });

  test('AppSettings.copyWith leaves other fields intact', () {
    const s = AppSettings.defaults;
    expect(s.copyWith(keepScreenOn: false).themeMode, ThemeMode.system);
    expect(s.copyWith(keepScreenOn: false).aideMemoireInScript, isTrue);
    expect(s.copyWith(language: AppLanguage.english).keepScreenOn, isTrue);
  });
}
