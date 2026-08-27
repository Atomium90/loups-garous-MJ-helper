import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import 'game_repository_provider.dart';

/// Manually written, not @riverpod codegen: see gameListProvider's comment,
/// same InvalidTypeException workaround for Drift's generated `PlayerRow` type
/// (riverpod_generator can't embed a type defined via a `part` file).
///
/// A one-shot `FutureProvider` (over `getRoster`), mirroring [gameProvider],
/// not a `StreamProvider` over the repository's `watchRoster`: the A1/A2
/// screens only need a fresh snapshot per visit, [RosterEditor] holds the live
/// draft while editing, and it `ref.invalidate`s this provider on commit. A
/// live-reactive roster is a Phase 4 concern (`watchRoster` stays for then).
/// `.autoDispose.family` also matches what the codegen default would produce.
final rosterProvider = FutureProvider.autoDispose.family<List<PlayerRow>, int>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).getRoster(gameId);
});
