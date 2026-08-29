import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Semantic icon names, mapped to `tabler_icons_plus`'s `TablerIcons.*` constants (see
/// `claude/design_handoff_loup_garou_mj/README.md`, "Design tokens > Icons" for the full
/// intended set - only the icons the screens built so far actually use are mapped here).
///
/// Call sites read `AppIcons.settings`, not `TablerIcons.settings`, for the same reason
/// [AppColors]/[AppSpacing] are centralised: `tabler_icons_plus` auto-syncs from upstream
/// Tabler Icons daily, so a future rename/removal there should only ever require touching this
/// one file, not every screen that renders an icon.
abstract final class AppIcons {
  /// Header icon button, routes to Réglages (not built yet).
  static const settings = TablerIcons.settings;

  /// "Nouvelle partie" button and header icon button.
  static const newGame = TablerIcons.plus;

  /// E0's empty-state circle.
  static const emptyState = TablerIcons.moonStars;

  /// The most recent "en cours" game's card.
  static const resumeActive = TablerIcons.playerPlayFilled;

  /// Any other "en cours" game's card. Neutral/outline on purpose: with no phase data to back
  /// it, a filled sun/moon phase icon would fabricate a status we don't actually know.
  static const resumeOther = TablerIcons.playerPlay;

  /// E2's back chevron. Also A1/A2's.
  static const back = TablerIcons.chevronLeft;

  /// E2's "Compo complète" check.
  static const compositionComplete = TablerIcons.check;

  /// A2's "Distribuez les cartes" callout.
  static const deal = TablerIcons.cards;

  /// A2's "Commencer la nuit 1" button.
  static const nightStart = TablerIcons.moonStars;

  /// A1's disabled "Carnet d'habitués" row (the coming-soon address book).
  static const regulars = TablerIcons.bookmarks;
}
