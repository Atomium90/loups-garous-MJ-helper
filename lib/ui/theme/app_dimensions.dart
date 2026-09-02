/// The design handoff's spacing/radii/sizes tables ("Design tokens > Spacing,
/// radii, sizes"), transcribed as plain constants.
///
/// Unlike [AppColors]/[AppTypography] these don't vary by brightness, so they're not
/// [ThemeExtension]s - just `import` and use directly. Transcribed in full even where the
/// screens don't use every value yet: it's pure data entry with no judgement calls,
/// so there's nothing to lose by encoding the whole table once instead of extending it
/// piecemeal per screen. The one deliberate omission is the 28px "device frame" radius: the
/// handoff explicitly calls the mockups' fixed frames a phone stand-in for the board, not
/// something the real (full-screen) app has a use for.
library;

/// Padding and gaps.
abstract final class AppSpacing {
  /// Screen horizontal padding.
  static const double screen = 20;

  /// Section gap, lower end of the README's 14-20 range.
  static const double sectionGapSmall = 14;

  /// Section gap, upper end of the README's 14-20 range.
  static const double sectionGapLarge = 20;

  /// Row vertical padding in lists.
  static const double rowList = 9;

  /// Row vertical padding in settings-style rows.
  static const double rowSettings = 13;

  /// Selection-grid row gap.
  static const double gridGapRow = 12;

  /// Selection-grid column gap.
  static const double gridGapColumn = 8;
}

/// Corner radii.
abstract final class AppRadii {
  /// Bottom-sheet top corners.
  static const double sheetTop = 20;

  /// Role/script card.
  static const double card = 16;

  /// Small card.
  static const double cardSmall = 12;

  /// Buttons, rows, chips-as-boxes.
  static const double button = 8;

  /// Pills.
  static const double pill = 999;
}

/// Fixed control/avatar sizes.
abstract final class AppSizes {
  static const double buttonPrimaryHeight = 44;
  static const double buttonSecondaryHeight = 38;

  static const double iconButton = 36;
  static const double iconButtonDense = 30;

  /// Dense lists, recap.
  static const double avatarDense = 28;

  /// Victim row.
  static const double avatarVictimRow = 30;

  /// Village roster.
  static const double avatarRoster = 32;

  /// Selection grids.
  static const double avatarSelectionGrid = 40;

  /// Day recap.
  static const double avatarDayRecap = 42;

  /// Vote grid - deliberately the largest, per the README.
  static const double avatarVoteGrid = 44;

  /// Death sheet.
  static const double avatarDeathSheet = 56;

  /// Midpoint of the README's 58-60 tab bar height range.
  static const double tabBar = 59;

  static const double toggleTrackWidth = 40;
  static const double toggleTrackHeight = 24;
  static const double toggleKnob = 20;
  static const double toggleInset = 2;

  /// Selection grid columns, default.
  static const int gridColumnsDefault = 4;

  /// Selection grid columns, when the pool is small.
  static const int gridColumnsSmallPool = 3;
}
