import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/l10n/localizations.dart';
import 'package:loup_garou_mj/state/settings/settings.dart';
import 'package:loup_garou_mj/ui/utils/narration.dart';
import 'package:rules_engine/rules_engine.dart';

void main() {
  final fr = lookupAppLocalizations(const Locale('fr'));
  final en = lookupAppLocalizations(const Locale('en'));

  String say(List<NarrationLine> lines, NarrationLevel level) =>
      lines.map((l) => l.textAt(level)).join(' | ');

  group('a line at each level', () {
    const line = NarrationLine('Chasseur, tu es mort.', 'Emporte qui tu veux.');

    test('is nothing when off, the head when short, head and body when full', () {
      expect(line.textAt(NarrationLevel.off), isEmpty);
      expect(line.textAt(NarrationLevel.short), 'Chasseur, tu es mort.');
      expect(line.textAt(NarrationLevel.full), 'Chasseur, tu es mort. Emporte qui tu veux.');
    });

    test('without a body, full is the head too', () {
      expect(const NarrationLine('Voyante, rendors-toi.').textAt(NarrationLevel.full),
          'Voyante, rendors-toi.');
    });
  });

  group('the role calls', () {
    test('every role that wakes at night has a call, a task and a way back to sleep', () {
      for (final role in RoleRegistry.all.roles.where((r) => r.hasNightCall)) {
        for (final l10n in [fr, en]) {
          final lines = roleCallNarration(l10n, role.id);
          // Nobody wakes for a role settled before the night: there is no way back to sleep.
          expect(lines, hasLength(role.preparation ? 1 : 2), reason: '${role.id} in ${l10n.localeName}');
          expect(lines[0].head, isNotEmpty);
          expect(lines[0].body, isNotNull, reason: '${role.id} has no task');
          if (!role.preparation) expect(lines[1].head, isNotEmpty);
        }
      }
    });

    test('a role with no night call says nothing', () {
      expect(roleCallNarration(fr, 'villageois'), isEmpty);
      expect(roleCallNarration(en, 'chasseur'), isEmpty);
    });

    test('the Voyante in French and English, short and full', () {
      final frLines = roleCallNarration(fr, 'voyante');
      expect(say(frLines, NarrationLevel.short), 'Voyante, ouvre les yeux. | Voyante, rendors-toi.');
      expect(
        say(frLines, NarrationLevel.full),
        'Voyante, ouvre les yeux. Désigne le joueur dont tu veux connaître le rôle. | '
        'Voyante, rendors-toi.',
      );
      expect(
        say(roleCallNarration(en, 'voyante'), NarrationLevel.short),
        'Seer, open your eyes. | Seer, go back to sleep.',
      );
    });

    test('Cupidon wakes the lovers when he goes back to sleep', () {
      expect(roleCallNarration(fr, 'cupidon')[1].head, contains('Amoureux, ouvrez les yeux'));
      expect(roleCallNarration(en, 'cupidon')[1].head, contains('Lovers, open your eyes'));
    });
  });

  group('the morning', () {
    test('says nobody died', () {
      expect(say(morningNarration(fr, const []), NarrationLevel.full),
          'Le village se réveille. Tout le monde ouvre les yeux. | Cette nuit, personne n\'est mort.');
      expect(morningNarration(en, const [])[1].head, 'Tonight, nobody died.');
    });

    test('names the dead and asks them to turn their card over', () {
      final lines = morningNarration(fr, const ['Ana', 'Bo', 'Cy']);
      expect(lines[1].head, 'Cette nuit, le village a perdu Ana, Bo et Cy.');
      expect(lines[1].body, 'Les joueurs concernés retournent leur carte.');
      expect(morningNarration(en, const ['Ana'])[1].head, 'Tonight, the village lost Ana.');
    });
  });

  group('when the dead keep their card hidden', () {
    test('the morning, the reveal and the heartbreak no longer ask to turn the card over', () {
      expect(
        morningNarration(fr, const ['Ana'], cardsShown: false)[1].body,
        'Leurs cartes restent cachées.',
      );
      expect(revealNarration(fr, 'Ana', cardsShown: false).first.body, 'Ta carte reste cachée.');
      expect(
        loversNarration(en, 'Bo', cardsShown: false).first.body,
        'You die of heartbreak. Your card stays hidden.',
      );
    });

    test('nobody dead still means no line about cards', () {
      expect(morningNarration(fr, const [], cardsShown: false)[1].body, isNull);
    });
  });

  test('names are joined with "and" in the language of the app', () {
    expect(joinNames(fr, const ['Ana']), 'Ana');
    expect(joinNames(fr, const ['Ana', 'Bo']), 'Ana et Bo');
    expect(joinNames(en, const ['Ana', 'Bo', 'Cy']), 'Ana, Bo and Cy');
    expect(joinNames(en, const []), isEmpty);
  });

  group('the other moments', () {
    test('the Hunter hears the sentence he was promised', () {
      expect(
        say(hunterNarration(fr), NarrationLevel.full),
        'Chasseur, tu es mort. Emporte qui tu le souhaites dans la tombe.',
      );
      expect(say(hunterNarration(en), NarrationLevel.short), 'Hunter, you are dead.');
    });

    test('each moment has a head and a body in both languages', () {
      for (final l10n in [fr, en]) {
        final moments = {
          'night start': nightStartNarration(l10n),
          'captain': captainNarration(l10n),
          'vote': voteNarration(l10n),
          'reveal': revealNarration(l10n, 'Ana'),
          'succession': successionNarration(l10n),
          'lovers': loversNarration(l10n, 'Ana'),
        };
        for (final MapEntry(key: name, value: lines) in moments.entries) {
          expect(lines, isNotEmpty, reason: name);
          expect(lines.first.head, isNotEmpty, reason: '$name in ${l10n.localeName}');
        }
      }
    });

    test('a name goes into the sentence', () {
      expect(revealNarration(fr, 'Ana').first.head, 'Ana, tu es éliminé.');
      expect(loversNarration(en, 'Bo').first.head, 'Bo, your lover is dead.');
    });
  });
}
