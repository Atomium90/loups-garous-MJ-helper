import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/game_not_found_exception.dart';
import '../providers/game_list_provider.dart';
import '../providers/game_provider.dart';
import '../providers/game_repository_provider.dart';
import 'composition_draft.dart';

part 'composition_editor_notifier.g.dart';

@riverpod
class CompositionEditor extends _$CompositionEditor {
  @override
  Future<CompositionDraft> build(int gameId) async {
    final game = await ref.watch(gameProvider(gameId).future);
    if (game == null) throw GameNotFoundException(gameId);
    return CompositionDraft.fromGame(game);
  }

  void setPlayerCount(int count) {
    final draft = state.value;
    if (draft == null || count < 0) return;
    state = AsyncData(draft.copyWith(playerCount: count));
  }

  void toggleRole(String roleId) {
    final draft = state.value;
    if (draft == null) return;
    final counts = Map<String, int>.from(draft.roleCounts);
    if (counts.containsKey(roleId)) {
      counts.remove(roleId);
    } else {
      counts[roleId] = 1;
    }
    state = AsyncData(_withCounts(draft, counts));
  }

  void setRoleCount(String roleId, int count) {
    final draft = state.value;
    if (draft == null || count < 0) return;
    final counts = Map<String, int>.from(draft.roleCounts);
    if (count == 0) {
      counts.remove(roleId);
    } else {
      counts[roleId] = count;
    }
    state = AsyncData(_withCounts(draft, counts));
  }

  void clearRoles() {
    final draft = state.value;
    if (draft == null) return;
    state = AsyncData(draft.copyWith(roleCounts: const {}, reserveRoleIds: const []));
  }

  /// Sets the reserve card in [slot] (0 or 1) to [roleId]. Only meaningful
  /// while the Voleur is in the composition.
  void setReserveRole(int slot, String roleId) {
    final draft = state.value;
    if (draft == null || slot < 0 || slot > 1) return;
    final reserve = List<String>.filled(2, '', growable: false).toList();
    for (var i = 0; i < draft.reserveRoleIds.length && i < 2; i++) {
      reserve[i] = draft.reserveRoleIds[i];
    }
    reserve[slot] = roleId;
    state = AsyncData(
      draft.copyWith(reserveRoleIds: [for (final r in reserve) if (r.isNotEmpty) r]),
    );
  }

  /// Drops the reserve card in [slot], if set.
  void clearReserveRole(int slot) {
    final draft = state.value;
    if (draft == null || slot < 0 || slot >= draft.reserveRoleIds.length) return;
    final reserve = List<String>.from(draft.reserveRoleIds)..removeAt(slot);
    state = AsyncData(draft.copyWith(reserveRoleIds: reserve));
  }

  /// Applies new role counts, clearing the reserve when the Voleur is no
  /// longer in play (a stale reserve would otherwise block "Lancer la partie").
  CompositionDraft _withCounts(CompositionDraft draft, Map<String, int> counts) {
    final next = draft.copyWith(roleCounts: counts);
    return next.hasVoleur ? next : next.copyWith(reserveRoleIds: const []);
  }

  Future<void> commit() async {
    final draft = state.value;
    if (draft == null || !draft.isValid) return;

    final counts = Map<String, int>.from(draft.roleCounts);
    if (draft.remaining > 0) {
      counts['villageois'] = (counts['villageois'] ?? 0) + draft.remaining;
    }

    await ref.read(gameRepositoryProvider).saveComposition(
      gameId: draft.gameId,
      playerCount: draft.playerCount,
      roleCounts: counts,
      reserveRoleIds: draft.hasVoleur ? draft.reserveRoleIds : const [],
    );
    ref.invalidate(gameListProvider);
    ref.invalidate(gameProvider(gameId));
  }
}
