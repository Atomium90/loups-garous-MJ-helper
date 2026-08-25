import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/repositories/drift_game_repository.dart';
import '../../data/repositories/game_repository.dart';
import 'database_provider.dart';

part 'game_repository_provider.g.dart';

@Riverpod(keepAlive: true)
GameRepository gameRepository(Ref ref) => DriftGameRepository(ref.watch(appDatabaseProvider));
