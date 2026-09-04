import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/theme/app_colors.dart';
import 'package:loup_garou_mj/ui/widgets/app_toggle.dart';

import '../../support/pump_app.dart';

Container _track(WidgetTester tester) => tester.widget<Container>(
  find.descendant(of: find.byType(AppToggle), matching: find.byType(Container)).first,
);

void main() {
  testWidgets('tapping flips the value through onChanged', (tester) async {
    bool? received;
    await pumpApp(tester, AppToggle(value: false, onChanged: (v) => received = v));

    await tester.tap(find.byType(AppToggle));
    expect(received, isTrue);
  });

  testWidgets('on drives the track to accent', (tester) async {
    await pumpApp(tester, AppToggle(value: true, onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(
      ((_track(tester).decoration) as BoxDecoration).color,
      AppColors.light.accentBorder,
    );
  });

  testWidgets('off drives the track to border/control', (tester) async {
    await pumpApp(tester, AppToggle(value: false, onChanged: (_) {}));
    await tester.pumpAndSettle();
    expect(
      ((_track(tester).decoration) as BoxDecoration).color,
      AppColors.light.borderControl,
    );
  });

  testWidgets('a null onChanged makes it inert', (tester) async {
    await pumpApp(tester, const AppToggle(value: true, onChanged: null));
    await tester.tap(find.byType(AppToggle)); // must not throw
  });
}
