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
    state = AsyncData(draft.copyWith(roleCounts: counts));
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
    state = AsyncData(draft.copyWith(roleCounts: counts));
  }

  void clearRoles() {
    final draft = state.value;
    if (draft == null) return;
    state = AsyncData(draft.copyWith(roleCounts: const {}));
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
    );
    ref.invalidate(gameListProvider);
    ref.invalidate(gameProvider(gameId));
  }
}
