import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

GameState _table({int night = 1, GamePhase phase = GamePhase.night}) => GameState.initial(
  players: const [
    Player(id: 'actor', name: 'Actor', roleId: 'comedien'),
    Player(id: 'w', name: 'W', roleId: 'loup_garou'),
    Player(id: 'a', name: 'A', roleId: 'villageois'),
    Player(id: 'b', name: 'B', roleId: 'villageois'),
  ],
).copyWith(nightIndex: night, phase: phase);

const _cards = ['voyante', 'sorciere', 'salvateur'];

void main() {
  const machine = GameStateMachine();
  const builder = NightScriptBuilder();
  final registry = RoleRegistry.all;

  ActionResult apply(GameState state, GameAction action) =>
      machine.apply(state: state, action: action, roleRegistry: registry);

  GameState withCards([GameState? from]) =>
      apply(from ?? _table(), const ActorSetCards(roleIds: _cards)).state;

  test('the Comedien is called after the Voleur, every night until his cards are used', () {
    final role = registry.byId('comedien');
    expect(role.hasNightCall, isTrue);
    expect(role.wakeCondition, WakeCondition.conditional);
    expect(role.wakeGuard, WakeGuard.powerUnspent);
    final ids = registry.roles.map((r) => r.id).toList();
    expect(ids.indexOf('comedien'), ids.indexOf('voleur') + 1);
    expect(ids.indexOf('comedien'), lessThan(ids.indexOf('cupidon')));
  });

  group('his cards', () {
    test('are three different roles among those he can play', () {
      final state = apply(_table(), const ActorSetCards(roleIds: _cards)).state;
      expect(state.actor?.cards, _cards);
      expect(state.actor?.available, _cards);
      expect(
        () => apply(_table(), const ActorSetCards(roleIds: ['voyante', 'sorciere'])),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table(), const ActorSetCards(roleIds: ['voyante', 'voyante', 'sorciere'])),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table(), const ActorSetCards(roleIds: ['voyante', 'sorciere', 'loup_garou'])),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('can be laid down again until one is used', () {
      final once = withCards();
      final again = apply(once, const ActorSetCards(roleIds: ['voyante', 'cupidon', 'renard']));
      expect(again.state.actor?.cards, ['voyante', 'cupidon', 'renard']);

      final used = apply(once, const ActorChooseCard(roleId: 'voyante')).state;
      final next = apply(used, const FinalizeNight()).state;
      expect(
        () => apply(
          next.copyWith(phase: GamePhase.night),
          const ActorSetCards(roleIds: ['voyante', 'cupidon', 'renard']),
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });
  });

  group('choosing a card', () {
    test('takes the power of one card still on the table, once a night', () {
      final result = apply(withCards(), const ActorChooseCard(roleId: 'sorciere'));
      expect(result.state.actor?.current, 'sorciere');
      expect(result.events.whereType<ActorChoseCard>(), hasLength(1));
      expect(
        () => apply(result.state, const ActorChooseCard(roleId: 'voyante')),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('refuses a card that is not his, and needs the cards laid down', () {
      expect(
        () => apply(withCards(), const ActorChooseCard(roleId: 'renard')),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(_table(), const ActorChooseCard(roleId: 'voyante')),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('Cupidon can only be played on the first night, while no lovers exist', () {
      const cupidCards = ['cupidon', 'voyante', 'sorciere'];
      GameState table(int night) =>
          apply(_table(night: night), const ActorSetCards(roleIds: cupidCards)).state;
      expect(
        apply(table(1), const ActorChooseCard(roleId: 'cupidon')).state.actor?.current,
        'cupidon',
      );
      expect(
        () => apply(table(2), const ActorChooseCard(roleId: 'cupidon')),
        throwsA(isA<InvalidActionError>()),
      );
      expect(
        () => apply(
          table(1).copyWith(lovers: const LoversPair('a', 'b')),
          const ActorChooseCard(roleId: 'cupidon'),
        ),
        throwsA(isA<InvalidActionError>()),
      );
    });

    test('the card used leaves the game when the night ends', () {
      var state = apply(withCards(), const ActorChooseCard(roleId: 'voyante')).state;
      state = apply(state, const FinalizeNight()).state;
      expect(state.actor?.used, ['voyante']);
      expect(state.actor?.current, isNull);
      expect(state.actor?.available, ['sorciere', 'salvateur']);
      expect(state.spentPowers, isEmpty);
    });

    test('with the last card gone he is not called again', () {
      var state = withCards();
      for (final card in _cards) {
        state = state.copyWith(phase: GamePhase.night);
        state = apply(state, ActorChooseCard(roleId: card)).state;
        state = apply(state, const FinalizeNight()).state;
        state = state.copyWith(nightIndex: state.nightIndex + 1);
      }
      expect(state.actor?.available, isEmpty);
      expect(state.spentPowers, {'comedien': 3});
    });

    test('survives a save', () {
      final state = apply(withCards(), const ActorChooseCard(roleId: 'voyante')).state;
      final back = GameStateJson.decode(GameStateJson.encode(state));
      expect(back.actor?.cards, _cards);
      expect(back.actor?.current, 'voyante');
      expect(back.actor?.used, isEmpty);
    });
  });

  group('the night script', () {
    List<String> script(int night, {String? card, Set<String> spent = const {}}) {
      final roles = [
        for (final r in registry.roles)
          if (const {'comedien', 'cupidon', 'voyante', 'sorciere', 'loup_garou'}.contains(r.id))
            r,
      ];
      return builder
          .build(
            compositionRoles: roles,
            aliveRoleIds: {for (final r in roles) r.id},
            nightIndex: night,
            context: NightContext(nightIndex: night, actorCard: card, spentPowers: spent),
          )
          .steps
          .map((s) => s.role.id)
          .toList();
    }

    test('the Comedien comes first, every night', () {
      expect(script(1).first, 'comedien');
      expect(script(4).first, 'comedien');
    });

    test('the card he took is called at its place, whatever its own wake condition', () {
      // Cupidon is a first-night role: he is called on night 3 only for the card.
      expect(script(3), ['comedien', 'voyante', 'loup_garou', 'sorciere']);
      expect(script(3, card: 'cupidon'), ['comedien', 'cupidon', 'voyante', 'loup_garou', 'sorciere']);
    });

    test('once his cards are used he is no longer called', () {
      expect(script(4, spent: {'comedien'}).contains('comedien'), isFalse);
    });
  });
}
