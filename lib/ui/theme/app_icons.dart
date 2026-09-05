import 'package:flutter/widgets.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

/// Semantic icon names, mapped to `tabler_icons_plus`'s `TablerIcons.*` constants
/// (the design handoff's "Design tokens > Icons" lists the full intended set -
/// only the icons the screens built so far actually use are mapped here).
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

  /// Accueil's empty-state circle.
  static const emptyState = TablerIcons.moonStars;

  /// The most recent "en cours" game's card.
  static const resumeActive = TablerIcons.playerPlayFilled;

  /// Any other "en cours" game's card. Neutral/outline on purpose: with no phase data to back
  /// it, a filled sun/moon phase icon would fabricate a status we don't actually know.
  static const resumeOther = TablerIcons.playerPlay;

  /// The back chevron on the setup screens.
  static const back = TablerIcons.chevronLeft;

  /// The trailing "opens another screen" chevron on nav rows.
  static const chevronRight = TablerIcons.chevronRight;

  /// The composition screen's "Compo complète" check.
  static const compositionComplete = TablerIcons.check;

  /// The composition screen's "Suggestion pour N joueurs" card.
  static const suggestion = TablerIcons.sparkles;

  /// Clear a filled slot back to empty (the Voleur reserve cards).
  static const removeReserve = TablerIcons.x;

  /// The "Distribuez les cartes" callout before night 1.
  static const deal = TablerIcons.cards;

  /// The "Commencer la nuit 1" button.
  static const nightStart = TablerIcons.moonStars;

  /// The disabled "Carnet d'habitués" row (the coming-soon address book).
  static const regulars = TablerIcons.bookmarks;

  // --- Réglages ---

  /// Apparence segmented control: follow the OS.
  static const themeSystem = TablerIcons.deviceMobile;

  /// Apparence segmented control: force light.
  static const themeLight = TablerIcons.sun;

  /// Apparence segmented control: force dark.
  static const themeDark = TablerIcons.moon;

  /// "Garder l'écran allumé" row.
  static const screenOn = TablerIcons.bulb;

  /// "Mes boîtes" row / banner.
  static const boxes = TablerIcons.cards;

  /// The in-game header's "quitter la partie" (back to Accueil, game stays running).
  static const exitGame = TablerIcons.home;

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

  /// The Capitaine (an elected status): the captain election, the succession
  /// panel, the vote grid's crown badge, the Village roster.
  static const captain = TablerIcons.crown;

  /// The village vote.
  static const vote = TablerIcons.gavel;

  /// A tie vote ("Égalité").
  static const scale = TablerIcons.scale;

  /// The Village tab's "Terminer la partie" row.
  static const endGame = TablerIcons.flag;

  // --- end of game / past-game recap ---

  /// The village as a winning side.
  static const home = TablerIcons.home;

  /// "Partie annulée" - nobody won.
  static const cancelled = TablerIcons.circleOff;

  /// The picked winner row's check.
  static const winnerPicked = TablerIcons.circleCheckFilled;

  /// The unpicked winner row's radio.
  static const winnerUnpicked = TablerIcons.circle;

  /// The past-game recap's "Rejouer".
  static const replay = TablerIcons.refresh;

  /// The past-game recap's export (inert for now).
  static const share = TablerIcons.share;

  /// Maps a [NightLogRow.iconName] semantic key to its icon.
  static IconData? nightLog(String key) => switch (key) {
    'wolves' => wolves,
    'seer' => seer,
    'flask' => witch,
    'cupid' => cupid,
    'thief' => thief,
    'skull' => skull,
    'hunter' => hunter,
    'crown' => captain,
    'vote' => vote,
    'scale' => scale,
    'sun' => day,
    _ => null,
  };
}
