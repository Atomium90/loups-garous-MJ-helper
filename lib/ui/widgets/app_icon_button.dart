import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// A circular icon button (`border/control` outline, 36px by default / 30px in dense headers).
/// [onTap] left `null` renders a normal-looking (not inert-styled) button that simply doesn't
/// respond - used for header actions that route to a screen not built yet (see call sites'
/// `// TODO` comments), rather than the button-inert visual language, which is reserved for
/// "this primary action needs more input first," not "not implemented yet."
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    this.onTap,
    this.size = AppSizes.iconButton,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

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
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(child: Icon(icon, size: 18, color: colors.textSecondary)),
        ),
      ),
    );
  }
}
