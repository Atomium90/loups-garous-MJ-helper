import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table(
  Map<String, String> idToRole, {
  Set<String> dead = const {},
  LoversPair? lovers,
  Map<String, Team> overrides = const {},
}) => GameState.initial(
  players: [
    for (final entry in idToRole.entries)
      Player(
        id: entry.key,
        name: entry.key.toUpperCase(),
        roleId: entry.value,
        alive: !dead.contains(entry.key),
        teamOverride: overrides[entry.key],
      ),
  ],
).copyWith(lovers: lovers);

void main() {
  final registry = RoleRegistry.all;
  VictoryKind? propose(GameState state) => proposeVictory(state, registry);

  test('the game goes on while wolves and villagers are both alive', () {
    expect(propose(_table({'a': 'loup_garou', 'b': 'voyante', 'c': 'villageois'})), isNull);
  });

  test('the village wins when no wolf is left', () {
    expect(
      propose(_table({'a': 'loup_garou', 'b': 'voyante', 'c': 'villageois'}, dead: {'a'})),
      VictoryKind.village,
    );
  });

  test('the wolves win when only wolves are left', () {
    expect(
      propose(_table({'a': 'loup_garou', 'b': 'voyante', 'c': 'loup_garou'}, dead: {'b'})),
      VictoryKind.werewolves,
    );
  });

  test('nobody wins when nobody is left', () {
    expect(propose(_table({'a': 'loup_garou', 'b': 'voyante'}, dead: {'a', 'b'})), VictoryKind.nobody);
  });

  test('an unresolved Voleur counts with the village', () {
    expect(propose(_table({'a': 'loup_garou', 'b': 'voleur'}, dead: {'a'})), VictoryKind.village);
    expect(propose(_table({'a': 'loup_garou', 'b': 'voleur'})), isNull);
  });

  group('lovers', () {
    const pair = LoversPair('a', 'b');

    test('a wolf and a villager left alone together win as lovers', () {
      expect(
        propose(_table({'a': 'loup_garou', 'b': 'voyante', 'c': 'villageois'}, dead: {'c'}, lovers: pair)),
        VictoryKind.lovers,
      );
    });

    test('lovers of the same side just win with their side', () {
      expect(
        propose(_table({'a': 'voyante', 'b': 'sorciere', 'c': 'loup_garou'}, dead: {'c'}, lovers: pair)),
        VictoryKind.village,
      );
    });

    test('mixed lovers with someone else still alive do not end the game', () {
      expect(
        propose(_table({'a': 'loup_garou', 'b': 'voyante', 'c': 'villageois'}, lovers: pair)),
        isNull,
      );
    });

    test('a dead lover is no couple: the usual sides decide', () {
      expect(
        propose(_table({'a': 'loup_garou', 'b': 'voyante'}, dead: {'b'}, lovers: pair)),
        VictoryKind.werewolves,
      );
    });
  });

  group('sides that moved', () {
    test('an infected villager counts as a wolf', () {
      final state = _table(
        {'a': 'loup_garou', 'b': 'voyante'},
        overrides: {'b': Team.werewolves},
      );
      expect(propose(state), VictoryKind.werewolves);
    });

    test('a solo player alive means no proposal from the usual sides', () {
      final state = _table(
        {'a': 'loup_garou', 'b': 'voyante'},
        dead: {'a'},
        overrides: {'b': Team.solo},
      );
      expect(propose(state), isNull);
    });
  });
}
