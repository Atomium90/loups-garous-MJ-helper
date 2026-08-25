import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import 'game_repository_provider.dart';

/// Manually written, not @riverpod codegen: see gameListProvider's comment,
/// same InvalidTypeException workaround for Drift's generated `Game` type.
///
/// .autoDispose: scoped to one composition-screen visit (matches what the
/// codegen default would have been).
final gameProvider = FutureProvider.autoDispose.family<Game?, int>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).getGame(gameId);
});
