import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/state/settings/settings_providers.dart';
import 'package:loup_garou_mj/ui/utils/narration.dart';
import 'package:loup_garou_mj/ui/widgets/narration_block.dart';
import 'package:material_ui/material_ui.dart' show Scaffold;
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_app.dart';

const _lines = [
  NarrationLine('Chasseur, tu es mort.', 'Emporte qui tu veux.'),
  NarrationLine('Rendors-toi.'),
];

const _hint = 'Tu peux limiter ou masquer ces phrases dans Réglages.';

void main() {
  /// Shows [blocks] narration blocks one under the other, with the given saved preferences,
  /// once the settings have loaded.
  Future<void> pumpBlocks(
    WidgetTester tester,
    Map<String, Object> saved, {
    int blocks = 1,
    List<NarrationLine> lines = _lines,
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    await pumpScreen(
      tester,
      Scaffold(
        body: Column(
          children: [for (var i = 0; i < blocks; i++) NarrationBlock(lines: lines)],
        ),
      ),
      overrides: [sharedPreferencesProvider.overrideWith((ref) async => prefs)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('full reads the heads and the bodies', (tester) async {
    await pumpBlocks(tester, {'narration_hint_seen': true});

    expect(find.text('À DIRE'), findsOneWidget);
    expect(find.text('Chasseur, tu es mort. Emporte qui tu veux.'), findsOneWidget);
    expect(find.text('Rendors-toi.'), findsOneWidget);
  });

  testWidgets('short reads only the heads', (tester) async {
    await pumpBlocks(tester, {'narration_level': 'short', 'narration_hint_seen': true});

    expect(find.text('Chasseur, tu es mort.'), findsOneWidget);
    expect(find.textContaining('Emporte'), findsNothing);
  });

  testWidgets('off shows nothing at all', (tester) async {
    await pumpBlocks(tester, {'narration_level': 'off'});

    expect(find.text('À DIRE'), findsNothing);
    expect(find.textContaining('Chasseur'), findsNothing);
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('the first block says the lines can be limited in Réglages, once', (tester) async {
    await pumpBlocks(tester, {});

    expect(find.text(_hint), findsOneWidget);
    // it stays while the block is on screen, but is already remembered as seen
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('narration_hint_seen'), isTrue);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(_hint), findsNothing);
    expect(find.text('À DIRE'), findsOneWidget);
  });

  testWidgets('a block shown after the hint was seen has no hint', (tester) async {
    await pumpBlocks(tester, {'narration_hint_seen': true});

    expect(find.text('OK'), findsNothing);
  });

  group('folding it away', () {
    testWidgets('keeps only the first line', (tester) async {
      await pumpBlocks(tester, {'narration_hint_seen': true});

      await tester.tap(find.text('À DIRE'));
      await tester.pumpAndSettle();

      expect(find.text('Rendors-toi.'), findsNothing);
      expect(find.text('Chasseur, tu es mort. Emporte qui tu veux.'), findsOneWidget);
    });

    testWidgets('holds for the next block, which is folded too', (tester) async {
      await pumpBlocks(tester, {'narration_hint_seen': true}, blocks: 2);

      await tester.tap(find.text('À DIRE').first);
      await tester.pumpAndSettle();

      expect(find.text('À DIRE'), findsNWidgets(2));
      expect(find.text('Rendors-toi.'), findsNothing);
    });

    testWidgets('and unfolding it brings the lines back', (tester) async {
      await pumpBlocks(tester, {'narration_hint_seen': true});

      await tester.tap(find.text('À DIRE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('À DIRE'));
      await tester.pumpAndSettle();

      expect(find.text('Rendors-toi.'), findsOneWidget);
    });
  });

  testWidgets('a long script scrolls instead of taking over the screen', (tester) async {
    await pumpBlocks(
      tester,
      {'narration_hint_seen': true},
      lines: [for (var i = 0; i < 12; i++) NarrationLine('Une phrase assez longue $i.')],
    );

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      tester.getSize(find.byType(NarrationBlock)).height,
      lessThanOrEqualTo(screen.height * 0.24),
    );
  });
}
