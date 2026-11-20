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

  group('the narration', () {
    test('is full by default, with its hint not yet seen', () async {
      final container = await containerWith({});
      final settings = await container.read(settingsProvider.future);

      expect(settings.narrationLevel, NarrationLevel.full);
      expect(settings.narrationHintSeen, isFalse);
    });

    test('reads the stored level, and an unknown one means full', () async {
      final short = await containerWith({'narration_level': 'short'});
      expect((await short.read(settingsProvider.future)).narrationLevel, NarrationLevel.short);

      final unknown = await containerWith({'narration_level': 'loud'});
      expect((await unknown.read(settingsProvider.future)).narrationLevel, NarrationLevel.full);
    });

    test('the level and the seen hint persist', () async {
      final container = await containerWith({});
      await container.read(settingsProvider.future);
      final notifier = container.read(settingsProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      await notifier.setNarrationLevel(NarrationLevel.off);
      await notifier.dismissNarrationHint();

      final settings = container.read(settingsProvider).value!;
      expect(settings.narrationLevel, NarrationLevel.off);
      expect(settings.narrationHintSeen, isTrue);
      expect(prefs.getString('narration_level'), 'off');
      expect(prefs.getBool('narration_hint_seen'), isTrue);
    });
  });

  group('the White Werewolf parity', () {
    test('is the even nights by default, and the choice persists', () async {
      final container = await containerWith({});
      expect((await container.read(settingsProvider.future)).whiteWolfOddNights, isFalse);

      await container.read(settingsProvider.notifier).setWhiteWolfOddNights(true);

      expect(container.read(settingsProvider).value!.whiteWolfOddNights, isTrue);
      expect((await SharedPreferences.getInstance()).getBool('white_wolf_odd_nights'), isTrue);
    });
  });

  group('the Fox position', () {
    test('is after the Seer by default, and the choice persists', () async {
      final container = await containerWith({});
      expect((await container.read(settingsProvider.future)).foxAfterWitch, isFalse);

      await container.read(settingsProvider.notifier).setFoxAfterWitch(true);

      expect(container.read(settingsProvider).value!.foxAfterWitch, isTrue);
      expect((await SharedPreferences.getInstance()).getBool('fox_after_witch'), isTrue);
    });
  });

  group('the Thief reserve', () {
    test('is drawn at random by default', () async {
      final container = await containerWith({});
      expect((await container.read(settingsProvider.future)).thiefReserveChosen, isFalse);
    });

    test('the choice persists', () async {
      final container = await containerWith({});
      await container.read(settingsProvider.future);
      await container.read(settingsProvider.notifier).setThiefReserveChosen(true);

      expect(container.read(settingsProvider).value!.thiefReserveChosen, isTrue);
      expect((await SharedPreferences.getInstance()).getBool('thief_reserve_chosen'), isTrue);
    });
  });

  group('the owned boxes', () {
    test('default to the base box alone', () async {
      final container = await containerWith({});
      final settings = await container.read(settingsProvider.future);
      expect(settings.ownedBoxes, {'base'});
      expect(container.read(cardPoolProvider).ownedBoxIds, {'base'});
    });

    test('read the stored ids, drop unknown ones and always keep the base box', () async {
      final container = await containerWith({
        'owned_boxes': ['best_of', 'nope'],
      });
      final settings = await container.read(settingsProvider.future);
      expect(settings.ownedBoxes, {'base', 'best_of'});
    });

    test('ticking and unticking a box persists and moves the card pool', () async {
      final container = await containerWith({});
      await container.read(settingsProvider.future);
      final notifier = container.read(settingsProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      await notifier.setBoxOwned('best_of', true);
      expect(container.read(settingsProvider).value!.ownedBoxes, {'base', 'best_of'});
      expect(prefs.getStringList('owned_boxes'), unorderedEquals(['base', 'best_of']));
      expect(container.read(cardPoolProvider).ownedBoxIds, {'base', 'best_of'});

      await notifier.setBoxOwned('best_of', false);
      expect(container.read(settingsProvider).value!.ownedBoxes, {'base'});
    });

    test('the base box cannot be unticked and an unknown box cannot be ticked', () async {
      final container = await containerWith({});
      await container.read(settingsProvider.future);
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setBoxOwned('base', false);
      await notifier.setBoxOwned('nope', true);

      expect(container.read(settingsProvider).value!.ownedBoxes, {'base'});
    });
  });

  test('AppSettings.copyWith leaves other fields intact', () {
    const s = AppSettings.defaults;
    expect(s.copyWith(keepScreenOn: false).themeMode, ThemeMode.system);
    expect(s.copyWith(keepScreenOn: false).aideMemoireInScript, isTrue);
    expect(s.copyWith(language: AppLanguage.english).keepScreenOn, isTrue);
    expect(s.copyWith(narrationLevel: NarrationLevel.off).narrationHintSeen, isFalse);
  });
}
