import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../state/providers/game_repository_provider.dart';
import '../../../state/providers/share_provider.dart';
import '../../utils/journal_export.dart';
import '../../utils/l10n.dart';
import '../../utils/labels.dart';

/// Shares the journal of [game] as text through the system share sheet.
Future<void> shareJournal(BuildContext context, WidgetRef ref, Game game) async {
  final l10n = context.l10n;
  final rows = await ref.read(gameRepositoryProvider).getNightLog(game.id);
  await ref.read(textSharerProvider)(
    text: journalAsText(l10n, game, rows),
    subject: gameTitle(l10n, game),
  );
}
