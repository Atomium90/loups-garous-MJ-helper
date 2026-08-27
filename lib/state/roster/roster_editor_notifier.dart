import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/game_repository_provider.dart';
import '../providers/roster_provider.dart';
import 'roster_draft.dart';

part 'roster_editor_notifier.g.dart';

/// Draft-then-commit editing for the A1 "Les joueurs" screen. Mirrors
/// [CompositionEditor]: local [RosterDraft] state, only written on [commit].
/// Codegen-safe (unlike [rosterProvider]) because [RosterDraft] is an
/// app-defined type, not a Drift `part`-file type.
@riverpod
class RosterEditor extends _$RosterEditor {
  @override
  Future<RosterDraft> build(int gameId) async {
    final rows = await ref.watch(rosterProvider(gameId).future);
    return RosterDraft.fromRoster(gameId, rows);
  }

  void setName(int seatIndex, String value) {
    final draft = state.value;
    if (draft == null || seatIndex < 0 || seatIndex >= draft.names.length) return;
    final names = List<String>.from(draft.names);
    names[seatIndex] = value;
    state = AsyncData(draft.copyWith(names: names));
  }

  Future<void> commit() async {
    final draft = state.value;
    if (draft == null || !draft.allNamed) return;

    await ref.read(gameRepositoryProvider).savePlayerNames(
      gameId: draft.gameId,
      names: draft.names.map((n) => n.trim()).toList(),
    );
    ref.invalidate(rosterProvider(gameId));
  }
}
