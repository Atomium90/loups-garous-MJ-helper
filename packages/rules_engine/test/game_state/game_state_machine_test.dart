import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

List<Player> _players(Map<String, String> idToRole, {String? dead}) => [
  for (final entry in idToRole.entries)
    Player(id: entry.key, name: entry.key, roleId: entry.value, alive: entry.key != dead),
];

void main() {
  const machine = GameStateMachine();
  final roleRegistry = RoleRegistry.base;

  group('VoleurSwap', () {
    test('changes the roleId to the stolen role', () {
      final state = GameState.initial(players: _players({'v': 'voleur', 'a': 'villageois'}));
      final result = machine.apply(
        state: state,
        action: const VoleurSwap(voleurPlayerId: 'v', stolenRoleId: 'loup_garou'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('v').roleId, 'loup_garou');
      expect(result.events, hasLength(1));
      expect(result.events.single, isA<VoleurSwapped>());
    });

    test('keeps his own role when stolenRoleId is null', () {
      final state = GameState.initial(players: _players({'v': 'voleur'}));
      final result = machine.apply(
        state: state,
        action: const VoleurSwap(voleurPlayerId: 'v'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('v').roleId, 'voleur');
    });

    test('rejects an unknown stolenRoleId', () {
      final state = GameState.initial(players: _players({'v': 'voleur'}));
      expect(
        () => machine.apply(
          state: state,
          action: const VoleurSwap(voleurPlayerId: 'v', stolenRoleId: 'nonexistent'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<RoleNotFoundException>()),
      );
    });

    test('rejects acting on a night other than 1', () {
      final state = GameState.initial(
        players: _players({'v': 'voleur'}),
      ).copyWith(nightIndex: 2);
      expect(
        () => machine.apply(
          state: state,
          action: const VoleurSwap(voleurPlayerId: 'v', stolenRoleId: 'loup_garou'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('CupidonPair', () {
    test('pairs two players as lovers', () {
      final state = GameState.initial(players: _players({'a': 'cupidon', 'b': 'villageois'}));
      final result = machine.apply(
        state: state,
        action: const CupidonPair(playerAId: 'a', playerBId: 'b'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.lovers?.partnerOf('a'), 'b');
      expect(result.events.single, isA<LoversPaired>());
    });

    test('rejects pairing a player with themselves', () {
      final state = GameState.initial(players: _players({'a': 'cupidon'}));
      expect(
        () => machine.apply(
          state: state,
          action: const CupidonPair(playerAId: 'a', playerBId: 'a'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('rejects a second pairing once lovers are already set', () {
      final state = GameState.initial(
        players: _players({'a': 'cupidon', 'b': 'villageois', 'c': 'voyante'}),
      ).copyWith(lovers: const LoversPair('a', 'b'));
      expect(
        () => machine.apply(
          state: state,
          action: const CupidonPair(playerAId: 'a', playerBId: 'c'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('rejects acting on a night other than 1', () {
      final state = GameState.initial(
        players: _players({'a': 'cupidon', 'b': 'villageois'}),
      ).copyWith(nightIndex: 2);
      expect(
        () => machine.apply(
          state: state,
          action: const CupidonPair(playerAId: 'a', playerBId: 'b'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('WolvesTarget', () {
    test('sets the pending wolf victim', () {
      final state = GameState.initial(players: _players({'a': 'villageois'}));
      final result = machine.apply(
        state: state,
        action: const WolvesTarget(targetPlayerId: 'a'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.pendingWolfVictimId, 'a');
    });

    test('rejects targeting a dead player', () {
      final state = GameState.initial(players: _players({'a': 'villageois'}, dead: 'a'));
      expect(
        () => machine.apply(
          state: state,
          action: const WolvesTarget(targetPlayerId: 'a'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('overwriting the target before finalize is allowed', () {
      final state = GameState.initial(players: _players({'a': 'villageois', 'b': 'voyante'}));
      final first = machine.apply(
        state: state,
        action: const WolvesTarget(targetPlayerId: 'a'),
        roleRegistry: roleRegistry,
      );
      final second = machine.apply(
        state: first.state,
        action: const WolvesTarget(targetPlayerId: 'b'),
        roleRegistry: roleRegistry,
      );
      expect(second.state.pendingWolfVictimId, 'b');
    });
  });

  group('WitchLifePotion', () {
    test('clears the pending wolf victim and marks the potion used', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois'}),
      ).copyWith(pendingWolfVictimId: 'a');
      final result = machine.apply(
        state: state,
        action: const WitchLifePotion(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.pendingWolfVictimId, isNull);
      expect(result.state.witch.lifePotionUsed, isTrue);
    });

    test('rejects when there is no pending wolf victim', () {
      final state = GameState.initial(players: _players({'a': 'villageois'}));
      expect(
        () => machine.apply(
          state: state,
          action: const WitchLifePotion(),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('rejects reuse', () {
      final state = GameState.initial(players: _players({'a': 'villageois'})).copyWith(
        pendingWolfVictimId: 'a',
        witch: const WitchState(lifePotionUsed: true),
      );
      expect(
        () => machine.apply(
          state: state,
          action: const WitchLifePotion(),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('WitchDeathPotion', () {
    test('sets the pending death target and marks the potion used', () {
      final state = GameState.initial(players: _players({'a': 'villageois'}));
      final result = machine.apply(
        state: state,
        action: const WitchDeathPotion(targetPlayerId: 'a'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.pendingWitchDeathTargetId, 'a');
      expect(result.state.witch.deathPotionUsed, isTrue);
    });

    test('allows targeting herself', () {
      final state = GameState.initial(players: _players({'sorciere': 'sorciere'}));
      final result = machine.apply(
        state: state,
        action: const WitchDeathPotion(targetPlayerId: 'sorciere'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.pendingWitchDeathTargetId, 'sorciere');
    });

    test('rejects reuse', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois'}),
      ).copyWith(witch: const WitchState(deathPotionUsed: true));
      expect(
        () => machine.apply(
          state: state,
          action: const WitchDeathPotion(targetPlayerId: 'a'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('ElectCaptain', () {
    test('sets the captain during the day', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois'}),
      ).copyWith(phase: GamePhase.day);
      final result = machine.apply(
        state: state,
        action: const ElectCaptain(playerId: 'a'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.captainPlayerId, 'a');
    });

    test('rejects during the night', () {
      final state = GameState.initial(players: _players({'a': 'villageois'}));
      expect(
        () => machine.apply(
          state: state,
          action: const ElectCaptain(playerId: 'a'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('rejects re-electing once a captain is already set', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois', 'b': 'voyante'}),
      ).copyWith(phase: GamePhase.day, captainPlayerId: 'a');
      expect(
        () => machine.apply(
          state: state,
          action: const ElectCaptain(playerId: 'b'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('StartNextNight', () {
    test('increments the night index and switches back to night', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois'}),
      ).copyWith(phase: GamePhase.day);
      final result = machine.apply(
        state: state,
        action: const StartNextNight(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.nightIndex, 2);
      expect(result.state.phase, GamePhase.night);
    });

    test('rejects starting the next night from the night phase', () {
      final state = GameState.initial(players: _players({'a': 'villageois'}));
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
}
