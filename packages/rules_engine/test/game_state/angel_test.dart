import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table({
  GamePhase phase = GamePhase.day,
  int night = 0,
  LoversPair? lovers,
}) => GameState.initial(
  players: const [
    Player(id: 'angel', name: 'Angel', roleId: 'ange'),
    Player(id: 'w', name: 'W', roleId: 'loup_garou'),
    Player(id: 'a', name: 'A', roleId: 'villageois'),
    Player(id: 'b', name: 'B', roleId: 'villageois'),
  ],
).copyWith(phase: phase, nightIndex: night, lovers: lovers);

void main() {
  const machine = GameStateMachine();
  final registry = RoleRegistry.all;

  GameState apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry).state;

  VictoryKind? verdict(GameState state) => proposeVictory(state, registry);

  test('the Angel is a solo role with no night call', () {
    final angel = registry.byId('ange');
    expect(angel.team, Team.solo);
    expect(angel.hasNightCall, isFalse);
  });

  group('wins when he is eliminated', () {
    test('at the first vote, before night 1', () {
      final state = apply(_table(), const DayVoteElimination(targetPlayerId: 'angel'));
      expect(state.playerById('angel').diedOnNight, 0);
      expect(verdict(state), VictoryKind.angel);
    });

    test('during the first night, whoever kills him', () {
      var night = _table(phase: GamePhase.night, night: 1);
      night = apply(night, const WolvesTarget(targetPlayerId: 'angel'));
      expect(verdict(apply(night, const FinalizeNight())), VictoryKind.angel);

      var poisoned = _table(phase: GamePhase.night, night: 1);
      poisoned = apply(poisoned, const WitchDeathPotion(targetPlayerId: 'angel'));
      expect(verdict(apply(poisoned, const FinalizeNight())), VictoryKind.angel);
    });

    test('by the Hunter\'s shot at the first vote', () {
      final withHunter = GameState.initial(
        players: const [
          Player(id: 'angel', name: 'Angel', roleId: 'ange'),
          Player(id: 'h', name: 'H', roleId: 'chasseur'),
          Player(id: 'w', name: 'W', roleId: 'loup_garou'),
        ],
      ).copyWith(phase: GamePhase.day, nightIndex: 0);
      var state = apply(withHunter, const DayVoteElimination(targetPlayerId: 'h'));
      state = apply(state, const HunterShoot(targetPlayerId: 'angel'));
      expect(verdict(state), VictoryKind.angel);
    });
  });

  group('does not win when he is eliminated later', () {
    test('at the vote of the first day (after night 1)', () {
      final state = apply(
        _table(phase: GamePhase.day, night: 1),
        const DayVoteElimination(targetPlayerId: 'angel'),
      );
      expect(verdict(state), isNull);
    });

    test('during night 2', () {
      var night = _table(phase: GamePhase.night, night: 2);
      night = apply(night, const WolvesTarget(targetPlayerId: 'angel'));
      expect(verdict(apply(night, const FinalizeNight())), isNull);
    });

    test('when he is one of the lovers: they give up their own goal', () {
      final state = apply(
        _table(phase: GamePhase.night, night: 1, lovers: const LoversPair('angel', 'a')),
        const WitchDeathPotion(targetPlayerId: 'angel'),
      );
      expect(verdict(apply(state, const FinalizeNight())), isNull);
    });
  });

  group('his side', () {
    test('is his own while the first day and night go on', () {
      expect(_table(night: 0).sideOf(_table().playerById('angel'), registry), Team.solo);
      expect(
        _table(phase: GamePhase.night, night: 1).sideOf(_table().playerById('angel'), registry),
        Team.solo,
      );
    });

    test('is the village\'s once the second day has begun', () {
      final day1 = _table(phase: GamePhase.day, night: 1);
      expect(day1.sideOf(day1.playerById('angel'), registry), Team.village);
      final night2 = _table(phase: GamePhase.night, night: 2);
      expect(night2.sideOf(night2.playerById('angel'), registry), Team.village);
      expect(night2.aliveOnSide(Team.village, registry), 3);
    });

    test('no longer blocks the village from winning', () {
      final state = apply(
        _table(phase: GamePhase.day, night: 2),
        const DayVoteElimination(targetPlayerId: 'w'),
      );
      expect(verdict(state), VictoryKind.village);
    });

    test('while he is a solo player nobody else wins by the usual sides', () {
      final state = apply(
        _table(phase: GamePhase.night, night: 1),
        const WolvesTarget(targetPlayerId: 'a'),
      );
      final morning = apply(state, const FinalizeNight());
      expect(verdict(morning), isNull);
    });
  });

  test('before night 1 no side is declared the winner, whatever the cards say', () {
    // Nobody's card is noted yet, so everyone looks like a villager: no "village wins" banner.
    final state = GameState.initial(
      players: const [
        Player(id: 'a', name: 'A', roleId: 'villageois'),
        Player(id: 'b', name: 'B', roleId: 'villageois'),
      ],
    ).copyWith(phase: GamePhase.day, nightIndex: 0);
    expect(verdict(state), isNull);
  });

  test('a game starting before night 1 goes straight from the vote to night 1', () {
    var state = apply(_table(), const DayVoteElimination(targetPlayerId: 'a'));
    state = apply(state, const StartNextNight());
    expect(state.nightIndex, 1);
    expect(state.phase, GamePhase.night);
  });
}
