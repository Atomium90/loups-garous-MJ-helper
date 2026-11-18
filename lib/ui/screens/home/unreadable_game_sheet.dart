import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../state/providers/game_repository_provider.dart';
import '../../utils/l10n.dart';
import '../../widgets/confirm_sheet.dart';

/// Offered when a saved game can't be read back (its data is damaged, or comes from a version
/// of the app this one doesn't understand). The only useful move is to remove it, so the sheet
/// asks for confirmation and deletes the game with its roster and journal; other games are
/// untouched. [onDeleted] runs once the game is gone, e.g. to leave a screen that showed it.
Future<void> showUnreadableGameSheet(
  BuildContext context,
  WidgetRef ref, {
  required int gameId,
  VoidCallback? onDeleted,
}) async {
  final deleted = await showConfirmSheet(
    context,
    title: context.l10n.unreadableGameTitle,
    message: context.l10n.unreadableGameMessage,
    confirmLabel: context.l10n.deleteGameConfirm,
    onConfirm: () => ref.read(gameRepositoryProvider).deleteGame(gameId),
  );
  if (deleted == true) onDeleted?.call();
}
