import '../../l10n/localizations.dart';
import '../../state/settings/settings.dart';

/// One thing the MJ can say: the [head] is the essential, the [body] the rest. The *short*
/// narration reads only heads, the *full* one reads both.
class NarrationLine {
  const NarrationLine(this.head, [this.body]);

  final String head;
  final String? body;

  /// The text to show at [level]; empty when the narration is off.
  String textAt(NarrationLevel level) => switch (level) {
    NarrationLevel.off => '',
    NarrationLevel.short => head,
    NarrationLevel.full => body == null ? head : '$head $body',
  };
}

/// Said when the night begins, before the first role is woken.
List<NarrationLine> nightStartNarration(AppLocalizations l10n) => [
  NarrationLine(l10n.narrNightStart),
];

/// Waking a role, telling it what to do, and putting it back to sleep. Empty for a role that
/// has no lines (it has no night call); a role settled before the night (a card shown at the
/// deal) has no one to put back to sleep.
List<NarrationLine> roleCallNarration(AppLocalizations l10n, String roleId) {
  final head = l10n.narrCallHead(roleId);
  if (head.isEmpty) return const [];
  final close = l10n.narrClose(roleId);
  return [
    NarrationLine(head, _orNull(l10n.narrCallBody(roleId))),
    if (close.isNotEmpty) NarrationLine(close),
  ];
}

/// The morning: the village wakes up, then who died in the night.
List<NarrationLine> morningNarration(AppLocalizations l10n, List<String> deathNames) => [
  NarrationLine(l10n.narrMorningHead, l10n.narrMorningBody),
  NarrationLine(
    l10n.narrDeathsHead(deathNames.length, joinNames(l10n, deathNames)),
    deathNames.isEmpty ? null : l10n.narrDeathsBody,
  ),
];

List<NarrationLine> captainNarration(AppLocalizations l10n) => [
  NarrationLine(l10n.narrCaptainHead, l10n.narrCaptainBody),
];

/// What the MJ says for the Bear Tamer's growl.
List<NarrationLine> growlNarration(AppLocalizations l10n) => [
  NarrationLine(l10n.narrGrowlHead, l10n.narrGrowlBody),
];

List<NarrationLine> voteNarration(AppLocalizations l10n) => [
  NarrationLine(l10n.narrVoteHead, l10n.narrVoteBody),
];

/// Said to a player whose card is about to be turned over.
List<NarrationLine> revealNarration(AppLocalizations l10n, String name) => [
  NarrationLine(l10n.narrRevealHead(name), l10n.narrRevealBody),
];

List<NarrationLine> hunterNarration(AppLocalizations l10n) => [
  NarrationLine(l10n.narrHunterHead, l10n.narrHunterBody),
];

List<NarrationLine> successionNarration(AppLocalizations l10n) => [
  NarrationLine(l10n.narrSuccessionHead, l10n.narrSuccessionBody),
];

/// Said to the lover who dies of heartbreak.
List<NarrationLine> loversNarration(AppLocalizations l10n, String name) => [
  NarrationLine(l10n.narrLoversHead(name), l10n.narrLoversBody),
];

/// "Ana", "Ana et Bo", "Ana, Bo et Cy" (or with "and").
String joinNames(AppLocalizations l10n, List<String> names) {
  if (names.length < 2) return names.join();
  final last = names.last;
  final rest = names.sublist(0, names.length - 1).join(', ');
  return l10n.narrNames(rest, last);
}

String? _orNull(String text) => text.isEmpty ? null : text;
