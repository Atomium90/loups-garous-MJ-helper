import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/session/night_script.dart';
import 'package:rules_engine/rules_engine.dart';

/// A GameState with [count] seats, all carrying the placeholder role unless
/// [roles] overrides a seat (0-indexed).
GameState _state({
  int count = 6,
  int nightIndex = 1,
  GamePhase phase = GamePhase.night,
  Map<int, String> roles = const {},
  Set<int> dead = const {},
}) => GameState(
  nightIndex: nightIndex,
  phase: phase,
  players: [
    for (var i = 0; i < count; i++)
      Player(
        id: '$i',
        name: 'P$i',
        roleId: roles[i] ?? kPlaceholderRoleId,
        alive: !dead.contains(i),
      ),
  ],
);

void main() {
  List<String> stepIds(NightScript s) => s.steps.map((st) => st.role.id).toList();

  group('night 1', () {
    test('is built from the composition, in wake order', () {
      final script = buildNightScript(
        engine: _state(),
        composition: const {'voyante': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2},
      );
      expect(stepIds(script), ['voyante', 'loup_garou', 'sorciere']);
    });

    test('wakes Cupidon before the Loups even with no Voyante to tie them together', () {
      // The composition lists the Loups first: its key order must not decide the wake order.
      final script = buildNightScript(
        engine: _state(),
        composition: const {'loup_garou': 1, 'cupidon': 1, 'sorciere': 1, 'villageois': 3},
      );
      expect(stepIds(script), ['cupidon', 'loup_garou', 'sorciere']);
    });

    test('keeps the official order whatever order the composition is written in', () {
      final script = buildNightScript(
        engine: _state(),
        composition: const {
          'sorciere': 1,
          'loup_garou': 1,
          'voyante': 1,
          'cupidon': 1,
          'voleur': 1,
          'villageois': 2,
        },
      );
      expect(stepIds(script), ['voleur', 'cupidon', 'voyante', 'loup_garou', 'sorciere']);
    });

    test('picks up a role the Voleur just stole from the reserve', () {
      // The composition has no Voyante (she was set aside as a reserve card);
      // the Voleur swapped his card for her mid-night.
      final script = buildNightScript(
        engine: _state(roles: {0: 'voleur', 1: 'voyante'}),
        composition: const {'voleur': 1, 'loup_garou': 2, 'villageois': 3},
      );
      expect(stepIds(script), ['voleur', 'voyante', 'loup_garou']);
    });
  });

  group('night 2+', () {
    const composition = {'voyante': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2};

    test('drops a role once every confirmed holder is dead', () {
      final script = buildNightScript(
        engine: _state(
          nightIndex: 2,
          roles: {0: 'voyante', 1: 'loup_garou', 2: 'loup_garou', 3: 'sorciere'},
          dead: {0}, // the only Voyante is dead
        ),
        composition: composition,
      );
      expect(stepIds(script), ['loup_garou', 'sorciere']);
    });

    test('keeps a role while a holder is still un-identified', () {
      // No player confirmed as the Voyante yet -> she might be alive.
      final script = buildNightScript(
        engine: _state(nightIndex: 2, roles: {0: 'loup_garou', 1: 'loup_garou'}),
        composition: composition,
      );
      expect(stepIds(script), contains('voyante'));
    });

    test('calls a stolen Voyante on later nights even though she is not in the composition', () {
      // Seat 0 is the Voleur who became the Voyante on night 1.
      final script = buildNightScript(
        engine: _state(
          nightIndex: 3,
          roles: {0: 'voyante', 1: 'loup_garou', 2: 'loup_garou'},
        ),
        composition: const {'voleur': 1, 'loup_garou': 2, 'villageois': 3},
      );
      expect(stepIds(script), ['voyante', 'loup_garou']);
    });

    test('does not wake a role whose cards all sit in a drawn reserve, with no holder', () {
      // The Sorcière was left in the middle by the deal: nobody holds her.
      final script = buildNightScript(
        engine: _state(nightIndex: 2, roles: {0: 'loup_garou', 1: 'loup_garou'}),
        composition: const {'loup_garou': 2, 'sorciere': 1, 'villageois': 3},
        dealtComposition: const {'loup_garou': 2, 'villageois': 5},
      );
      expect(stepIds(script), ['loup_garou']);
    });

    test('night 1 still calls a role whose cards are in the reserve, to keep the table guessing', () {
      final script = buildNightScript(
        engine: _state(),
        composition: const {'loup_garou': 2, 'sorciere': 1, 'villageois': 3},
        dealtComposition: const {'loup_garou': 2, 'villageois': 5},
      );
      expect(stepIds(script), ['loup_garou', 'sorciere']);
    });

    test('a stolen Voyante drops out once the Voleur holding her dies', () {
      final script = buildNightScript(
        engine: _state(
          nightIndex: 3,
          roles: {0: 'voyante', 1: 'loup_garou', 2: 'loup_garou'},
          dead: {0},
        ),
        composition: const {'voleur': 1, 'loup_garou': 2, 'villageois': 3},
      );
      expect(stepIds(script), ['loup_garou']);
    });
  });

  group('the Fox, the Sisters and the Bear Tamer', () {
    const composition = {
      'renard': 1,
      'deux_soeurs': 2,
      'montreur_d_ours': 1,
      'loup_garou': 2,
      'villageois': 0,
    };

    test('night 1 calls all three between the Voyante\'s place and the wolves', () {
      final script = buildNightScript(engine: _state(count: 8), composition: composition);
      expect(stepIds(script), ['renard', 'deux_soeurs', 'montreur_d_ours', 'loup_garou']);
    });

    test('the Fox can be called after the Witch instead (the Best Of order)', () {
      final script = buildNightScript(
        engine: _state(count: 8),
        composition: {...composition, 'voyante': 1, 'sorciere': 1},
        foxAfterWitch: true,
      );
      expect(stepIds(script), [
        'voyante',
        'deux_soeurs',
        'montreur_d_ours',
        'loup_garou',
        'sorciere',
        'renard',
      ]);
    });

    test('with no Witch the Fox keeps his place whatever the setting', () {
      final script = buildNightScript(
        engine: _state(count: 8),
        composition: composition,
        foxAfterWitch: true,
      );
      expect(stepIds(script), ['renard', 'deux_soeurs', 'montreur_d_ours', 'loup_garou']);
    });

    test('night 2 keeps the Fox and drops the Sisters and the Bear Tamer', () {
      final script = buildNightScript(
        engine: _state(
          count: 8,
          nightIndex: 2,
          roles: {0: 'renard', 1: 'deux_soeurs', 2: 'deux_soeurs', 3: 'montreur_d_ours', 4: 'loup_garou', 5: 'loup_garou'},
        ),
        composition: composition,
      );
      expect(stepIds(script), ['renard', 'loup_garou']);
    });

    test('night 3 offers the Sisters again while both are alive', () {
      final roles = {0: 'renard', 1: 'deux_soeurs', 2: 'deux_soeurs', 4: 'loup_garou', 5: 'loup_garou'};
      final both = buildNightScript(
        engine: _state(count: 8, nightIndex: 3, roles: roles),
        composition: composition,
      );
      expect(stepIds(both), ['renard', 'deux_soeurs', 'loup_garou']);

      final one = buildNightScript(
        engine: _state(count: 8, nightIndex: 3, roles: roles, dead: {2}),
        composition: composition,
      );
      expect(stepIds(one), ['renard', 'loup_garou']);
    });

    test('a Fox who lost his power is not called any more', () {
      final script = buildNightScript(
        engine: _state(
          count: 8,
          nightIndex: 2,
          roles: {0: 'renard', 4: 'loup_garou', 5: 'loup_garou'},
        ).copyWith(spentPowers: {'renard': 1}),
        composition: composition,
      );
      expect(stepIds(script), ['loup_garou']);
    });

    test('Sisters not yet identified on night 3 may still be alive: they are offered', () {
      final script = buildNightScript(
        engine: _state(count: 8, nightIndex: 3, roles: {4: 'loup_garou', 5: 'loup_garou'}),
        composition: composition,
      );
      expect(stepIds(script), contains('deux_soeurs'));
    });
  });

  group('the Big Bad Wolf', () {
    const composition = {'grand_mechant_loup': 1, 'loup_garou': 2, 'villageois': 3};

    test('is called while no wolf is dead', () {
      final script = buildNightScript(
        engine: _state(
          nightIndex: 2,
          roles: {0: 'grand_mechant_loup', 1: 'loup_garou', 2: 'loup_garou'},
          dead: {5},
        ),
        composition: composition,
      );
      expect(stepIds(script), ['loup_garou', 'grand_mechant_loup']);
    });

    test('stops being called from the night after a wolf died', () {
      final script = buildNightScript(
        engine: _state(
          nightIndex: 3,
          roles: {0: 'grand_mechant_loup', 1: 'loup_garou', 2: 'loup_garou'},
          dead: {2},
        ),
        composition: composition,
      );
      expect(stepIds(script), ['loup_garou']);
    });
  });

  group('the Piper', () {
    const composition = {'joueur_de_flute': 1, 'loup_garou': 2, 'sorciere': 1, 'villageois': 2};
    final roles = {0: 'joueur_de_flute', 1: 'loup_garou', 2: 'loup_garou', 3: 'sorciere'};

    GameState engineWith({Set<int> charmed = const {}, bool infected = false, int night = 2}) {
      final base = _state(nightIndex: night, roles: roles);
      return base.copyWith(
        players: [
          for (final (i, p) in base.players.indexed)
            p.copyWith(
              statuses: charmed.contains(i) ? {PlayerStatus.charmed} : const {},
              teamOverride: infected && i == 0 ? Team.werewolves : null,
            ),
        ],
      );
    }

    test('is called after the Witch every night', () {
      final script = buildNightScript(engine: engineWith(), composition: composition);
      expect(stepIds(script), ['loup_garou', 'sorciere', 'joueur_de_flute']);
    });

    test('wakes the charmed right after him, once someone is charmed', () {
      final script = buildNightScript(
        engine: engineWith(charmed: {4, 5}),
        composition: composition,
      );
      expect(stepIds(script), ['loup_garou', 'sorciere', 'joueur_de_flute', 'joueurs_charmes']);
      expect([for (final s in script.steps) s.stepIndex], [1, 2, 3, 4]);
    });

    test('has nobody to wake once the charmed are all dead', () {
      final script = buildNightScript(
        engine: engineWith(charmed: {4, 5}).killPlayer('4', cause: const DayVoteKill()).killPlayer('5', cause: const DayVoteKill()),
        composition: composition,
      );
      expect(stepIds(script), isNot(contains('joueurs_charmes')));
    });

    test('is no longer called once he is infected, and neither are the charmed', () {
      final script = buildNightScript(
        engine: engineWith(charmed: {4}, infected: true),
        composition: composition,
      );
      expect(stepIds(script), ['loup_garou', 'sorciere']);
    });
  });

  group('the Comedien\'s cards', () {
    final everyBox = CardPool(
      registry: RoleRegistry.all,
      ownedBoxIds: [for (final b in gameBoxes) b.id],
    );

    test('are roles of the boxes that are not dealt', () {
      expect(
        actorCardOptions(
          composition: const {'sorciere': 1, 'loup_garou': 2, 'villageois': 3},
          reserveRoleIds: const [],
          reserveDrawn: false,
          pool: everyBox,
        ),
        ['voyante', 'cupidon', 'salvateur', 'renard'],
      );
    });

    test('leave out the cards of the Voleur\'s reserve too', () {
      expect(
        actorCardOptions(
          composition: const {'voleur': 1, 'loup_garou': 2, 'villageois': 3},
          reserveRoleIds: const ['voyante', 'renard'],
          reserveDrawn: false,
          pool: everyBox,
        ),
        ['sorciere', 'cupidon', 'salvateur'],
      );
    });

    test('are limited to what the owned boxes hold', () {
      final baseOnly = CardPool(registry: RoleRegistry.all);
      expect(
        actorCardOptions(
          composition: const {'loup_garou': 2, 'villageois': 3},
          reserveRoleIds: const [],
          reserveDrawn: false,
          pool: baseOnly,
        ),
        ['voyante', 'sorciere', 'cupidon'],
      );
    });
  });

  group('a blind game', () {
    // Nobody noted at the deal: a role is only learnt when it is woken, so every role with a
    // night call must be called on the first night, whatever its wake condition.
    for (final role in RoleRegistry.all.roles.where((r) => r.hasNightCall)) {
      test('wakes ${role.id} on the first night', () {
        final script = buildNightScript(
          engine: _state(),
          composition: {role.id: role.groupSize, 'loup_garou': 2, 'villageois': 3},
        );
        expect(stepIds(script), contains(role.id));
      });
    }
  });
}
