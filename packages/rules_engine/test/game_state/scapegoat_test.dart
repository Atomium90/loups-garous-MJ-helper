import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table({
  GamePhase phase = GamePhase.day,
  int night = 2,
  bool powerless = false,
  Set<String> dead = const {},
}) => GameState.initial(
  players: [
    for (final (id, role) in [
      ('goat', 'bouc_emissaire'),
      ('w', 'loup_garou'),
      ('a', 'villageois'),
      ('b', 'villageois'),
    ])
      Player(id: id, name: id.toUpperCase(), roleId: role, alive: !dead.contains(id)),
  ],
).copyWith(phase: phase, nightIndex: night, villagersPowerless: powerless);

void main() {
  const machine = GameStateMachine();
  final registry = RoleRegistry.all;

  ActionResult apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry);

  test('the Scapegoat is a village role with no call whose death asks who votes next', () {
    final role = registry.byId('bouc_emissaire');
    expect(role.team, Team.village);
    expect(role.hasNightCall, isFalse);
    expect(role.onDeath, DeathEffect.scapegoatVoters);
  });

  group('a tied vote', () {
    test('falls on the Scapegoat, even though he was not one of the tied players', () {
      final result = apply(_table(), const DayVoteTie(scapegoatPlayerId: 'goat'));
      expect(result.state.playerById('goat').alive, isFalse);
      expect(result.state.playerById('goat').causeOfDeath, isA<DayVoteKill>());
      expect(result.events.whereType<ScapegoatBlamed>(), hasLength(1));
      expect(result.state.cascade?.decision, isA<PendingScapegoatVoters>());
    });

    test('eliminates nobody without a Scapegoat', () {
      final result = apply(_table(), const DayVoteTie());
      expect(result.state.alivePlayers, hasLength(4));
      expect(result.events, isEmpty);
    });

    test('only a living Scapegoat can take it, and not once the villagers lost their powers', () {
      expect(
        () => apply(_table(), const DayVoteTie(scapegoatPlayerId: 'a')),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table(dead: {'goat'}), const DayVoteTie(scapegoatPlayerId: 'goat')),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table(powerless: true), const DayVoteTie(scapegoatPlayerId: 'goat')),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('only happens during the day', () {
      expect(
        () => apply(
          _table(phase: GamePhase.night),
          const DayVoteTie(scapegoatPlayerId: 'goat'),
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('his last act', () {
    test('names who votes the next day, which is tomorrow when he died in a day', () {
      var state = apply(_table(night: 2), const DayVoteTie(scapegoatPlayerId: 'goat')).state;
      state = apply(state, const ScapegoatChooseVoters(allowedPlayerIds: {'a', 'w'})).state;

      expect(state.cascade, isNull);
      expect(state.voteRestriction?.allowed, {'a', 'w'});
      expect(state.voteRestriction?.day, 3);
      // today's vote is not restricted, tomorrow's is
      expect(state.votersToday, isNull);
      final tomorrow = state.copyWith(nightIndex: 3);
      expect(tomorrow.votersToday, {'a', 'w'});
    });

    test('is this very morning when he was devoured in the night', () {
      var state = _table(phase: GamePhase.night, night: 2);
      state = apply(state, const WolvesTarget(targetPlayerId: 'goat')).state;
      state = apply(state, const FinalizeNight()).state;
      expect(state.cascade?.decision, isA<PendingScapegoatVoters>());

      state = apply(state, const ScapegoatChooseVoters(allowedPlayerIds: {'b'})).state;
      expect(state.voteRestriction?.day, 2);
      expect(state.votersToday, {'b'});
    });

    test('lets nobody vote when he names nobody', () {
      var state = apply(_table(night: 2), const DayVoteTie(scapegoatPlayerId: 'goat')).state;
      state = apply(state, const ScapegoatChooseVoters(allowedPlayerIds: {})).state;
      expect(state.copyWith(nightIndex: 3).votersToday, isEmpty);
    });

    test('forgets a voter who has died since', () {
      var state = apply(_table(night: 2), const DayVoteTie(scapegoatPlayerId: 'goat')).state;
      state = apply(state, const ScapegoatChooseVoters(allowedPlayerIds: {'a', 'b'})).state;
      state = state.killPlayer('a', cause: const WolvesKill()).copyWith(nightIndex: 3);
      expect(state.votersToday, {'b'});
    });

    test('nothing is asked when the villagers lost their powers', () {
      final state = apply(
        _table(powerless: true),
        const DayVoteElimination(targetPlayerId: 'goat'),
      ).state;
      expect(state.cascade, isNull);
    });

    test('cannot be resolved when nothing is pending', () {
      expect(
        () => apply(_table(), const ScapegoatChooseVoters(allowedPlayerIds: {'a'})),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('the restriction and the pending question survive a save', () {
      var state = apply(_table(), const DayVoteTie(scapegoatPlayerId: 'goat')).state;
      final asked = GameStateJson.decode(GameStateJson.encode(state));
      expect(asked.cascade?.decision, isA<PendingScapegoatVoters>());

      state = apply(state, const ScapegoatChooseVoters(allowedPlayerIds: {'a'})).state;
      final back = GameStateJson.decode(GameStateJson.encode(state));
      expect(back.voteRestriction?.allowed, {'a'});
      expect(back.voteRestriction?.day, 3);
    });
  });
}
