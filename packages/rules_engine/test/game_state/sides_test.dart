import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table(Map<String, String> idToRole, {Set<String> dead = const {}}) =>
    GameState.initial(
      players: [
        for (final entry in idToRole.entries)
          Player(
            id: entry.key,
            name: entry.key.toUpperCase(),
            roleId: entry.value,
            alive: !dead.contains(entry.key),
          ),
      ],
    );

void main() {
  final registry = RoleRegistry.all;

  group('a player\'s side', () {
    test('is their role\'s team by default', () {
      expect(const Player(id: 'a', name: 'A', roleId: 'loup_garou').sideIn(registry), Team.werewolves);
      expect(const Player(id: 'a', name: 'A', roleId: 'voyante').sideIn(registry), Team.village);
      expect(const Player(id: 'a', name: 'A', roleId: 'voleur').sideIn(registry), Team.ambiguous);
    });

    test('is the override when they have one (an infected villager plays with the wolves)', () {
      const infected = Player(
        id: 'a',
        name: 'A',
        roleId: 'voyante',
        teamOverride: Team.werewolves,
        statuses: {PlayerStatus.infected},
      );
      expect(infected.sideIn(registry), Team.werewolves);
      expect(infected.hasStatus(PlayerStatus.infected), isTrue);
      expect(infected.hasStatus(PlayerStatus.charmed), isFalse);
    });

    test('an unknown role counts for the village', () {
      expect(const Player(id: 'a', name: 'A', roleId: 'inconnu').sideIn(registry), Team.village);
    });

    test('copyWith can set the override and clear it again', () {
      const player = Player(id: 'a', name: 'A', roleId: 'voyante');
      final turned = player.copyWith(teamOverride: Team.werewolves);
      expect(turned.teamOverride, Team.werewolves);
      expect(turned.copyWith(roleId: 'sorciere').teamOverride, Team.werewolves);
      expect(turned.copyWith(teamOverride: null).teamOverride, isNull);
    });
  });

  group('counting the living by side', () {
    test('counts only the living, by current side', () {
      final state = _table(
        {'a': 'loup_garou', 'b': 'loup_garou', 'c': 'voyante', 'd': 'villageois'},
        dead: {'b'},
      );
      expect(state.aliveWolves(registry), 1);
      expect(state.aliveOnSide(Team.village, registry), 2);
    });

    test('an override moves a player to the other side', () {
      final state = _table({'a': 'loup_garou', 'b': 'voyante'});
      final infected = state.copyWith(
        players: [
          state.players[0],
          state.players[1].copyWith(teamOverride: Team.werewolves),
        ],
      );
      expect(infected.aliveWolves(registry), 2);
      expect(infected.aliveOnSide(Team.village, registry), 0);
    });
  });

  group('aliveNeighbours', () {
    test('are the seats on either side, in roster order', () {
      final state = _table({'a': 'villageois', 'b': 'villageois', 'c': 'villageois', 'd': 'villageois'});
      final around = state.aliveNeighbours('b');
      expect(around.left?.id, 'a');
      expect(around.right?.id, 'c');
    });

    test('wrap around the end of the roster', () {
      final state = _table({'a': 'villageois', 'b': 'villageois', 'c': 'villageois', 'd': 'villageois'});
      expect(state.aliveNeighbours('a').left?.id, 'd');
      expect(state.aliveNeighbours('d').right?.id, 'a');
    });

    test('skip the dead seats', () {
      final state = _table(
        {'a': 'villageois', 'b': 'villageois', 'c': 'villageois', 'd': 'villageois', 'e': 'villageois'},
        dead: {'b', 'c'},
      );
      final around = state.aliveNeighbours('d');
      expect(around.left?.id, 'a');
      expect(around.right?.id, 'e');
    });

    test('are the same player on both sides when only one other is alive', () {
      final state = _table({'a': 'villageois', 'b': 'villageois', 'c': 'villageois'}, dead: {'c'});
      final around = state.aliveNeighbours('a');
      expect(around.left?.id, 'b');
      expect(around.right?.id, 'b');
    });

    test('are nobody when nobody else is alive', () {
      final state = _table({'a': 'villageois', 'b': 'villageois'}, dead: {'b'});
      final around = state.aliveNeighbours('a');
      expect(around.left, isNull);
      expect(around.right, isNull);
    });

    test('can be asked for a dead player (the Fox\'s middle player may die)', () {
      final state = _table({'a': 'villageois', 'b': 'villageois', 'c': 'villageois'}, dead: {'b'});
      expect(state.aliveNeighbours('b').left?.id, 'a');
      expect(state.aliveNeighbours('b').right?.id, 'c');
    });

    test('an unknown player is an error', () {
      expect(
        () => _table({'a': 'villageois'}).aliveNeighbours('zzz'),
        throwsA(isA<PlayerNotFoundException>()),
      );
    });
  });
}
