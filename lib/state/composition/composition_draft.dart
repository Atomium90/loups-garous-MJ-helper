import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../data/database/app_database.dart';

part 'composition_draft.freezed.dart';

/// Local draft state for the composition screen: mutated by chip taps and
/// the player-count stepper, only persisted when the MJ commits it.
@freezed
abstract class CompositionDraft with _$CompositionDraft {
  const CompositionDraft._();

  const factory CompositionDraft({
    required int gameId,
    required int playerCount,
    required Map<String, int> roleCounts,

    /// The Voleur's two undealt cards. Empty unless the Voleur is in
    /// [roleCounts]; then it must hold exactly two role ids for the draft to
    /// be valid.
    @Default(<String>[]) List<String> reserveRoleIds,

    /// Whether the MJ picks the Voleur's reserve here (the house-rule setting). Otherwise the
    /// reserve is whatever two cards are left after the deal, noted on night 1: the draft has
    /// no reserve to pick, and the pack just holds two more Simples Villageois.
    @Default(false) bool reserveChosen,

    /// The CompositionAdvisor's current pick for [playerCount] - not persisted (absent from
    /// [fromGame], filled in by CompositionEditor.build right after). Recomputed only when
    /// the player count changes or the MJ asks for another suggestion, never by editing
    /// [roleCounts]/[reserveRoleIds] directly - otherwise ticking a chip would silently
    /// reroll the suggestion shown on screen.
    CompositionSuggestion? suggestion,
  }) = _CompositionDraft;

  factory CompositionDraft.fromGame(Game game, {bool reserveChosen = false}) => CompositionDraft(
    gameId: game.id,
    playerCount: game.playerCount,
    roleCounts: game.compositionJson ?? const {},
    reserveRoleIds: reserveChosen ? game.reserveRolesJson ?? const [] : const [],
    reserveChosen: reserveChosen,
  );

  int get assignedCount => roleCounts.values.fold(0, (a, b) => a + b);
  int get remaining => playerCount - assignedCount;

  /// The Voleur brings the two-card reserve into play.
  bool get hasVoleur => roleCounts.containsKey('voleur');

  /// The Voleur's pack holds two more cards than there are players, drawn at random.
  bool get reserveDrawn => hasVoleur && !reserveChosen;

  /// The reserve is fully specified: not needed without the Voleur, nor when it is left to
  /// the draw, exactly two cards otherwise.
  bool get reserveComplete => !reserveChosen || !hasVoleur || reserveRoleIds.length == 2;

  bool get isValid => remaining >= 0 && reserveComplete;

  /// [isValid], and the deal as it will be launched exists in [pool]: the seats left over filled
  /// with Simples Villageois, the two extra ones of a drawn reserve, the reserve cards the MJ
  /// picked. A box may have been unticked since the draft was made.
  bool isValidFor(CardPool pool) {
    if (!isValid) return false;
    final deal = _claimed();
    if (remaining > 0) deal.update('villageois', (n) => n + remaining, ifAbsent: () => remaining);
    return pool.fits(deal);
  }

  /// True once the displayed composition exactly matches [suggestion] - the "Suggestion" card
  /// hides at that point (nothing left to apply). Compared by hand rather than pulling in
  /// `package:collection` just for a map equality check the app doesn't otherwise need.
  bool get suggestionApplied {
    final target = suggestion?.roleCounts;
    if (target == null || target.length != roleCounts.length) return false;
    for (final entry in roleCounts.entries) {
      if (target[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Cards of [roleId] still free in [pool], given what the deal and the reserve already claim.
  /// [ignoreReserveSlot] excludes one reserve slot from the tally - the slot currently being
  /// (re)picked.
  int cardsLeft(String roleId, CardPool pool, {int? ignoreReserveSlot}) =>
      pool.cardsLeft(roleId, _claimed(ignoreReserveSlot: ignoreReserveSlot));

  /// Role id -> cards the deal and the reserve claim.
  Map<String, int> _claimed({int? ignoreReserveSlot}) {
    final claimed = Map<String, int>.from(roleCounts);
    if (reserveDrawn) claimed.update('villageois', (n) => n + 2, ifAbsent: () => 2);
    for (var i = 0; i < reserveRoleIds.length; i++) {
      if (i == ignoreReserveSlot) continue;
      claimed.update(reserveRoleIds[i], (n) => n + 1, ifAbsent: () => 1);
    }
    return claimed;
  }

  /// The roles the MJ may still put in reserve slot [slot]: anything but the
  /// Voleur that has a spare card left in [pool].
  List<Role> availableReserveRoles(int slot, CardPool pool) => [
    for (final role in pool.available.roles)
      if (role.id != 'voleur' && cardsLeft(role.id, pool, ignoreReserveSlot: slot) > 0) role,
  ];
}
