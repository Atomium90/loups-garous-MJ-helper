import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/l10n/localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('resolveAppLocale', () {
    const supported = [Locale('fr'), Locale('en')];

    test('a French device gets French, whatever the region', () {
      expect(resolveAppLocale(const Locale('fr'), supported), const Locale('fr'));
      expect(resolveAppLocale(const Locale('fr', 'CA'), supported), const Locale('fr'));
    });

    test('an English device gets English', () {
      expect(resolveAppLocale(const Locale('en', 'US'), supported), const Locale('en'));
    });

    test('any other language falls back to English', () {
      expect(resolveAppLocale(const Locale('de'), supported), const Locale('en'));
      expect(resolveAppLocale(null, supported), const Locale('en'));
    });
  });

  test('the app is available in French and English', () {
    expect(
      {for (final l in AppLocalizations.supportedLocales) l.languageCode},
      {'fr', 'en'},
    );
  });
}
