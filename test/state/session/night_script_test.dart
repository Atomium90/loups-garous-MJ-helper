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
}
