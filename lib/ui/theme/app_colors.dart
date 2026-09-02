import 'package:flutter/material.dart';

/// The design handoff's semantic colour tokens ("Design tokens > Colour"), as a
/// [ThemeExtension] so both the light and dark palettes are
/// available anywhere via `Theme.of(context).extension<AppColors>()!` (or the [AppColorsX]
/// shortcut below) without any screen ever hardcoding a hex value.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgApp,
    required this.bgScreen,
    required this.bgInset,
    required this.accentBg,
    required this.accentBorder,
    required this.accentText,
    required this.successBg,
    required this.successText,
    required this.warnBg,
    required this.warnText,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.borderHairline,
    required this.borderControl,
    required this.scrim,
  });

  /// Warm off-white behind everything.
  final Color bgApp;

  /// Screen surface.
  final Color bgScreen;

  /// Cards, role panels, inert fields, avatar fills.
  final Color bgInset;

  /// Primary button fill, selected chip/row fill.
  final Color accentBg;

  /// Primary button border, selected avatar ring.
  final Color accentBorder;

  /// Primary button label, active tab, wolf role names, links.
  final Color accentText;

  /// Available potion pill.
  final Color successBg;

  /// Available potion label, "compo complète".
  final Color successText;

  /// Chained-effect callout, night victim row, captain avatar fill, "bientôt" badge.
  final Color warnBg;

  /// Chained-effect title, captain crown, day icon, "bientôt" label.
  final Color warnText;

  /// Titles, body.
  final Color textPrimary;

  /// Supporting copy, inactive tab labels.
  final Color textSecondary;

  /// Labels, meta, counters, disabled.
  final Color textTertiary;

  /// Row separators, card and avatar outlines.
  final Color borderHairline;

  /// Secondary button, icon button, radio outline.
  final Color borderControl;

  /// Behind modal sheets.
  final Color scrim;

  static const light = AppColors(
    bgApp: Color(0xFFF5F4EF),
    bgScreen: Color(0xFFFFFFFF),
    bgInset: Color(0xFFFAF9F5),
    accentBg: Color(0xFFE8F0FE),
    accentBorder: Color(0xFF2563EB),
    accentText: Color(0xFF1D4ED8),
    successBg: Color(0xFFE6F4EA),
    successText: Color(0xFF1E7A34),
    warnBg: Color(0xFFFEF3E0),
    warnText: Color(0xFF92600A),
    textPrimary: Color(0xFF1A1A18),
    textSecondary: Color(0xFF6B6A64),
    textTertiary: Color(0xFF9B9A93),
    borderHairline: Color(0x14000000), // rgba(0,0,0,0.08)
    borderControl: Color(0x2E000000), // rgba(0,0,0,0.18)
    scrim: Color(0x5214130F), // rgba(20,19,15,0.32)
  );

  // Two rules govern the mapping (README): surfaces get lighter with depth
  // (app -> screen -> card), the inverse of light; tinted backgrounds lose
  // luminosity but keep their hue, so a warning never reads as an ordinary
  // card. The README's dark table doesn't list a dark-specific scrim, so it
  // stays the same value as light.
  static const dark = AppColors(
    bgApp: Color(0xFF14130F),
    bgScreen: Color(0xFF1C1A16),
    bgInset: Color(0xFF24221D),
    accentBg: Color(0xFF1B2A4A),
    accentBorder: Color(0xFF3B82F6),
    accentText: Color(0xFF93B4FC),
    successBg: Color(0xFF16301F),
    successText: Color(0xFF6FCF8C),
    warnBg: Color(0xFF33260F),
    warnText: Color(0xFFE0B058),
    textPrimary: Color(0xFFF2F0EA),
    textSecondary: Color(0xFFA8A49A),
    textTertiary: Color(0xFF767268),
    borderHairline: Color(0x1AFFFFFF), // rgba(255,255,255,0.10)
    borderControl: Color(0x2EFFFFFF), // rgba(255,255,255,0.18)
    scrim: Color(0x5214130F),
  );

  @override
  AppColors copyWith({
    Color? bgApp,
    Color? bgScreen,
    Color? bgInset,
    Color? accentBg,
    Color? accentBorder,
    Color? accentText,
    Color? successBg,
    Color? successText,
    Color? warnBg,
    Color? warnText,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? borderHairline,
    Color? borderControl,
    Color? scrim,
  }) {
    return AppColors(
      bgApp: bgApp ?? this.bgApp,
      bgScreen: bgScreen ?? this.bgScreen,
      bgInset: bgInset ?? this.bgInset,
      accentBg: accentBg ?? this.accentBg,
      accentBorder: accentBorder ?? this.accentBorder,
      accentText: accentText ?? this.accentText,
      successBg: successBg ?? this.successBg,
      successText: successText ?? this.successText,
      warnBg: warnBg ?? this.warnBg,
      warnText: warnText ?? this.warnText,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      borderHairline: borderHairline ?? this.borderHairline,
      borderControl: borderControl ?? this.borderControl,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    // Nothing in the design animates a light/dark transition (no gradients,
    // near-zero shadow/animation per the README) - a real per-field
    // Color.lerp would just be unused precision, so snap at the midpoint.
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

/// `context.colors` shortcut for `Theme.of(context).extension<AppColors>()!`.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
