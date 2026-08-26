import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// An uppercase section header ("EN COURS", "HISTORIQUE"), `text/tertiary`.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.typography.sectionLabel.copyWith(color: context.colors.textTertiary),
    );
  }
}
