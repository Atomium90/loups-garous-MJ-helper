import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

typedef SegmentOption<T> = ({T value, IconData icon, String label});

/// A pill-track segmented control (the Apparence control in Réglages): an
/// inset track, the selected segment lifted onto `bg/screen` with a hairline.
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        spacing: 6,
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option.value),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: option.value == selected ? colors.bgScreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.button - 1),
                    border: Border.all(
                      color: option.value == selected
                          ? colors.borderHairline
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 5,
                    children: [
                      Icon(
                        option.icon,
                        size: 14,
                        color: option.value == selected
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                      Text(
                        option.label,
                        style: typography.chipLabel.copyWith(
                          color: option.value == selected
                              ? colors.textPrimary
                              : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
