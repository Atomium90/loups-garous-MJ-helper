import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../home/unreadable_game_sheet.dart';

/// What a game tab shows when the saved game can't be loaded: the [message], and a way out
/// by deleting the game (with its confirmation sheet), after which the MJ lands back on Home.
class UnreadableGameNotice extends ConsumerWidget {
  const UnreadableGameNotice({required this.gameId, required this.message, super.key});

  final int gameId;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.typography.body.copyWith(color: context.colors.textSecondary),
            ),
            AppButton(
              label: 'Supprimer cette partie',
              variant: AppButtonVariant.secondary,
              onPressed: () => showUnreadableGameSheet(
                context,
                ref,
                gameId: gameId,
                onDeleted: () => router.go('/'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
