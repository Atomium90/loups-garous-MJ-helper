import 'dart:math';

import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

/// A pool shaped like the real base game (a wolf role + a villager filler), plus one oversized
/// tier (4 interchangeable roles) - the base box alone never has more candidates than a tier's
/// target slots, so this is what actually exercises the shuffle-and-cut path.
CardPool _poolWithSurplusTier() => CardPool(
  registry: const RoleRegistry([
    Role(id: 'loup_garou', team: Team.werewolves, multiple: true, hasNightCall: true),
    Role(id: 'villageois', team: Team.village, multiple: true, hasNightCall: false),
    Role(id: 'a', team: Team.village, suggestionTier: 1, hasNightCall: false),
    Role(id: 'b', team: Team.village, suggestionTier: 2, hasNightCall: false),
    Role(id: 'c', team: Team.village, suggestionTier: 2, hasNightCall: false),
    Role(id: 'd', team: Team.village, suggestionTier: 2, hasNightCall: false),
    Role(id: 'e', team: Team.village, suggestionTier: 2, hasNightCall: false),
  ]),
  boxes: const [
    GameBox(
      id: baseBoxId,
      cards: {'loup_garou': 4, 'villageois': 20, 'a': 1, 'b': 1, 'c': 1, 'd': 1, 'e': 1},
    ),
  ],
);

CardPool _basePool([Iterable<String> boxes = const []]) =>
    CardPool(registry: RoleRegistry.all, ownedBoxIds: boxes);

void main() {
  scarceVillagersTests();

  group('CompositionAdvisor wolf bands', () {
    test('2 wolves from 8 to 10 players, 3 from 11, 4 from 15', () {
      final advisor = CompositionAdvisor(_basePool(), random: Random(1));
      expect(advisor.suggest(8).roleCounts['loup_garou'], 2);
      expect(advisor.suggest(10).roleCounts['loup_garou'], 2);
      expect(advisor.suggest(11).roleCounts['loup_garou'], 3);
      expect(advisor.suggest(14).roleCounts['loup_garou'], 3);
      expect(advisor.suggest(15).roleCounts['loup_garou'], 4);
      expect(advisor.suggest(18).roleCounts['loup_garou'], 4);
    });
  });

  group('CompositionAdvisor.suggest on the base box', () {
    test('always assigns exactly the requested player count, 8 through 18', () {
      final advisor = CompositionAdvisor(_basePool(), random: Random(1));
      for (var n = 8; n <= 18; n++) {
        final total = advisor.suggest(n).roleCounts.values.fold(0, (a, b) => a + b);
        expect(total, n, reason: 'player count $n');
      }
    });

    test('tier-1 roles are always included once they fit (8 players)', () {
      final advisor = CompositionAdvisor(_basePool(), random: Random(1));
      final counts = advisor.suggest(8).roleCounts;
      expect(counts['voyante'], 1);
      expect(counts['sorciere'], 1);
    });

    test('the Voleur never appears in a suggestion, 8 through 18', () {
      final advisor = CompositionAdvisor(_basePool(), random: Random(1));
      for (var n = 8; n <= 18; n++) {
        expect(advisor.suggest(n).roleCounts.containsKey('voleur'), isFalse, reason: '$n players');
      }
    });
  });

  group('CompositionAdvisor determinism', () {
    test('two advisors seeded alike suggest the same composition', () {
      final a = CompositionAdvisor(_basePool(), random: Random(42));
      final b = CompositionAdvisor(_basePool(), random: Random(42));
      expect(a.suggest(12).roleCounts, equals(b.suggest(12).roleCounts));
    });
  });

  group('CompositionAdvisor variety (oversized tier)', () {
    test('the essential tier is always kept, the surplus tier is cut down to size', () {
      final advisor = CompositionAdvisor(_poolWithSurplusTier(), random: Random(7));
      final counts = advisor.suggest(8).roleCounts;
      // wolves 2, specials target 4: tier 1's "a" (1) + 3 of tier 2's 4 candidates.
      expect(counts['a'], 1);
      final tier2Picked = ['b', 'c', 'd', 'e'].where(counts.containsKey).length;
      expect(tier2Picked, 3);
    });

    test('different seeds can pick a different subset of an oversized tier', () {
      final outcomes = <Set<String>>{};
      for (var seed = 0; seed < 20; seed++) {
        final advisor = CompositionAdvisor(_poolWithSurplusTier(), random: Random(seed));
        final counts = advisor.suggest(8).roleCounts;
        outcomes.add({'b', 'c', 'd', 'e'}.where(counts.containsKey).toSet());
      }
      // Not a hard guarantee for any single seed range, but with 4-choose-3 = 4 possible
      // subsets and 20 seeds, seeing only one outcome would mean the shuffle isn't doing
      // anything - that's the actual regression this test guards against.
      expect(outcomes.length, greaterThan(1));
    });
  });
}

/// A box set where the deck is mostly special roles, to exercise the Simple Villageois budget.
CardPool _scarceVillagersPool() => CardPool(
  registry: const RoleRegistry([
    Role(id: 'loup_garou', team: Team.werewolves, multiple: true, hasNightCall: false),
    Role(id: 'villageois', team: Team.village, multiple: true, hasNightCall: false),
    Role(id: 'a', team: Team.village, suggestionTier: 1, hasNightCall: false),
    Role(id: 'b', team: Team.village, suggestionTier: 1, hasNightCall: false),
    Role(id: 'c', team: Team.village, suggestionTier: 2, hasNightCall: false),
    Role(id: 's', team: Team.village, suggestionTier: 2, hasNightCall: false),
  ]),
  boxes: const [
    GameBox(
      id: baseBoxId,
      cards: {'loup_garou': 4, 'villageois': 3, 'a': 1, 'b': 1, 'c': 1},
    ),
    GameBox(id: 'stickers', stickers: ['s']),
  ],
  ownedBoxIds: const ['stickers'],
);

void scarceVillagersTests() {
  group('CompositionAdvisor with few Simples Villageois', () {
    test('adds roles and wolves rather than more Simples Villageois than exist', () {
      final advisor = CompositionAdvisor(_scarceVillagersPool(), random: Random(1));
      final counts = advisor.suggest(10).roleCounts;
      expect(counts.values.fold(0, (a, b) => a + b), 10);
      final stickerRoles = counts.containsKey('s') ? 1 : 0;
      expect((counts['villageois'] ?? 0) + stickerRoles, lessThanOrEqualTo(3));
    });
  });
}
