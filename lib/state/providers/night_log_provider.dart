import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import 'game_repository_provider.dart';

/// Hand-written (not codegen): returns Drift's generated `NightLogRow` type,
/// which riverpod_generator can't embed - same limitation as gameListProvider.
///
/// Newest first (the Journal is reverse-chronological). Reactive: the repo
/// re-emits after every appendNightLog.
final nightLogProvider = StreamProvider.autoDispose.family<List<NightLogRow>, int>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).watchNightLog(gameId);
});
