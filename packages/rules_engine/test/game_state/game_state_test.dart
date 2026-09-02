import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

List<Player> _players(List<String> ids) => [
  for (final id in ids) Player(id: id, name: id, roleId: 'villageois'),
];

void main() {
  group('GameState.initial', () {
    test('starts on night 1, night phase, everyone alive, no lovers/captain', () {
      final state = GameState.initial(players: _players(['a', 'b', 'c']));
      expect(state.nightIndex, 1);
      expect(state.phase, GamePhase.night);
      expect(state.alivePlayers.map((p) => p.id), ['a', 'b', 'c']);
      expect(state.lovers, isNull);
      expect(state.captainPlayerId, isNull);
      expect(state.witch.lifePotionUsed, isFalse);
      expect(state.witch.deathPotionUsed, isFalse);
    });
  });

  group('GameState.playerById', () {
    test('returns the matching player', () {
      final state = GameState.initial(players: _players(['a', 'b']));
      expect(state.playerById('b').id, 'b');
    });

    test('throws PlayerNotFoundException for an unknown id', () {
      final state = GameState.initial(players: _players(['a']));
      expect(() => state.playerById('nonexistent'), throwsA(isA<PlayerNotFoundException>()));
    });
  });

  group('GameState.alivePlayers', () {
    test('excludes dead players', () {
      final state = GameState(
        players: [
          const Player(id: 'a', name: 'a', roleId: 'villageois'),
          const Player(id: 'b', name: 'b', roleId: 'villageois', alive: false),
        ],
        nightIndex: 1,
        phase: GamePhase.night,
      );
      expect(state.alivePlayers.map((p) => p.id), ['a']);
    });
  });

  group('GameState.killPlayer', () {
    test('marks the player dead and stamps cause, night and phase', () {
      final state = GameState(
        players: _players(['a', 'b']),
        nightIndex: 3,
        phase: GamePhase.day,
      );
      final killed = state.killPlayer('a', cause: const DayVoteKill());
      final a = killed.playerById('a');
      expect(a.alive, isFalse);
      expect(a.causeOfDeath, isA<DayVoteKill>());
      expect(a.diedOnNight, 3);
      expect(a.diedOnPhase, GamePhase.day);
    });

    test('leaves the other players untouched and still alive', () {
      final state = GameState.initial(players: _players(['a', 'b']));
      final killed = state.killPlayer('a', cause: const WolvesKill());
      final b = killed.playerById('b');
      expect(b.alive, isTrue);
      expect(b.causeOfDeath, isNull);
      expect(b.diedOnNight, isNull);
      expect(b.diedOnPhase, isNull);
    });
  });

  group('GameState.copyWith', () {
    test('preserves untouched fields', () {
      final state = GameState.initial(players: _players(['a', 'b']));
      final copy = state.copyWith(nightIndex: 2);
      expect(copy.nightIndex, 2);
      expect(copy.phase, state.phase);
      expect(copy.players, state.players);
    });

    test('can explicitly clear a nullable field back to null', () {
      final state = GameState.initial(
        players: _players(['a']),
      ).copyWith(captainPlayerId: 'a');
      expect(state.captainPlayerId, 'a');

      final cleared = state.copyWith(captainPlayerId: null);
      expect(cleared.captainPlayerId, isNull);
    });

    test('omitting a nullable field leaves it unchanged, not cleared', () {
      final state = GameState.initial(
        players: _players(['a']),
      ).copyWith(captainPlayerId: 'a');
      final copy = state.copyWith(nightIndex: 3);
      expect(copy.captainPlayerId, 'a');
    });
  });

  group('LoversPair.partnerOf', () {
    const pair = LoversPair('a', 'b');

    test('returns the other player from either side', () {
      expect(pair.partnerOf('a'), 'b');
      expect(pair.partnerOf('b'), 'a');
    });

    test('returns null for an unrelated player', () {
      expect(pair.partnerOf('c'), isNull);
    });
  });
}
