import 'package:flutter/widgets.dart';
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

  // --- in-game tab bar ---

  /// Script tab, night phase.
  static const night = TablerIcons.moonStars;

  /// Script tab, day phase.
  static const day = TablerIcons.sun;

  /// Village tab.
  static const village = TablerIcons.users;

  /// Journal tab.
  static const journal = TablerIcons.listDetails;

  /// The script card's `?` help button (opens the aide-mémoire).
  static const help = TablerIcons.help;

  // --- night script / journal ---

  static const wolves = TablerIcons.moodWrrr;
  static const seer = TablerIcons.eye;
  static const witch = TablerIcons.flask;
  static const cupid = TablerIcons.heart;
  static const thief = TablerIcons.cards;
  static const skull = TablerIcons.skull;
  static const hunter = TablerIcons.crosshair;

  /// The Witch's "Elle sauve X" button.
  static const witchSave = TablerIcons.heartPlus;

  // --- day loop ---

  /// The Capitaine (an elected status): J2, the succession panel, the vote
  /// grid's crown badge, the Village roster.
  static const captain = TablerIcons.crown;

  /// J3, the village vote.
  static const vote = TablerIcons.gavel;

  /// A tie vote ("Égalité").
  static const scale = TablerIcons.scale;

  /// Maps a [NightLogRow.iconName] semantic key to its icon.
  static IconData? nightLog(String key) => switch (key) {
    'wolves' => wolves,
    'flask' => witch,
    'cupid' => cupid,
    'skull' => skull,
    'hunter' => hunter,
    'crown' => captain,
    'vote' => vote,
    'scale' => scale,
    'sun' => day,
    _ => null,
  };
}
