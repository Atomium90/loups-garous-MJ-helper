import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/theme/app_theme.dart';

/// Wraps [child] in a minimal `MaterialApp`/`Scaffold` carrying [AppTheme.light], so widgets
/// that read `context.colors`/`context.typography` (every widget under `lib/ui/`) resolve
/// without each test re-declaring the same boilerplate.
Future<void> pumpApp(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
  );
}
