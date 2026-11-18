import 'package:flutter/widgets.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/l10n/localizations.dart';
import 'package:loup_garou_mj/ui/utils/journal_labels.dart';

/// The journal sentences of [rows] as the MJ reads them in French.
List<String> frenchJournal(Iterable<NightLogRow> rows) {
  final fr = lookupAppLocalizations(const Locale('fr'));
  return [for (final row in rows) journalLine(fr, row)];
}
