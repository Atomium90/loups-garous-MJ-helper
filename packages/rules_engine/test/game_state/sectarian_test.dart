import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

/// Ana (the Sectaire), Bo and Cy in the first group; the wolf W and the villagers D, E in the
/// second.
GameState _table({
  Set<String> dead = const {},
  bool divided = true,
  Map<String, Team> overrides = const {},
}) {
  final state = GameState.initial(
    players: [
      for (final (id, role) in [
        ('ana', 'abominable_sectaire'),
        ('bo', 'villageois'),
        ('cy', 'villageois'),
        ('w', 'loup_garou'),
        ('d', 'villageois'),
        ('e', 'villageois'),
      ])
        Player(id: id, name: id, roleId: role, alive: !dead.contains(id), teamOverride: overrides[id]),
    ],
  );
  return divided
      ? state.copyWith(division: const VillageDivision(groupA: {'ana', 'bo', 'cy'}))
      : state;
}

void main() {
  const machine = GameStateMachine();
  final registry = RoleRegistry.all;

  ActionResult apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry);

  test('the Sectaire is a solo role settled before the night, like the Trusted Villager', () {
    final role = registry.byId('abominable_sectaire');
    expect(role.team, Team.solo);
    expect(role.preparation, isTrue);
    expect(role.wakeCondition, WakeCondition.firstNightOnly);
    final ids = registry.roles.map((r) => r.id).toList();
    expect(ids.indexOf('abominable_sectaire'), lessThan(ids.indexOf('voleur')));
  });

  group('dividing the village', () {
    test('records the first group, the others making up the second', () {
      final state = GameState.initial(
        players: const [
          Player(id: 'a', name: 'A', roleId: 'villageois'),
          Player(id: 'b', name: 'B', roleId: 'villageois'),
          Player(id: 'c', name: 'C', roleId: 'villageois'),
        ],
      );
      final result = apply(state, const DivideVillage(groupAPlayerIds: {'a'}));
      expect(result.state.division?.groupA, {'a'});
      expect(result.state.division?.groupOf('a'), 0);
      expect(result.state.division?.groupOf('c'), 1);
      expect(result.events.whereType<VillageDivided>(), hasLength(1));
    });

    test('needs somebody in each group, and only players of the game', () {
      final state = _table(divided: false);
      expect(
        () => apply(state, const DivideVillage(groupAPlayerIds: {})),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(
          state,
          DivideVillage(groupAPlayerIds: {for (final p in state.players) p.id}),
        ),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(state, const DivideVillage(groupAPlayerIds: {'nobody'})),
        throwsA(isA<PlayerNotFoundException>()),
      );
    });

    test('happens before the first night only', () {
      expect(
        () => apply(
          _table(divided: false).copyWith(nightIndex: 2),
          const DivideVillage(groupAPlayerIds: {'ana'}),
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('survives a save', () {
      final back = GameStateJson.decode(GameStateJson.encode(_table()));
      expect(back.division?.groupA, {'ana', 'bo', 'cy'});
      expect(GameStateJson.decode(GameStateJson.encode(_table(divided: false))).division, isNull);
    });
  });

  group('the victory proposed', () {
    VictoryKind? proposal(GameState state) => proposeVictory(state, registry);

    test('nothing while the group he is not in still has a living player', () {
      expect(proposal(_table(dead: {'d'})), isNull);
      expect(proposal(_table(dead: {'d', 'w'})), isNull);
    });

    test('the Sectaire wins when the whole group he is not in is eliminated', () {
      // The wolf and the villagers D, E are gone: the first group is what is left, and the
      // others are decided too.
      expect(proposal(_table(dead: {'d', 'e', 'w'})), VictoryKind.village);
    });

    test('while the others are not settled, it is the Sectaire who is proposed', () {
      // The second group is gone; with the wolf in the first one, the game goes on without him.
      final state = GameState.initial(
        players: const [
          Player(id: 'ana', name: 'ana', roleId: 'abominable_sectaire'),
          Player(id: 'w', name: 'w', roleId: 'loup_garou'),
          Player(id: 'bo', name: 'bo', roleId: 'villageois'),
          Player(id: 'cy', name: 'cy', roleId: 'villageois', alive: false),
          Player(id: 'd', name: 'd', roleId: 'villageois', alive: false),
        ],
      ).copyWith(division: const VillageDivision(groupA: {'ana', 'w', 'bo'}));
      expect(proposal(state), VictoryKind.sectarian);
    });

    test('once the others are settled too, they decide what is proposed', () {
      final state = GameState.initial(
        players: const [
          Player(id: 'ana', name: 'ana', roleId: 'abominable_sectaire'),
          Player(id: 'w', name: 'w', roleId: 'loup_garou'),
          Player(id: 'bo', name: 'bo', roleId: 'villageois', alive: false),
          Player(id: 'cy', name: 'cy', roleId: 'villageois', alive: false),
        ],
      ).copyWith(division: const VillageDivision(groupA: {'ana', 'w'}));
      expect(proposal(state), VictoryKind.werewolves);
    });

    test('alone with nobody else, he is the one proposed', () {
      final state = GameState.initial(
        players: const [
          Player(id: 'ana', name: 'ana', roleId: 'abominable_sectaire'),
          Player(id: 'bo', name: 'bo', roleId: 'villageois', alive: false),
        ],
      ).copyWith(division: const VillageDivision(groupA: {'ana'}));
      expect(proposal(state), VictoryKind.sectarian);
    });

    test('a dead Sectaire, an infected one, or a village never divided win nothing', () {
      expect(proposal(_table(dead: {'ana', 'd', 'e', 'w'})), VictoryKind.village);
      expect(sectarianWinner(_table(dead: {'ana', 'd', 'e', 'w'})), isNull);
      expect(
        sectarianWinner(_table(dead: {'d', 'e', 'w'}, overrides: {'ana': Team.werewolves})),
        isNull,
      );
      expect(sectarianWinner(_table(dead: {'d', 'e', 'w'}, divided: false)), isNull);
    });

    test('while he is alive and has not won, nobody else is proposed as the winner', () {
      expect(proposal(_table(dead: {'w'})), isNull);
    });
  });
}
