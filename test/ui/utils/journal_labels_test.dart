import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart';
import 'package:loup_garou_mj/l10n/localizations.dart';
import 'package:loup_garou_mj/ui/utils/journal_labels.dart';

NightLogRow _row(
  JournalKind kind, {
  Map<String, String> args = const {},
  JournalPhase phase = JournalPhase.night,
  int phaseIndex = 1,
}) => NightLogRow(
  id: 1,
  gameId: 1,
  seq: 1,
  phaseLabel: '',
  iconName: kind.iconName,
  line: '',
  kind: kind.name,
  argsJson: jsonEncode(args),
  phase: phase.name,
  phaseIndex: phaseIndex,
  createdAt: DateTime(2026, 11, 18),
);

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('journalLine', () {
    test('every kind has a sentence in both languages', () {
      for (final kind in JournalKind.values) {
        final row = _row(kind, args: {'player': 'Ana', 'other': 'Bo', 'role': 'voyante'});
        expect(journalLine(fr, row), isNotEmpty, reason: '$kind in French');
        expect(journalLine(en, row), isNotEmpty, reason: '$kind in English');
        expect(journalLine(en, row), isNot(journalLine(fr, row)), reason: '$kind translated');
      }
    });

    test('player names go into the sentence', () {
      final row = _row(JournalKind.cupidPair, args: {'player': 'Ana', 'other': 'Bo'});
      expect(journalLine(fr, row), 'Cupidon unit Ana et Bo');
      expect(journalLine(en, row), 'Cupid pairs Ana and Bo');
    });

    test('the Voleur swap names the card in the reader\'s language', () {
      final row = _row(JournalKind.thiefSwap, args: {'role': 'voyante'});
      expect(journalLine(fr, row), 'Le Voleur échange sa carte contre Voyante');
      expect(journalLine(en, row), 'The Thief swaps their card for Seer');
    });

    test('a line without arguments reads as a plain sentence', () {
      final row = _row(JournalKind.voteTie);
      expect(journalLine(fr, row), "Égalité, personne n'est éliminé");
      expect(journalLine(en, row), 'Tie, nobody is eliminated');
    });

    test('unreadable arguments leave a blank name rather than failing', () {
      final row = _row(JournalKind.wolvesTarget).copyWith(argsJson: const Value('not json'));
      expect(journalLine(fr, row), 'Les Loups désignent ');
    });

    test('a line written before the journal was structured is shown as it was', () {
      final legacy = NightLogRow(
        id: 1,
        gameId: 1,
        seq: 1,
        phaseLabel: 'NUIT 1',
        iconName: 'wolves',
        line: 'Les Loups désignent Bob',
        createdAt: DateTime(2026, 11, 18),
      );
      expect(journalLine(fr, legacy), 'Les Loups désignent Bob');
      expect(journalLine(en, legacy), 'Les Loups désignent Bob');
      expect(journalPhaseLabel(en, legacy), 'NUIT 1');
    });
  });

  group('journalPhaseLabel', () {
    test('counts nights and days in the reader\'s language', () {
      final night = _row(JournalKind.voteTie, phase: JournalPhase.night, phaseIndex: 2);
      final day = _row(JournalKind.voteTie, phase: JournalPhase.day, phaseIndex: 3);
      expect(journalPhaseLabel(fr, night), 'NUIT 2');
      expect(journalPhaseLabel(en, night), 'NIGHT 2');
      expect(journalPhaseLabel(fr, day), 'JOUR 3');
      expect(journalPhaseLabel(en, day), 'DAY 3');
    });
  });
}
