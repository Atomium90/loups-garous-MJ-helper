import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the two [ThemeData] the app switches between (`MaterialApp.router(theme:, darkTheme:,
/// themeMode: ThemeMode.system)`), each carrying [AppColors] and [AppTypography] as
/// [ThemeExtension]s so screens read design tokens via `context.colors`/`context.typography`
/// instead of Material's own [ColorScheme]/[TextTheme] roles, which don't line up with this
/// design's own token names.
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light);

  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(AppColors colors) {
    return ThemeData(
      brightness: colors == AppColors.dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.bgApp,
      // The design has near-zero shadow/animation (no gradients, 120-150ms state transitions
      // instead of Material ripples per the README) - suppress the default ink splash rather
      // than have every tappable surface show a Material ripple the design never specifies.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: [colors, AppTypography.standard],
    );
  }
}
