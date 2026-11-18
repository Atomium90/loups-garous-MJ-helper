import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../state/settings/narration_collapsed_provider.dart';
import '../../state/settings/settings.dart';
import '../../state/settings/settings_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../utils/l10n.dart';
import '../utils/narration.dart';

/// The share of the screen's height the lines may take at most. Beyond it they scroll, so
/// the grid of players or the buttons below them are never squeezed out on a small phone.
const _maxHeightFraction = 0.24;

/// "À dire": the lines the MJ reads aloud at this moment, in the level chosen in Réglages
/// (nothing at all when it is off). The first time any is shown, a hint under them says the
/// level can be changed in Réglages; it is shown once and not again.
class NarrationBlock extends ConsumerStatefulWidget {
  const NarrationBlock({required this.lines, super.key});

  final List<NarrationLine> lines;

  @override
  ConsumerState<NarrationBlock> createState() => _NarrationBlockState();
}

class _NarrationBlockState extends ConsumerState<NarrationBlock> {
  /// Whether this block shows the hint: decided once, when the settings are first known, so
  /// the hint stays up while this block is on screen even though it is marked as seen right
  /// away.
  var _hintDecided = false;
  var _showHint = false;
  var _hintClosed = false;

  void _decideHint(AppSettings settings) {
    if (_hintDecided) return;
    _hintDecided = true;
    _showHint = !settings.narrationHintSeen;
    if (_showHint) {
      // After this frame: a provider must not change while the tree is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(settingsProvider.notifier).dismissNarrationHint();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    if (settings != null && settings.narrationLevel != NarrationLevel.off) {
      _decideHint(settings);
    }
    final level = settings?.narrationLevel ?? NarrationLevel.defaults;
    final texts = [
      for (final line in widget.lines)
        if (line.textAt(level).isNotEmpty) line.textAt(level),
    ];
    if (texts.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final collapsed = ref.watch(narrationCollapsedProvider);
    final toggle = ref.read(narrationCollapsedProvider.notifier).toggle;

    if (collapsed) {
      // Just the label and the first line, to give the screen its room back.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.accentBg,
            borderRadius: BorderRadius.circular(AppRadii.cardSmall),
          ),
          child: Row(
            spacing: 10,
            children: [
              Text(
                context.l10n.narrLabel.toUpperCase(),
                style: typography.sectionLabel.copyWith(color: colors.accentText),
              ),
              Expanded(
                child: Text(
                  texts.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.meta.copyWith(
                    color: colors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Icon(Icons.expand_more, size: 18, color: colors.accentText),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _maxHeightFraction,
      ),
      decoration: BoxDecoration(
        color: colors.accentBg,
        borderRadius: BorderRadius.circular(AppRadii.cardSmall),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: toggle,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.narrLabel.toUpperCase(),
                      style: typography.sectionLabel.copyWith(color: colors.accentText),
                    ),
                  ),
                  Icon(Icons.expand_less, size: 18, color: colors.accentText),
                ],
              ),
            ),
            for (final text in texts)
              Text(
                text,
                style: typography.body.copyWith(
                  color: colors.textPrimary,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
            if (_showHint && !_hintClosed)
              _Hint(onClose: () => setState(() => _hintClosed = true)),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.accentBorder)),
      ),
      child: Row(
        spacing: 10,
        children: [
          Expanded(
            child: Text(
              context.l10n.narrHint,
              style: typography.counter.copyWith(color: colors.textSecondary, height: 1.4),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/settings'),
            child: Text(
              context.l10n.settingsTitle,
              style: typography.chipLabel.copyWith(color: colors.accentText),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Text(
              context.l10n.commonOk,
              style: typography.chipLabel.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
