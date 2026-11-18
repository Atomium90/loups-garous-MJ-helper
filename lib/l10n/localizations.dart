import 'package:material_ui/material_ui.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// The delegates the app's `MaterialApp` needs: the app's own texts, then the Material, widgets
/// and Cupertino translations of the `material_ui` package. Listed by hand rather than taken
/// from [AppLocalizations.localizationsDelegates], which carries Flutter's own Material
/// translations instead of the ones the widgets in use rely on.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

/// French for a French device, English for any other language.
Locale resolveAppLocale(Locale? deviceLocale, Iterable<Locale> supportedLocales) =>
    deviceLocale?.languageCode == 'fr' ? const Locale('fr') : const Locale('en');
