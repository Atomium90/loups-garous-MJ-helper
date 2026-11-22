import 'package:rules_engine/rules_engine.dart';

import '../../data/database/app_database.dart';
import '../../l10n/localizations.dart';
import 'journal_labels.dart';
import 'labels.dart';

/// The journal of [game] as plain text, to share: a short header (title, date, winner, deck), then
/// every line from the first night on, under the same phase headers the Journal shows. [rows] come
/// newest first, as the journal provider emits them.
String journalAsText(AppLocalizations l10n, Game game, List<NightLogRow> rows) {
  final out = StringBuffer()
    ..writeln(gameTitle(l10n, game))
    ..writeln(l10n.dayMonthLabel(game.endedAt ?? game.createdAt));
  final winner = game.winner;
  if (winner != null) out.writeln(l10n.journalShareWinner(winnerLabel(l10n, winner)));
  final composition = game.compositionJson;
  if (composition != null && composition.values.any((n) => n > 0)) {
    out.writeln(deckLine(l10n, composition, RoleRegistry.all));
  }

  String? lastPhase;
  for (final row in rows.reversed) {
    final phase = journalPhaseLabel(l10n, row);
    if (phase != lastPhase) {
      lastPhase = phase;
      out
        ..writeln()
        ..writeln(phase);
    }
    out.writeln('- ${journalLine(l10n, row)}');
  }
  return out.toString().trimRight();
}
