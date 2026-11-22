import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table({String? captain, GamePhase phase = GamePhase.day, int night = 2}) =>
    GameState.initial(
      players: const [
        Player(id: 'idiot', name: 'Idiot', roleId: 'idiot_du_village'),
        Player(id: 'w', name: 'W', roleId: 'loup_garou'),
        Player(id: 'a', name: 'A', roleId: 'villageois'),
        Player(id: 'b', name: 'B', roleId: 'villageois'),
      ],
    ).copyWith(phase: phase, nightIndex: night, captainPlayerId: captain);

void main() {
  const machine = GameStateMachine();
  final registry = RoleRegistry.all;

  ActionResult apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry);

  test('the Village Idiot is a village role with no night call', () {
    final role = registry.byId('idiot_du_village');
    expect(role.team, Team.village);
    expect(role.hasNightCall, isFalse);
  });

  group('voted against by the village', () {
    test('he is pardoned: alive, nobody eliminated, and he no longer votes', () {
      final result = apply(_table(), const DayVoteElimination(targetPlayerId: 'idiot'));
      final idiot = result.state.playerById('idiot');
      expect(idiot.alive, isTrue);
      expect(idiot.hasStatus(PlayerStatus.pardoned), isTrue);
      expect(result.events.whereType<PlayerDied>(), isEmpty);
      expect(result.events.whereType<IdiotPardoned>(), hasLength(1));
      expect(result.state.alivePlayers, hasLength(4));
    });

    test('the pardon is used once: voted against again, he is eliminated', () {
      var state = apply(_table(), const DayVoteElimination(targetPlayerId: 'idiot')).state;
      state = apply(state, const DayVoteElimination(targetPlayerId: 'idiot')).state;
      expect(state.playerById('idiot').alive, isFalse);
      expect(state.playerById('idiot').causeOfDeath, isA<DayVoteKill>());
    });

    test('he keeps the Capitaine\'s honor when pardoned', () {
      final state = apply(
        _table(captain: 'idiot'),
        const DayVoteElimination(targetPlayerId: 'idiot'),
      ).state;
      expect(state.captainPlayerId, 'idiot');
    });

    test('the pardon survives a save', () {
      final state = apply(_table(), const DayVoteElimination(targetPlayerId: 'idiot')).state;
      final back = GameStateJson.decode(GameStateJson.encode(state));
      expect(back.playerById('idiot').hasStatus(PlayerStatus.pardoned), isTrue);
    });
  });

  group('eliminated any other way', () {
    test('devoured by the wolves, he dies', () {
      var state = _table(phase: GamePhase.night, night: 1);
      state = apply(state, const WolvesTarget(targetPlayerId: 'idiot')).state;
      state = apply(state, const FinalizeNight()).state;
      expect(state.playerById('idiot').alive, isFalse);
    });

    test('shot by the Hunter, he dies', () {
      final withHunter = GameState.initial(
        players: const [
          Player(id: 'h', name: 'H', roleId: 'chasseur'),
          Player(id: 'idiot', name: 'Idiot', roleId: 'idiot_du_village'),
          Player(id: 'w', name: 'W', roleId: 'loup_garou'),
        ],
      ).copyWith(phase: GamePhase.day, nightIndex: 2);
      var state = apply(withHunter, const DayVoteElimination(targetPlayerId: 'h')).state;
      state = apply(state, const HunterShoot(targetPlayerId: 'idiot')).state;
      expect(state.playerById('idiot').alive, isFalse);
    });
  });

  group('the honor of Capitaine', () {
    test('is lost with the Idiot, not passed on, when his card is known', () {
      var state = _table(captain: 'idiot', phase: GamePhase.night, night: 1);
      state = apply(state, const WolvesTarget(targetPlayerId: 'idiot')).state;
      final result = apply(state, const FinalizeNight());
      expect(result.state.playerById('idiot').alive, isFalse);
      expect(result.state.captainPlayerId, isNull);
      expect(result.state.cascade, isNull);
    });

    test('can be given up by the MJ when the card was only known too late', () {
      // His card was unknown when he died (a plain villager for the engine): a succession is asked.
      var state = GameState.initial(
        players: const [
          Player(id: 'x', name: 'X', roleId: 'villageois'),
          Player(id: 'a', name: 'A', roleId: 'villageois'),
          Player(id: 'w', name: 'W', roleId: 'loup_garou'),
        ],
      ).copyWith(phase: GamePhase.day, nightIndex: 2, captainPlayerId: 'x');
      state = apply(state, const DayVoteElimination(targetPlayerId: 'x')).state;
      expect(state.cascade?.decision, isA<PendingCaptainSuccession>());

      final result = apply(state, const CaptainNoSuccessor());
      expect(result.state.captainPlayerId, isNull);
      expect(result.state.cascade, isNull);
      expect(result.events.whereType<CaptainSuccessionSkipped>(), hasLength(1));
    });

    test('no successor can only answer a pending succession', () {
      expect(
        () => apply(_table(), const CaptainNoSuccessor()),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });
}
