import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/database/app_database.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../utils/french_date_format.dart';
import '../../widgets/confirm_sheet.dart';

/// Asks before deleting [game] (running or finished) with its roster and journal, which can't
/// be undone. Completes with true if the MJ confirmed and the game is gone.
Future<bool> showDeleteGameSheet(BuildContext context, WidgetRef ref, Game game) async {
  final name = game.name ?? 'Partie du ${frenchDayMonthLabel(game.createdAt)}';
  final deleted = await showConfirmSheet(
    context,
    title: 'Supprimer cette partie ?',
    message: '« $name » sera supprimée avec son journal. Cette action est définitive.',
    confirmLabel: 'Supprimer cette partie',
    onConfirm: () => ref.read(gameRepositoryProvider).deleteGame(game.id),
  );
  return deleted == true;
}
