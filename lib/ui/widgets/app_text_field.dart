import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// The design handoff's text field (the name rows now; Réglages/Mes boîtes search later).
/// 38 high, 8 radius. At rest: `bg/inset` fill, hairline outline. Focused: `bg/screen` fill,
/// 1.5px `accent/border` (the border thickens by 1, so horizontal padding drops by 1 to keep
/// the text from shifting). Placeholder in `text/tertiary`.
///
/// A [StatefulWidget] (not a bare `TextField`) only to track focus for the *fill* swap -
/// Material's `InputDecoration` can swap the border on focus but not the fill colour.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    this.focusNode,
    this.hintText,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;

  /// Optional external node (e.g. a row that colours its index label by focus).
  /// When omitted, the field owns and disposes its own.
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownedNode;
  FocusNode get _focusNode => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownedNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final focused = _focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      height: AppSizes.buttonSecondaryHeight, // 38
      padding: EdgeInsets.symmetric(horizontal: focused ? 11 : 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: focused ? colors.bgScreen : colors.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: Border.all(
          color: focused ? colors.accentBorder : colors.borderHairline,
          width: focused ? 1.5 : 0.5,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        textInputAction: widget.textInputAction,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        cursorColor: colors.accentBorder,
        style: typography.rowLabel.copyWith(
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: widget.hintText,
          hintStyle: typography.rowLabel.copyWith(
            fontWeight: FontWeight.w400,
            color: colors.textTertiary,
          ),
        ),
      ),
    );
  }
}
