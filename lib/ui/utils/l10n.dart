import 'package:material_ui/material_ui.dart';

import '../../l10n/localizations.dart';

/// `context.l10n.someText`: the app's translated texts for the current language.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
