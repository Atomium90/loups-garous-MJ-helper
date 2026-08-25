import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import 'game_repository_provider.dart';

/// Manually written, not @riverpod codegen: riverpod_generator can't embed
/// Drift's generated `Game` type (defined via a `part` file) into its own
/// generated provider code (InvalidTypeException). Not a stylistic choice,
/// a workaround for that specific limitation.
///
/// No .autoDispose: kept alive like a keepAlive codegen provider (the home
/// screen is the landing screen, shouldn't reload on revisit).
final gameListProvider = StreamProvider<List<Game>>((ref) {
  return ref.watch(gameRepositoryProvider).watchGames();
});
