import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/database/app_database.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../widgets/confirm_sheet.dart';
import '../../utils/l10n.dart';
import '../../utils/labels.dart';

/// Asks before deleting [game] (running or finished) with its roster and journal, which can't
/// be undone. Completes with true if the MJ confirmed and the game is gone.
Future<bool> showDeleteGameSheet(BuildContext context, WidgetRef ref, Game game) async {
  final name = gameTitle(context.l10n, game);
  final deleted = await showConfirmSheet(
    context,
    title: context.l10n.deleteGameTitle,
    message: context.l10n.deleteGameMessage(name),
    confirmLabel: context.l10n.deleteGameConfirm,
    onConfirm: () => ref.read(gameRepositoryProvider).deleteGame(game.id),
  );
  return deleted == true;
}
