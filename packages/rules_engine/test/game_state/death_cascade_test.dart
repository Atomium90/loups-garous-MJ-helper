import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

List<Player> _players(Map<String, String> idToRole, {String? dead}) => [
  for (final entry in idToRole.entries)
    Player(id: entry.key, name: entry.key, roleId: entry.value, alive: entry.key != dead),
];

void main() {
  const machine = GameStateMachine();
  final roleRegistry = RoleRegistry.base;

  group('FinalizeNight, no cascade (DeathEffect.none scenarios)', () {
    test('no wolf/witch action produces zero deaths', () {
      final state = GameState.initial(players: _players({'a': 'villageois', 'b': 'voyante'}));
      final result = machine.apply(
        state: state,
        action: const FinalizeNight(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.players.every((p) => p.alive), isTrue);
      expect(result.state.phase, GamePhase.day);
      expect(result.events.whereType<PlayerDied>(), isEmpty);
    });

    test('a wolf victim saved by the life potion produces zero deaths', () {
      var state = GameState.initial(players: _players({'a': 'villageois', 'b': 'voyante'}));
      state = machine
          .apply(
            state: state,
            action: const WolvesTarget(targetPlayerId: 'a'),
            roleRegistry: roleRegistry,
          )
          .state;
      state = machine
          .apply(state: state, action: const WitchLifePotion(), roleRegistry: roleRegistry)
          .state;
      final result = machine.apply(
        state: state,
        action: const FinalizeNight(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.players.every((p) => p.alive), isTrue);
    });

    test('a wolf victim plus a distinct witch death potion target produces two deaths', () {
      var state = GameState.initial(
        players: _players({'a': 'villageois', 'b': 'voyante', 'c': 'sorciere'}),
      );
      state = machine
          .apply(
            state: state,
            action: const WolvesTarget(targetPlayerId: 'a'),
            roleRegistry: roleRegistry,
          )
          .state;
      state = machine
          .apply(
            state: state,
            action: const WitchDeathPotion(targetPlayerId: 'b'),
            roleRegistry: roleRegistry,
          )
          .state;
      final result = machine.apply(
        state: state,
        action: const FinalizeNight(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('a').alive, isFalse);
      expect(result.state.playerById('b').alive, isFalse);
      expect(result.events.whereType<PlayerDied>(), hasLength(2));
    });

    test('the same target for wolves and witch death potion only dies once', () {
      var state = GameState.initial(players: _players({'a': 'villageois', 'b': 'voyante'}));
      state = machine
          .apply(
            state: state,
            action: const WolvesTarget(targetPlayerId: 'a'),
            roleRegistry: roleRegistry,
          )
          .state;
      state = machine
          .apply(
            state: state,
            action: const WitchDeathPotion(targetPlayerId: 'a'),
            roleRegistry: roleRegistry,
          )
          .state;
      final result = machine.apply(
        state: state,
        action: const FinalizeNight(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('a').alive, isFalse);
      expect(result.events.whereType<PlayerDied>(), hasLength(1));
    });
  });

  group('DayVoteElimination, no cascade', () {
    test('eliminates a plain villager with no further effect', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois'}),
      ).copyWith(phase: GamePhase.day);
      final result = machine.apply(
        state: state,
        action: const DayVoteElimination(targetPlayerId: 'a'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('a').alive, isFalse);
      expect(result.state.cascade, isNull);
    });
  });

  group('Lovers cascade', () {
    test('the partner dies too, attributed to LoversCascadeKill', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois', 'b': 'voyante'}),
      ).copyWith(phase: GamePhase.day, lovers: const LoversPair('a', 'b'));
      final result = machine.apply(
        state: state,
        action: const DayVoteElimination(targetPlayerId: 'a'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('a').alive, isFalse);
      expect(result.state.playerById('b').alive, isFalse);
      final partnerDeath = result.events.whereType<PlayerDied>().firstWhere(
        (e) => e.playerId == 'b',
      );
      expect(partnerDeath.cause, isA<LoversCascadeKill>());
    });

    test('both lovers dying independently the same night is not double-processed', () {
      var state = GameState.initial(
        players: _players({'a': 'villageois', 'b': 'voyante'}),
      ).copyWith(lovers: const LoversPair('a', 'b'));
      state = machine
          .apply(
            state: state,
            action: const WolvesTarget(targetPlayerId: 'a'),
            roleRegistry: roleRegistry,
          )
          .state;
      state = machine
          .apply(
            state: state,
            action: const WitchDeathPotion(targetPlayerId: 'b'),
            roleRegistry: roleRegistry,
          )
          .state;
      final result = machine.apply(
        state: state,
        action: const FinalizeNight(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('a').alive, isFalse);
      expect(result.state.playerById('b').alive, isFalse);
      expect(result.events.whereType<PlayerDied>(), hasLength(2));
    });
  });

  group('onDeath and captain status pause the cascade', () {
    test('a dying Chasseur with living candidates raises PendingHunterShot', () {
      final state = GameState.initial(
        players: _players({'h': 'chasseur', 'a': 'villageois', 'b': 'voyante'}),
      ).copyWith(phase: GamePhase.day);
      final result = machine.apply(
        state: state,
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.cascade?.decision, isA<PendingHunterShot>());
      expect((result.state.cascade!.decision as PendingHunterShot).deadHunterId, 'h');
    });

    test('a dying Chasseur with no living candidates auto-skips', () {
      final state = GameState.initial(
        players: _players({'h': 'chasseur'}),
      ).copyWith(phase: GamePhase.day);
      final result = machine.apply(
        state: state,
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.cascade, isNull);
      expect(result.events.whereType<HunterShotSkipped>(), hasLength(1));
    });

    test('a dying captain with living candidates raises PendingCaptainSuccession', () {
      final state = GameState.initial(
        players: _players({'a': 'voyante', 'b': 'villageois'}),
      ).copyWith(phase: GamePhase.day, captainPlayerId: 'a');
      final result = machine.apply(
        state: state,
        action: const DayVoteElimination(targetPlayerId: 'a'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.cascade?.decision, isA<PendingCaptainSuccession>());
    });

    test('a dying captain with no living candidates auto-skips and clears captainPlayerId', () {
      final state = GameState.initial(
        players: _players({'a': 'voyante'}),
      ).copyWith(phase: GamePhase.day, captainPlayerId: 'a');
      final result = machine.apply(
        state: state,
        action: const DayVoteElimination(targetPlayerId: 'a'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.cascade, isNull);
      expect(result.state.captainPlayerId, isNull);
      expect(result.events.whereType<CaptainSuccessionSkipped>(), hasLength(1));
    });

    test(
      'a plain villager who is also captain still triggers succession '
      '(captain status is role-independent)',
      () {
        final state = GameState.initial(
          players: _players({'a': 'villageois', 'b': 'voyante'}),
        ).copyWith(phase: GamePhase.day, captainPlayerId: 'a');
        final result = machine.apply(
          state: state,
          action: const DayVoteElimination(targetPlayerId: 'a'),
          roleRegistry: roleRegistry,
        );
        expect(result.state.cascade?.decision, isA<PendingCaptainSuccession>());
      },
    );
  });

  group('guards', () {
    test('FinalizeNight rejects when a cascade is already pending', () {
      final state = GameState.initial(players: _players({'h': 'chasseur'})).copyWith(
        phase: GamePhase.night,
        cascade: const CascadeState(
          decision: PendingHunterShot(deadHunterId: 'h'),
          remainingQueue: [],
        ),
      );
      expect(
        () => machine.apply(
          state: state,
          action: const FinalizeNight(),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('DayVoteElimination rejects during the night', () {
      final state = GameState.initial(players: _players({'a': 'villageois'}));
      expect(
        () => machine.apply(
          state: state,
          action: const DayVoteElimination(targetPlayerId: 'a'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('StartNextNight rejects when a cascade is pending', () {
      final state = GameState.initial(players: _players({'h': 'chasseur'})).copyWith(
        phase: GamePhase.day,
        cascade: const CascadeState(
          decision: PendingHunterShot(deadHunterId: 'h'),
          remainingQueue: [],
        ),
      );
      expect(
        () => machine.apply(
          state: state,
          action: const StartNextNight(),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('determinism', () {
    test('the same sequence of actions from a fresh initial state yields the same result', () {
      ActionResult run() {
        var state = GameState.initial(
          players: _players({'a': 'villageois', 'b': 'voyante', 'c': 'sorciere'}),
        );
        state = machine
            .apply(
              state: state,
              action: const WolvesTarget(targetPlayerId: 'a'),
              roleRegistry: roleRegistry,
            )
            .state;
        return machine.apply(
          state: state,
          action: const FinalizeNight(),
          roleRegistry: roleRegistry,
        );
      }

      final first = run();
      final second = run();
      expect(
        first.state.players.map((p) => (p.id, p.alive)),
        second.state.players.map((p) => (p.id, p.alive)),
      );
    });
  });
}
