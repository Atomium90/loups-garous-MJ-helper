import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

List<Player> _players(Map<String, String> idToRole) => [
  for (final entry in idToRole.entries)
    Player(id: entry.key, name: entry.key, roleId: entry.value),
];

void main() {
  const machine = GameStateMachine();
  final roleRegistry = RoleRegistry.base;

  group('HunterShoot resolution', () {
    test('kills the target and clears the cascade when nothing else is pending', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'h': 'chasseur', 't': 'villageois'}),
        ).copyWith(phase: GamePhase.day),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      final result = machine.apply(
        state: afterDeath.state,
        action: const HunterShoot(targetPlayerId: 't'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('t').alive, isFalse);
      expect(result.state.cascade, isNull);
      final death = result.events.whereType<PlayerDied>().single;
      expect(death.playerId, 't');
      expect(death.cause, isA<HunterShotKill>());
      expect((death.cause as HunterShotKill).shooterPlayerId, 'h');
    });

    test('rejects when there is no pending decision', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois'}),
      ).copyWith(phase: GamePhase.day);
      expect(
        () => machine.apply(
          state: state,
          action: const HunterShoot(targetPlayerId: 'a'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('a null target ("il ne tire pas") clears the cascade and kills no one', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'h': 'chasseur', 't': 'villageois'}),
        ).copyWith(phase: GamePhase.day),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      final result = machine.apply(
        state: afterDeath.state,
        action: const HunterShoot(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('t').alive, isTrue);
      expect(result.state.cascade, isNull);
      expect(result.events.whereType<HunterShotSkipped>(), hasLength(1));
      expect(result.events.whereType<PlayerDied>(), isEmpty);
    });

    test('declining the shot still resolves a queued captain succession behind it', () {
      // 'h' is the Chasseur and the captain: his death pauses on the shot, with
      // ResolveCaptainStatus still queued behind it.
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'h': 'chasseur', 'x': 'villageois'}),
        ).copyWith(phase: GamePhase.day, captainPlayerId: 'h'),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      final result = machine.apply(
        state: afterDeath.state,
        action: const HunterShoot(),
        roleRegistry: roleRegistry,
      );
      expect(result.state.cascade?.decision, isA<PendingCaptainSuccession>());
    });

    test('rejects a dead target', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'h': 'chasseur', 't': 'villageois'}),
        ).copyWith(phase: GamePhase.day),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      expect(
        () => machine.apply(
          state: afterDeath.state,
          action: const HunterShoot(targetPlayerId: 'h'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('CaptainNameSuccessor resolution', () {
    test('updates captainPlayerId and clears the cascade', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'c': 'voyante', 'x': 'villageois'}),
        ).copyWith(phase: GamePhase.day, captainPlayerId: 'c'),
        action: const DayVoteElimination(targetPlayerId: 'c'),
        roleRegistry: roleRegistry,
      );
      final result = machine.apply(
        state: afterDeath.state,
        action: const CaptainNameSuccessor(successorPlayerId: 'x'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.captainPlayerId, 'x');
      expect(result.state.cascade, isNull);
      expect(result.events.whereType<CaptainSuccession>(), hasLength(1));
    });

    test('rejects when there is no pending decision', () {
      final state = GameState.initial(
        players: _players({'a': 'villageois'}),
      ).copyWith(phase: GamePhase.day);
      expect(
        () => machine.apply(
          state: state,
          action: const CaptainNameSuccessor(successorPlayerId: 'a'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('mismatched and blocked resumption', () {
    test('CaptainNameSuccessor is rejected while a Hunter shot is pending', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'h': 'chasseur', 't': 'villageois'}),
        ).copyWith(phase: GamePhase.day),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      expect(
        () => machine.apply(
          state: afterDeath.state,
          action: const CaptainNameSuccessor(successorPlayerId: 't'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('HunterShoot is rejected while a Captain succession is pending', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'c': 'voyante', 'x': 'villageois'}),
        ).copyWith(phase: GamePhase.day, captainPlayerId: 'c'),
        action: const DayVoteElimination(targetPlayerId: 'c'),
        roleRegistry: roleRegistry,
      );
      expect(
        () => machine.apply(
          state: afterDeath.state,
          action: const HunterShoot(targetPlayerId: 'x'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('any unrelated action is rejected while a decision is pending', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'h': 'chasseur', 't': 'villageois'}),
        ).copyWith(phase: GamePhase.day),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      expect(
        () => machine.apply(
          state: afterDeath.state,
          action: const WolvesTarget(targetPlayerId: 't'),
          roleRegistry: roleRegistry,
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('ordering proof: onDeath resolves before the lovers cascade', () {
    test('the lover is still alive right when the pending decision is raised', () {
      final state = GameState.initial(
        players: _players({'h': 'chasseur', 'l': 'voyante', 't': 'villageois'}),
      ).copyWith(phase: GamePhase.day, lovers: const LoversPair('h', 'l'));
      final result = machine.apply(
        state: state,
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.cascade?.decision, isA<PendingHunterShot>());
      expect(result.state.playerById('l').alive, isTrue);
    });

    test('the shot resolves, then the lover dies, in that event order', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'h': 'chasseur', 'l': 'voyante', 't': 'villageois'}),
        ).copyWith(phase: GamePhase.day, lovers: const LoversPair('h', 'l')),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      final result = machine.apply(
        state: afterDeath.state,
        action: const HunterShoot(targetPlayerId: 't'),
        roleRegistry: roleRegistry,
      );
      expect(
        result.events.whereType<PlayerDied>().map((e) => e.playerId),
        ['t', 'l'],
      );
      expect(result.state.playerById('l').alive, isFalse);
      expect(result.state.cascade, isNull);
    });

    test('shooting his own lover kills her exactly once, via the shot', () {
      final afterDeath = machine.apply(
        state: GameState.initial(
          players: _players({'h': 'chasseur', 'l': 'voyante'}),
        ).copyWith(phase: GamePhase.day, lovers: const LoversPair('h', 'l')),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );
      final result = machine.apply(
        state: afterDeath.state,
        action: const HunterShoot(targetPlayerId: 'l'),
        roleRegistry: roleRegistry,
      );
      expect(result.state.playerById('l').alive, isFalse);
      final lDeaths = result.events.whereType<PlayerDied>().where((e) => e.playerId == 'l');
      expect(lDeaths, hasLength(1));
      expect(lDeaths.single.cause, isA<HunterShotKill>());
    });
  });

  group('a chain: Hunter shot target is also the Captain, raising a second decision', () {
    test('resolving fully needs both HunterShoot and CaptainNameSuccessor', () {
      final afterHunterDeath = machine.apply(
        state: GameState.initial(
          players: _players({
            'h': 'chasseur',
            'a': 'voyante', // h's lover
            't': 'villageois', // the shot target, also captain
            'x': 'villageois', // captain succession candidate
          }),
        ).copyWith(
          phase: GamePhase.day,
          lovers: const LoversPair('h', 'a'),
          captainPlayerId: 't',
        ),
        action: const DayVoteElimination(targetPlayerId: 'h'),
        roleRegistry: roleRegistry,
      );

      final afterShot = machine.apply(
        state: afterHunterDeath.state,
        action: const HunterShoot(targetPlayerId: 't'),
        roleRegistry: roleRegistry,
      );
      // The shot resolves, the lovers cascade kills 'a', and 't' being
      // captain immediately raises a second pending decision.
      expect(afterShot.state.playerById('t').alive, isFalse);
      expect(afterShot.state.playerById('a').alive, isFalse);
      expect(afterShot.state.cascade?.decision, isA<PendingCaptainSuccession>());

      final afterSuccession = machine.apply(
        state: afterShot.state,
        action: const CaptainNameSuccessor(successorPlayerId: 'x'),
        roleRegistry: roleRegistry,
      );
      expect(afterSuccession.state.cascade, isNull);
      expect(afterSuccession.state.captainPlayerId, 'x');
      expect(afterSuccession.state.alivePlayers.map((p) => p.id), ['x']);
    });
  });
}
