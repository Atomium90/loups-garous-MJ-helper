import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import 'game_repository_provider.dart';

/// Manually written, not @riverpod codegen: see gameListProvider's comment,
/// same InvalidTypeException workaround for Drift's generated `PlayerRow` type
/// (riverpod_generator can't embed a type defined via a `part` file).
///
/// A one-shot `FutureProvider` (over `getRoster`), mirroring [gameProvider],
/// not a `StreamProvider` over the repository's `watchRoster`: the naming and pre-night
/// screens only need a fresh snapshot per visit, [RosterEditor] holds the live
/// draft while editing, and it `ref.invalidate`s this provider on commit. A
/// live-reactive roster only matters once a game is running (`watchRoster`
/// stays for then). `.autoDispose.family` also matches the codegen default.
final rosterProvider = FutureProvider.autoDispose.family<List<PlayerRow>, int>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).getRoster(gameId);
});
