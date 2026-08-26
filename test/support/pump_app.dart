import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (used in pumpScreen's signature) isn't in flutter_riverpod.dart's own export
// list - it's only exposed via this secondary barrel.
import 'package:flutter_riverpod/misc.dart';
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

/// [pumpApp], plus a [ProviderScope] with [overrides] - for a screen that reads Riverpod
/// providers directly (as opposed to a plain component test, which never needs Riverpod at
/// all). No `Scaffold` wrapper here: a screen builds its own.
Future<void> pumpScreen(WidgetTester tester, Widget child, {List<Override> overrides = const []}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
}
