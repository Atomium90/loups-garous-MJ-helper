import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// A `−`/value/`+` control (the composition screen's player-count row, and the per-role counts on roles that can
/// exceed 1). [onChanged] receives the already-clamped new value; the +/- buttons disable
/// themselves (dim to `text/tertiary`, no tap) at [min]/[max] rather than calling out of range.
class AppStepper extends StatelessWidget {
  const AppStepper({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.buttonSize = 28,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;
  final double buttonSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final canDecrement = value > min;
    final canIncrement = max == null || value < max!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          symbol: '−',
          size: buttonSize,
          enabled: canDecrement,
          onTap: () => onChanged(value - 1),
        ),
        const SizedBox(width: 14),
        ConstrainedBox(
          // The mockup's `min-width: 16px` is a *minimum*, not a fixed width - it keeps a
          // single digit centred without letting a two-digit value (e.g. 10 to 18 players)
          // wrap onto a second line, which a SizedBox(width: 16) would force.
          constraints: const BoxConstraints(minWidth: 16),
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            softWrap: false,
            style: typography.stepperValue.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(width: 14),
        _StepperButton(
          symbol: '+',
          size: buttonSize,
          enabled: canIncrement,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.symbol,
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  final String symbol;
  final double size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        shape: CircleBorder(side: BorderSide(color: colors.borderControl)),
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Center(
            child: Text(
              symbol,
              style: TextStyle(
                fontSize: 15,
                color: enabled ? colors.textPrimary : colors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
