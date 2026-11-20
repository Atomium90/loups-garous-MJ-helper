import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/data/database/app_database.dart';
import 'package:loup_garou_mj/data/models/game_status.dart';
import 'package:loup_garou_mj/data/models/game_winner.dart';
import 'package:loup_garou_mj/data/models/night_log_entry.dart';
import 'package:loup_garou_mj/l10n/localizations.dart';
import 'package:loup_garou_mj/state/session/session_summary_provider.dart';
import 'package:loup_garou_mj/ui/utils/labels.dart';
import 'package:rules_engine/rules_engine.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final registry = RoleRegistry.all;
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('roleCountLabel', () {
    test('count 1 is just the singular name, no number', () {
      expect(roleCountLabel(fr, 'voyante', 1), 'Voyante');
      expect(roleCountLabel(en, 'voyante', 1), 'Seer');
    });

    test('Loup-Garou pluralises both words in French', () {
      expect(roleCountLabel(fr, 'loup_garou', 2), '2 Loups-Garous');
      expect(roleCountLabel(en, 'loup_garou', 2), '2 Werewolves');
    });

    test('Simple Villageois pluralises its first word in French', () {
      expect(roleCountLabel(fr, 'villageois', 3), '3 Simples Villageois');
      expect(roleCountLabel(en, 'villageois', 3), '3 Simple Villagers');
    });
  });

  group('deckLine', () {
    const composition = {
      'villageois': 2,
      'sorciere': 1,
      'loup_garou': 2,
      'cupidon': 1,
      'voyante': 1,
      'chasseur': 1,
    };

    test('wolves first, plain villageois last, rest in registry order between', () {
      expect(
        deckLine(fr, composition, registry),
        '2 Loups-Garous · Cupidon · Voyante · Sorcière · Chasseur · 2 Simples Villageois',
      );
      expect(
        deckLine(en, composition, registry),
        '2 Werewolves · Cupid · Seer · Witch · Hunter · 2 Simple Villagers',
      );
    });

    test('drops zero-count entries', () {
      final line = deckLine(fr, const {'loup_garou': 2, 'voyante': 0, 'villageois': 6}, registry);

      expect(line, '2 Loups-Garous · 6 Simples Villageois');
    });
  });

  group('reserveLine', () {
    test('spells each reserve card with its article, in the given order', () {
      expect(reserveLine(fr, const ['chasseur', 'voyante']), 'le Chasseur · la Voyante');
      expect(reserveLine(en, const ['chasseur', 'voyante']), 'the Hunter · the Seer');
    });

    test('is empty for no reserve', () {
      expect(reserveLine(fr, const []), '');
    });
  });

  group('every role of the base box', () {
    for (final role in registry.roles) {
      for (final l10n in [fr, en]) {
        test('has its texts in ${l10n.localeName}: ${role.id}', () {
          expect(l10n.roleName(role.id), isNotEmpty);
          expect(l10n.roleName(role.id), isNot(l10n.roleName('unknown')));
          expect(l10n.rolePlural(role.id), isNotEmpty);
          expect(l10n.roleWithArticle(role.id), isNotEmpty);
          expect(l10n.roleRuleText(role.id), isNotEmpty);
        });
      }
    }

    test('only Cupidon and the Sorcière carry a tip for the game master', () {
      final withTip = {
        for (final role in registry.roles)
          if (fr.roleMjTips(role.id).isNotEmpty) role.id,
      };

      expect(withTip, {'cupidon', 'sorciere'});
    });
  });

  group('winners', () {
    test('are named in full and in short, in both languages', () {
      expect(winnerLabel(fr, GameWinner.wolves), 'Les Loups-Garous');
      expect(winnerLabel(en, GameWinner.wolves), 'The Werewolves');
      expect(winnerLabel(fr, GameWinner.none), 'Personne');
      expect(winnerLabel(en, GameWinner.none), 'Nobody');
      expect(winnerShort(fr, GameWinner.village), 'Village');
      expect(winnerShort(fr, GameWinner.none), 'Annulée');
      expect(winnerShort(en, GameWinner.none), 'Cancelled');
    });

    test('every winner has a label, a short label and an icon', () {
      for (final winner in GameWinner.values) {
        expect(winnerLabel(fr, winner), isNotEmpty);
        expect(winnerShort(en, winner), isNotEmpty);
        expect(winnerIcon(winner), isNotNull);
      }
    });

    test('every winner has a label of its own, none silently reads "Annulée"', () {
      // An unknown winner falls back to the "cancelled" wording: a missing entry would make two
      // winners share a label.
      for (final l10n in [fr, en]) {
        final full = {for (final w in GameWinner.values) winnerLabel(l10n, w)};
        final short = {for (final w in GameWinner.values) winnerShort(l10n, w)};
        expect(full, hasLength(GameWinner.values.length), reason: l10n.localeName);
        expect(short, hasLength(GameWinner.values.length), reason: l10n.localeName);
      }
    });

    test('the stored order of the winners never changes: new ones come last', () {
      expect(GameWinner.values.take(4), [
        GameWinner.village,
        GameWinner.wolves,
        GameWinner.lovers,
        GameWinner.none,
      ]);
    });

    test('a solo winner needs its role in the game, the others none', () {
      expect(GameWinner.village.requiredRoleId, isNull);
      expect(GameWinner.none.requiredRoleId, isNull);
      expect(GameWinner.piper.requiredRoleId, 'joueur_de_flute');
      expect(GameWinner.whiteWolf.requiredRoleId, 'loup_garou_blanc');
      expect(GameWinner.angel.requiredRoleId, 'ange');
      expect(GameWinner.sectarian.requiredRoleId, 'abominable_sectaire');
    });
  });

  group('death causes', () {
    const causes = <DeathCause>[
      WolvesKill(),
      WitchDeathPotionKill(),
      DayVoteKill(),
      HunterShotKill(shooterPlayerId: 'a'),
      LoversCascadeKill(causingPlayerId: 'a'),
    ];

    test('each has a distinct long and short label in both languages', () {
      for (final l10n in [fr, en]) {
        expect({for (final c in causes) deathCauseLabel(l10n, c)}, hasLength(causes.length));
        expect({for (final c in causes) deathCauseShort(l10n, c)}, hasLength(causes.length));
      }
    });

    test('read naturally', () {
      expect(deathCauseLabel(fr, const WolvesKill()), 'Victime des Loups');
      expect(deathCauseShort(fr, const WitchDeathPotionKill()), 'potion de mort');
      expect(deathCauseLabel(en, const HunterShotKill(shooterPlayerId: 'a')), "Hunter's shot");
    });
  });

  group('dates', () {
    final date = DateTime(2026, 8, 14);

    test('a game without a name is titled by its date', () {
      final game = Game(
        id: 1,
        createdAt: date,
        updatedAt: date,
        playerCount: 8,
        status: GameStatus.setup,
      );

      expect(gameTitle(fr, game), 'Partie du 14 août');
      expect(gameTitle(en, game), 'Game of August 14');
      expect(gameTitle(fr, game.copyWith(name: const Value('Soirée'))), 'Soirée');
    });

    test('the month group label starts with a capital', () {
      expect(monthYearLabel(fr, date), 'Août 2026');
      expect(monthYearLabel(en, date), 'August 2026');
    });

    test('a day and month', () {
      expect(fr.dayMonthLabel(date), '14 août');
      expect(en.dayMonthLabel(date), 'August 14');
    });
  });

  group('sessionSummaryLine', () {
    test('a night names the role whose turn it is', () {
      const summary = SessionSummary(
        phase: JournalPhase.night,
        nightIndex: 1,
        step: SummaryStep.role,
        roleId: 'voyante',
      );
      expect(sessionSummaryLine(fr, summary), 'Nuit 1 · Voyante');
      expect(sessionSummaryLine(en, summary), 'Night 1 · Seer');
    });

    test('every other step has a phrase in both languages', () {
      for (final step in SummaryStep.values.where((s) => s != SummaryStep.role)) {
        for (final phase in JournalPhase.values) {
          final summary = SessionSummary(phase: phase, nightIndex: 2, step: step);
          expect(sessionSummaryLine(fr, summary), contains(' · '), reason: '$phase $step');
          expect(
            sessionSummaryLine(en, summary),
            isNot(sessionSummaryLine(fr, summary)),
            reason: '$phase $step',
          );
        }
      }
    });

    test('a day reads as "Jour" / "Day"', () {
      const summary = SessionSummary(
        phase: JournalPhase.day,
        nightIndex: 2,
        step: SummaryStep.villageVote,
      );
      expect(sessionSummaryLine(fr, summary), 'Jour 2 · vote du village');
      expect(sessionSummaryLine(en, summary), 'Day 2 · village vote');
    });
  });

  test('an unknown role has a neutral name rather than failing', () {
    expect(fr.roleName('nouveau_role'), 'Rôle inconnu');
    expect(en.roleName('nouveau_role'), 'Unknown role');
  });
}
