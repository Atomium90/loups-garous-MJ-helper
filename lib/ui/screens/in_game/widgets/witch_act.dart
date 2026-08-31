import 'package:flutter/material.dart';
import 'package:rules_engine/rules_engine.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_icons.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/player_avatar.dart';
import 'target_pick.dart';

/// The Witch's turn: two one-shot potions. She can save the wolves' victim
/// (life) and/or kill someone (death), then she's done. Each potion is a
/// separate GameSession.applyAction that leaves the cursor put; "Terminer"
/// advances.
class WitchAct extends StatefulWidget {
  const WitchAct({
    required this.witch,
    required this.wolfVictim,
    required this.candidates,
    required this.onSave,
    required this.onPoison,
    required this.onDone,
    super.key,
  });

  final WitchState witch;

  /// The wolves' pending victim, if any and not already saved.
  final Candidate? wolfVictim;

  /// Alive players she could poison.
  final List<Candidate> candidates;

  final VoidCallback onSave;
  final ValueChanged<String> onPoison;
  final VoidCallback onDone;

  @override
  State<WitchAct> createState() => _WitchActState();
}

class _WitchActState extends State<WitchAct> {
  bool _poisoning = false;

  @override
  Widget build(BuildContext context) {
    if (_poisoning) {
      return TargetPick(
        question: 'Qui la Sorcière empoisonne-t-elle ?',
        candidates: widget.candidates,
        confirmLabel: (name) => 'Elle empoisonne $name',
        onConfirm: (id) {
          // back to the potion view (now showing "Mort utilisée" + Terminer)
          setState(() => _poisoning = false);
          widget.onPoison(id);
        },
        secondaryLabel: 'Annuler',
        onSecondary: () => setState(() => _poisoning = false),
      );
    }

    final colors = context.colors;
    final canSave = !widget.witch.lifePotionUsed && widget.wolfVictim != null;
    final canPoison = !widget.witch.deathPotionUsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 14, AppSpacing.screen, 0),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PotionPill(label: 'Vie', used: widget.witch.lifePotionUsed),
              _PotionPill(label: 'Mort', used: widget.witch.deathPotionUsed),
            ],
          ),
        ),
        if (widget.wolfVictim case final victim?)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 16, AppSpacing.screen, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Victime des Loups cette nuit',
                  style: context.typography.meta.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: colors.warnBg,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Row(
                    spacing: 10,
                    children: [
                      PlayerAvatar(name: victim.name, fillColor: colors.bgScreen),
                      Expanded(
                        child: Text(
                          victim.name,
                          style: context.typography.rowLabel.copyWith(color: colors.textPrimary),
                        ),
                      ),
                      Icon(AppIcons.skull, size: 16, color: colors.warnText),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            16,
            AppSpacing.screen,
            AppSpacing.screen,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              if (canSave)
                AppButton(
                  label: 'Elle sauve ${widget.wolfVictim!.name}',
                  leadingIcon: AppIcons.witchSave,
                  onPressed: widget.onSave,
                ),
              if (canPoison)
                AppButton(
                  label: 'Elle empoisonne…',
                  variant: canSave ? AppButtonVariant.secondary : AppButtonVariant.primary,
                  onPressed: () => setState(() => _poisoning = true),
                ),
              AppButton(
                label: 'Terminer le tour de la Sorcière',
                variant: AppButtonVariant.secondary,
                onPressed: widget.onDone,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PotionPill extends StatelessWidget {
  const _PotionPill({required this.label, required this.used});

  final String label;
  final bool used;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: used ? Colors.transparent : colors.successBg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: used ? Border.all(color: colors.borderHairline) : null,
      ),
      child: Text(
        used ? '$label utilisée' : '$label disponible',
        style: context.typography.counter.copyWith(
          color: used ? colors.textTertiary : colors.successText,
          decoration: used ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
