import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

List<Player> _players(Map<String, String> idToRole, {Set<String> dead = const {}}) => [
  for (final entry in idToRole.entries)
    Player(
      id: entry.key,
      name: entry.key.toUpperCase(),
      roleId: entry.value,
      alive: !dead.contains(entry.key),
    ),
];

void _expectSameState(GameState a, GameState b) {
  expect(b.nightIndex, a.nightIndex);
  expect(b.phase, a.phase);
  expect(b.captainPlayerId, a.captainPlayerId);
  expect(b.pendingWolfVictimId, a.pendingWolfVictimId);
  expect(b.pendingWitchDeathTargetId, a.pendingWitchDeathTargetId);
  expect(b.witch.lifePotionUsed, a.witch.lifePotionUsed);
  expect(b.witch.deathPotionUsed, a.witch.deathPotionUsed);
  expect(b.lovers?.playerAId, a.lovers?.playerAId);
  expect(b.lovers?.playerBId, a.lovers?.playerBId);
  expect(b.players.map((p) => (p.id, p.name, p.roleId, p.alive, p.diedOnNight, p.diedOnPhase)),
      a.players.map((p) => (p.id, p.name, p.roleId, p.alive, p.diedOnNight, p.diedOnPhase)));
  expect(b.players.map((p) => p.causeOfDeath.runtimeType),
      a.players.map((p) => p.causeOfDeath.runtimeType));
}

void main() {
  GameState roundTrip(GameState state) => GameStateJson.decode(GameStateJson.encode(state));

  test('round-trips a fresh initial state', () {
    final state = GameState.initial(players: _players({'a': 'loup_garou', 'b': 'villageois'}));
    _expectSameState(state, roundTrip(state));
  });

  test('round-trips a mid-night state (pending victim, spent potion, lovers, a dead player)', () {
    final state = GameState.initial(
      players: _players(
        {'a': 'loup_garou', 'b': 'voyante', 'c': 'sorciere', 'd': 'villageois'},
        dead: {'d'},
      ),
    ).copyWith(
      nightIndex: 3,
      pendingWolfVictimId: 'b',
      pendingWitchDeathTargetId: 'a',
      witch: const WitchState(lifePotionUsed: true),
      lovers: const LoversPair('a', 'c'),
      captainPlayerId: 'b',
    );
    _expectSameState(state, roundTrip(state));
  });

  test('round-trips a death: cause, night and phase survive', () {
    const machine = GameStateMachine();
    var state = GameState.initial(
      players: _players({'a': 'loup_garou', 'b': 'villageois', 'c': 'sorciere'}),
    ).copyWith(nightIndex: 2);
    state = machine
        .apply(
          state: state,
          action: const WolvesTarget(targetPlayerId: 'b'),
          roleRegistry: RoleRegistry.base,
        )
        .state;
    state = machine
        .apply(state: state, action: const FinalizeNight(), roleRegistry: RoleRegistry.base)
        .state;

    final restored = roundTrip(state);
    final b = restored.playerById('b');
    expect(b.alive, isFalse);
    expect(b.causeOfDeath, isA<WolvesKill>());
    expect(b.diedOnNight, 2);
    expect(b.diedOnPhase, GamePhase.night);
    _expectSameState(state, restored);
  });

  test('round-trips a day-phase state', () {
    final state = GameState.initial(
      players: _players({'a': 'loup_garou', 'b': 'villageois'}),
    ).copyWith(phase: GamePhase.day, nightIndex: 2);
    expect(roundTrip(state).phase, GamePhase.day);
  });

  test('encode throws on a paused cascade', () {
    final state = GameState.initial(players: _players({'a': 'chasseur', 'b': 'villageois'}))
        .copyWith(
          cascade: const CascadeState(
            decision: PendingHunterShot(deadHunterId: 'a'),
            remainingQueue: [],
          ),
        );
    expect(() => GameStateJson.encode(state), throwsA(isA<UnimplementedError>()));
  });
}
