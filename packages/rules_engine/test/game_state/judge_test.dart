import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table({
  GamePhase phase = GamePhase.day,
  int night = 2,
  bool powerless = false,
  bool judgeAlive = true,
}) => GameState.initial(
  players: [
    Player(id: 'judge', name: 'Judge', roleId: 'juge_begue', alive: judgeAlive),
    const Player(id: 'w', name: 'W', roleId: 'loup_garou'),
    const Player(id: 'a', name: 'A', roleId: 'villageois'),
    const Player(id: 'b', name: 'B', roleId: 'villageois'),
  ],
).copyWith(phase: phase, nightIndex: night, villagersPowerless: powerless);

void main() {
  const machine = GameStateMachine();
  final registry = RoleRegistry.all;

  ActionResult apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry);

  test('the Wandering Judge is a village role shown on the first night only', () {
    final role = registry.byId('juge_begue');
    expect(role.team, Team.village);
    expect(role.hasNightCall, isTrue);
    expect(role.wakeCondition, WakeCondition.firstNightOnly);
  });

  test('he is called after the Fox and before the Sisters', () {
    final ids = registry.roles.map((r) => r.id).toList();
    expect(ids.indexOf('juge_begue'), ids.indexOf('renard') + 1);
    expect(ids.indexOf('juge_begue'), lessThan(ids.indexOf('deux_soeurs')));
  });

  group('his sign', () {
    test('calls for a second vote today and spends his power', () {
      final result = apply(_table(night: 2), const JudgeSign());
      expect(result.events.whereType<JudgeSignGiven>(), hasLength(1));
      expect(result.state.spentPowers, {'juge_begue': 2});
      expect(result.state.secondVoteToday, isTrue);
    });

    test('the second vote is today only', () {
      final state = apply(_table(night: 2), const JudgeSign()).state;
      expect(state.copyWith(nightIndex: 3).secondVoteToday, isFalse);
      expect(_table().secondVoteToday, isFalse);
    });

    test('can be given once in a game', () {
      final state = apply(_table(night: 2), const JudgeSign()).state;
      expect(
        () => apply(state.copyWith(nightIndex: 3), const JudgeSign()),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('needs a living Judge, a day, and villagers who still have their powers', () {
      expect(
        () => apply(_table(judgeAlive: false), const JudgeSign()),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table(phase: GamePhase.night), const JudgeSign()),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table(powerless: true), const JudgeSign()),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('survives a save', () {
      final state = apply(_table(night: 2), const JudgeSign()).state;
      final back = GameStateJson.decode(GameStateJson.encode(state));
      expect(back.secondVoteToday, isTrue);
    });
  });
}
