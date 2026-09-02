import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../state/roster/roster_editor_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/bientot_pill.dart';

/// "Les joueurs". Names the seats created (blank) when the composition was saved. The
/// game is still GameStatus.setup here; this only fills in names.
class PlayersScreen extends ConsumerWidget {
  const PlayersScreen({required this.gameId, super.key});

  final int gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftAsync = ref.watch(rosterEditorProvider(gameId));

    return Scaffold(
      body: SafeArea(
        child: draftAsync.when(
          data: (draft) => _PlayersForm(gameId: gameId, initialNames: draft.names),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Text(
                'Impossible de charger cette partie.',
                textAlign: TextAlign.center,
                style: context.typography.body.copyWith(color: context.colors.textSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayersForm extends ConsumerStatefulWidget {
  const _PlayersForm({required this.gameId, required this.initialNames});

  final int gameId;
  final List<String> initialNames;

  @override
  ConsumerState<_PlayersForm> createState() => _PlayersFormState();
}

class _PlayersFormState extends ConsumerState<_PlayersForm> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  RosterEditor get _notifier => ref.read(rosterEditorProvider(widget.gameId).notifier);

  @override
  void initState() {
    super.initState();
    // Seeded once from the first draft snapshot; the controllers own the text from here on,
    // the notifier owns the derived counts. A plain TextField(initialValue:) in a reactive
    // list would fight Riverpod rebuilds for the cursor position.
    _controllers = [
      for (final name in widget.initialNames) TextEditingController(text: name),
    ];
    _focusNodes = [for (var i = 0; i < widget.initialNames.length; i++) FocusNode()];
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _onContinue() async {
    // Capture the router before the await: commit() invalidates rosterProvider, which can
    // briefly rebuild this screen (see flutter_ui_gotchas #1).
    final router = GoRouter.of(context);
    await _notifier.commit();
    router.push('/games/${widget.gameId}/before-night');
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(rosterEditorProvider(widget.gameId)).value;
    final namedCount = draft?.namedCount ?? 0;
    final total = draft?.total ?? _controllers.length;
    final allNamed = draft?.allNamed ?? false;

    return Column(
      children: [
        _Header(namedCount: namedCount, total: total),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 14, AppSpacing.screen, 0),
            children: [
              for (var i = 0; i < _controllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _PlayerNameRow(
                    index: i,
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    isLast: i == _controllers.length - 1,
                    onChanged: (value) => _notifier.setName(i, value),
                  ),
                ),
              const _CarnetRow(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            16,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: AppButton(
            label: 'Continuer',
            onPressed: allNamed ? _onContinue : null,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.namedCount, required this.total});

  final int namedCount;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 24, AppSpacing.screen, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(AppIcons.back, size: 18, color: colors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            // Backing out of naming abandons the setup (the game stays GameStatus.setup and
            // just doesn't surface on Home - the accepted orphan tradeoff).
            onPressed: () => context.go('/'),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Les joueurs', style: typography.screenTitle.copyWith(color: colors.textPrimary)),
              Text(
                '$namedCount sur $total nommés',
                style: typography.meta.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerNameRow extends StatefulWidget {
  const _PlayerNameRow({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.isLast,
    required this.onChanged,
  });

  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLast;
  final ValueChanged<String> onChanged;

  @override
  State<_PlayerNameRow> createState() => _PlayerNameRowState();
}

class _PlayerNameRowState extends State<_PlayerNameRow> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final focused = widget.focusNode.hasFocus;

    return Row(
      children: [
        SizedBox(
          width: 14,
          child: Text(
            '${widget.index + 1}',
            textAlign: TextAlign.right,
            style: typography.counter.copyWith(
              color: focused ? colors.accentText : colors.textTertiary,
              fontWeight: focused ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppTextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            hintText: 'Joueur ${widget.index + 1}',
            textInputAction: widget.isLast ? TextInputAction.done : TextInputAction.next,
            onChanged: widget.onChanged,
          ),
        ),
      ],
    );
  }
}

/// The coming-soon "Carnet d'habitués" (regulars address book) - visible but inert, on
/// purpose (design handoff: an honest "bientôt" over a toggle that does nothing).
class _CarnetRow extends StatelessWidget {
  const _CarnetRow();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 12),
      child: Row(
        children: [
          Icon(AppIcons.regulars, size: 15, color: colors.textTertiary),
          const SizedBox(width: 8),
          Text(
            "Carnet d'habitués",
            style: context.typography.meta.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(width: 8),
          const BientotPill(),
        ],
      ),
    );
  }
}
