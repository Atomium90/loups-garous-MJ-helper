import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../state/providers/game_repository_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_sheet.dart';

/// Offered when a saved game can't be read back (its data is damaged, or comes from a version
/// of the app this one doesn't understand). The only useful move is to remove it, so the sheet
/// asks for confirmation and deletes the game with its roster and journal; other games are
/// untouched. [onDeleted] runs once the game is gone, e.g. to leave a screen that showed it.
Future<void> showUnreadableGameSheet(
  BuildContext context, {
  required int gameId,
  VoidCallback? onDeleted,
}) {
  return showAppSheet<void>(
    context,
    builder: (_) => _UnreadableGameSheet(gameId: gameId, onDeleted: onDeleted),
  );
}

class _UnreadableGameSheet extends ConsumerWidget {
  const _UnreadableGameSheet({required this.gameId, this.onDeleted});

  final int gameId;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 12, AppSpacing.screen, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(
              'Partie illisible',
              style: typography.rowLabel.copyWith(fontSize: 17, color: colors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              "Les données de cette partie sont abîmées, ou viennent d'une version de "
              "l'app que celle-ci ne comprend pas. Vous pouvez la supprimer : vos autres "
              'parties ne sont pas touchées.',
              style: typography.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Supprimer cette partie',
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref.read(gameRepositoryProvider).deleteGame(gameId);
                navigator.pop();
                onDeleted?.call();
              },
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'Annuler',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
