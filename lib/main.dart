import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/localizations.dart';
import 'state/settings/settings.dart';
import 'state/settings/settings_providers.dart';
import 'ui/router/app_router.dart';
import 'ui/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Falls back to the OS theme until the stored preference has loaded.
    final settings = ref.watch(settingsProvider).value ?? AppSettings.defaults;
    return MaterialApp.router(
      routerConfig: ref.watch(appRouterProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.language.locale,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: resolveAppLocale,
    );
  }
}
