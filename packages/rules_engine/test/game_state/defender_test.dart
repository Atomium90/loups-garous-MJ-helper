import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table({Set<String> dead = const {}, int night = 1}) => GameState.initial(
  players: [
    for (final (id, role) in [
      ('d', 'salvateur'),
      ('w', 'loup_garou'),
      ('a', 'villageois'),
      ('b', 'villageois'),
    ])
      Player(id: id, name: id.toUpperCase(), roleId: role, alive: !dead.contains(id)),
  ],
).copyWith(nightIndex: night);

void main() {
  const machine = GameStateMachine();
  final registry = RoleRegistry.all;

  ActionResult apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry);

  GameState applyAll(GameState state, List<GameAction> actions) {
    var current = state;
    for (final action in actions) {
      current = apply(current, action).state;
    }
    return current;
  }

  test('the Defender is a village role called every night, just before the wolf pack', () {
    final role = registry.byId('salvateur');
    expect(role.team, Team.village);
    expect(role.wakeCondition, WakeCondition.everyNight);
    final ids = registry.roles.map((r) => r.id).toList();
    expect(ids.indexOf('salvateur'), lessThan(ids.indexOf('loup_garou')));
    expect(ids.indexOf('salvateur'), greaterThan(ids.indexOf('montreur_d_ours')));
  });

  group('protection', () {
    test('keeps the wolves\' victim alive, and says so', () {
      var state = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'a'),
        const WolvesTarget(targetPlayerId: 'a'),
      ]);
      final result = apply(state, const FinalizeNight());
      expect(result.state.playerById('a').alive, isTrue);
      expect(result.events.whereType<DefenderSaved>(), hasLength(1));
      expect(result.events.whereType<PlayerDied>(), isEmpty);
    });

    test('he may protect himself', () {
      final state = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'd'),
        const WolvesTarget(targetPlayerId: 'd'),
        const FinalizeNight(),
      ]);
      expect(state.playerById('d').alive, isTrue);
    });

    test('protects against the Big Bad Wolf\'s second victim too', () {
      final state = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'b'),
        const BigBadWolfTarget(targetPlayerId: 'b'),
        const FinalizeNight(),
      ]);
      expect(state.playerById('b').alive, isTrue);
    });

    test('does not protect against the Witch\'s poison, the White Werewolf or a vote', () {
      final poisoned = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'a'),
        const WitchDeathPotion(targetPlayerId: 'a'),
        const FinalizeNight(),
      ]);
      expect(poisoned.playerById('a').alive, isFalse);

      final eaten = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'w'),
        const WhiteWolfEat(targetPlayerId: 'w'),
        const FinalizeNight(),
      ]);
      expect(eaten.playerById('w').alive, isFalse);
    });

    test('does not stop the infection', () {
      final state = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'a'),
        const WolvesTarget(targetPlayerId: 'a'),
        const InfectVictim(),
      ]);
      expect(state.playerById('a').teamOverride, Team.werewolves);
    });

    test('does not protect another player than the one picked', () {
      final state = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'b'),
        const WolvesTarget(targetPlayerId: 'a'),
        const FinalizeNight(),
      ]);
      expect(state.playerById('a').alive, isFalse);
    });

    test('the Elder\'s first bite is not used up while he is protected', () {
      final elderTable = GameState.initial(
        players: const [
          Player(id: 'd', name: 'D', roleId: 'salvateur'),
          Player(id: 'e', name: 'E', roleId: 'ancien'),
          Player(id: 'w', name: 'W', roleId: 'loup_garou'),
        ],
      );
      final state = applyAll(elderTable, [
        const DefenderProtect(targetPlayerId: 'e'),
        const WolvesTarget(targetPlayerId: 'e'),
        const FinalizeNight(),
      ]);
      expect(state.woundedElders, isEmpty);
    });
  });

  group('the rules of the Defender', () {
    test('cannot protect the same player two nights in a row', () {
      var state = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'a'),
        const FinalizeNight(),
        const StartNextNight(),
      ]);
      expect(state.defenderLastProtectedId, 'a');
      expect(
        () => apply(state, const DefenderProtect(targetPlayerId: 'a')),
        throwsA(isA<InvalidActionError>()),
      );
      // Someone else is fine, and so is the same player the night after.
      state = apply(state, const DefenderProtect(targetPlayerId: 'b')).state;
      state = applyAll(state, [const FinalizeNight(), const StartNextNight()]);
      expect(apply(state, const DefenderProtect(targetPlayerId: 'a')).state.defenderProtectedId, 'a');
    });

    test('skipping a night frees every player', () {
      final state = applyAll(_table(), [
        const DefenderProtect(targetPlayerId: 'a'),
        const FinalizeNight(),
        const StartNextNight(),
        const FinalizeNight(),
        const StartNextNight(),
      ]);
      expect(state.defenderLastProtectedId, isNull);
    });

    test('only protects the living, and only at night', () {
      expect(
        () => apply(_table(dead: {'a'}), const DefenderProtect(targetPlayerId: 'a')),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table().copyWith(phase: GamePhase.day), const DefenderProtect(targetPlayerId: 'b')),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('what the Witch is shown', () {
    test('is the wolves\' victim, unless the Defender protects them', () {
      final picked = apply(_table(), const WolvesTarget(targetPlayerId: 'a')).state;
      expect(picked.wolfVictimForWitch, 'a');
      final protected = apply(picked, const DefenderProtect(targetPlayerId: 'a')).state;
      expect(protected.wolfVictimForWitch, isNull);
      expect(protected.pendingWolfVictimId, 'a'); // still there for the infection
    });
  });

  test('the protection and the last protected survive a save', () {
    final state = applyAll(_table(), [const DefenderProtect(targetPlayerId: 'a')])
        .copyWith(defenderLastProtectedId: 'b');
    final back = GameStateJson.decode(GameStateJson.encode(state));
    expect(back.defenderProtectedId, 'a');
    expect(back.defenderLastProtectedId, 'b');
  });
}
