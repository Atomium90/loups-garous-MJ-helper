import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary }

/// The app's one button widget (primary/secondary, both full-width, 8px radius per the design
/// handoff). Inert state is *derived* from [onPressed], not a separate flag: passing `null`
/// renders the README's "inert, not disabled-looking-broken" look (`bg/screen` fill,
/// `border/control` outline, `text/tertiary` label, no ripple) instead of Flutter's default
/// greyed-out disabled style. Callers that need an inert button with an explanatory label
/// ("Choisissez deux joueurs") just pass that as [label] and `onPressed: null`.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leadingIcon,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? leadingIcon;

  /// Smaller inline height (e.g. an accent-card CTA), instead of the standard
  /// primary/secondary height.
  final bool compact;

  bool get _isInert => onPressed == null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final Color fillColor;
    final Color borderColor;
    final Color labelColor;
    if (_isInert) {
      fillColor = colors.bgScreen;
      borderColor = colors.borderControl;
      labelColor = colors.textTertiary;
    } else if (variant == AppButtonVariant.primary) {
      fillColor = colors.accentBg;
      borderColor = colors.accentBorder;
      labelColor = colors.accentText;
    } else {
      fillColor = Colors.transparent;
      borderColor = colors.borderControl;
      labelColor = colors.textPrimary;
    }

    final height = compact
        ? 34.0
        : (variant == AppButtonVariant.primary
              ? AppSizes.buttonPrimaryHeight
              : AppSizes.buttonSecondaryHeight);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: fillColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.button),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 16, color: labelColor),
                const SizedBox(width: 6),
              ],
              Text(label, style: typography.rowLabel.copyWith(color: labelColor)),
            ],
          ),
        ),
      ),
    );
  }
}
