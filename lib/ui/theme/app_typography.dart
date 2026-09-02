import 'package:flutter/material.dart';

/// The design handoff's type scale ("Design tokens > Typography"), as a
/// [ThemeExtension]. Only the roles actually used by a screen built so far are
/// defined here - extend as later screens need new roles (avatar initials, sheet
/// title, stat number, tab label, etc. aren't here yet).
///
/// Styles carry size/weight/height/letterSpacing only, deliberately never a [Color]: colour
/// comes from [AppColors] at the call site (e.g. `typography.body.copyWith(color:
/// colors.textSecondary)`). Baking colour into named styles here would mean one style per
/// role-times-colour combination instead of composing the two independently.
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.screenTitle,
    required this.rowLabel,
    required this.body,
    required this.meta,
    required this.chipLabel,
    required this.counter,
    required this.sectionLabel,
    required this.micro,
    required this.stepperValue,
  });

  /// "Mes parties", "Composition" - 18/500.
  final TextStyle screenTitle;

  /// Row label, button label - 14/500 (README: "Row label, button label | 14/400–500").
  final TextStyle rowLabel;

  /// Body, list item - 13/400, line-height 1.5.
  final TextStyle body;

  /// Meta line: subtitle, resume line, group label - 12/400.
  final TextStyle meta;

  /// Chip/pill label - 12/500.
  final TextStyle chipLabel;

  /// Counter, trailing meta - 11/400.
  final TextStyle counter;

  /// Uppercase section header ("EN COURS", "HISTORIQUE") - 11/400, 0.06em letter-spacing.
  final TextStyle sectionLabel;

  /// Smallest meta text: day-count badge, month label - 10/400.
  final TextStyle micro;

  /// The number inside a stepper control (the composition screen's player-count row) - 15/500.
  final TextStyle stepperValue;

  // System UI sans per the README ("-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto").
  // Flutter has no direct equivalent of a CSS font-family stack; leaving fontFamily null falls
  // back to the platform default (San Francisco on iOS, Roboto on Android), which is the
  // intended behaviour here, not an omission.
  static const _weightRegular = FontWeight.w400;
  static const _weightMedium = FontWeight.w500;

  static const standard = AppTypography(
    screenTitle: TextStyle(fontSize: 18, fontWeight: _weightMedium),
    rowLabel: TextStyle(fontSize: 14, fontWeight: _weightMedium),
    body: TextStyle(fontSize: 13, fontWeight: _weightRegular, height: 1.5),
    meta: TextStyle(fontSize: 12, fontWeight: _weightRegular),
    chipLabel: TextStyle(fontSize: 12, fontWeight: _weightMedium),
    counter: TextStyle(fontSize: 11, fontWeight: _weightRegular),
    // CSS `0.06em` is relative to font-size; Flutter's TextStyle.letterSpacing is logical
    // pixels, so it has to be computed from the size (11 * 0.06), not hardcoded as "0.06".
    sectionLabel: TextStyle(fontSize: 11, fontWeight: _weightRegular, letterSpacing: 11 * 0.06),
    micro: TextStyle(fontSize: 10, fontWeight: _weightRegular),
    stepperValue: TextStyle(fontSize: 15, fontWeight: _weightMedium),
  );

  @override
  AppTypography copyWith({
    TextStyle? screenTitle,
    TextStyle? rowLabel,
    TextStyle? body,
    TextStyle? meta,
    TextStyle? chipLabel,
    TextStyle? counter,
    TextStyle? sectionLabel,
    TextStyle? micro,
    TextStyle? stepperValue,
  }) {
    return AppTypography(
      screenTitle: screenTitle ?? this.screenTitle,
      rowLabel: rowLabel ?? this.rowLabel,
      body: body ?? this.body,
      meta: meta ?? this.meta,
      chipLabel: chipLabel ?? this.chipLabel,
      counter: counter ?? this.counter,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      micro: micro ?? this.micro,
      stepperValue: stepperValue ?? this.stepperValue,
    );
  }

  @override
  AppTypography lerp(ThemeExtension<AppTypography>? other, double t) {
    // Typography doesn't vary by brightness in this design - nothing to interpolate.
    if (other is! AppTypography) return this;
    return t < 0.5 ? this : other;
  }
}

/// `context.typography` shortcut for `Theme.of(context).extension<AppTypography>()!`.
extension AppTypographyX on BuildContext {
  AppTypography get typography => Theme.of(this).extension<AppTypography>()!;
}
