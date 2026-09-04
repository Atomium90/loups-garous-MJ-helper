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

    /// The CompositionAdvisor's current pick for [playerCount] - not persisted (absent from
    /// [fromGame], filled in by CompositionEditor.build right after). Recomputed only when
    /// the player count changes or the MJ asks for another suggestion, never by editing
    /// [roleCounts]/[reserveRoleIds] directly - otherwise ticking a chip would silently
    /// reroll the suggestion shown on screen.
    CompositionSuggestion? suggestion,
  }) = _CompositionDraft;

  factory CompositionDraft.fromGame(Game game) => CompositionDraft(
    gameId: game.id,
    playerCount: game.playerCount,
    roleCounts: game.compositionJson ?? const {},
    reserveRoleIds: game.reserveRolesJson ?? const [],
  );

  int get assignedCount => roleCounts.values.fold(0, (a, b) => a + b);
  int get remaining => playerCount - assignedCount;

  /// The Voleur brings the two-card reserve into play.
  bool get hasVoleur => roleCounts.containsKey('voleur');

  /// The reserve is fully specified: not needed without the Voleur, exactly
  /// two cards with it.
  bool get reserveComplete => !hasVoleur || reserveRoleIds.length == 2;

  bool get isValid => remaining >= 0 && reserveComplete;

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

  /// Cards of [roleId] still free against the box's `copies`, given what the
  /// deal and the reserve already claim. [ignoreReserveSlot] excludes one
  /// reserve slot from the tally - the slot currently being (re)picked.
  int cardsLeft(String roleId, RoleRegistry registry, {int? ignoreReserveSlot}) {
    final box = registry.byIdOrNull(roleId)?.copies ?? 1;
    final inDeal = roleCounts[roleId] ?? 0;
    var inReserve = 0;
    for (var i = 0; i < reserveRoleIds.length; i++) {
      if (i == ignoreReserveSlot) continue;
      if (reserveRoleIds[i] == roleId) inReserve++;
    }
    return box - inDeal - inReserve;
  }

  /// The roles the MJ may still put in reserve slot [slot]: anything but the
  /// Voleur that has a spare card left in the box.
  List<Role> availableReserveRoles(int slot, RoleRegistry registry) => [
    for (final role in registry.roles)
      if (role.id != 'voleur' && cardsLeft(role.id, registry, ignoreReserveSlot: slot) > 0)
        role,
  ];
}
