import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/widgets/app_stepper.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('tapping + calls onChanged with value + 1', (tester) async {
    int? newValue;
    await pumpApp(
      tester,
      AppStepper(value: 8, onChanged: (v) => newValue = v, min: 8, max: 18),
    );

    await tester.tap(find.text('+'));
    expect(newValue, 9);
  });

  testWidgets('tapping − calls onChanged with value − 1', (tester) async {
    int? newValue;
    await pumpApp(
      tester,
      AppStepper(value: 10, onChanged: (v) => newValue = v, min: 8, max: 18),
    );

    await tester.tap(find.text('−'));
    expect(newValue, 9);
  });

  testWidgets('− is inert at min: no tap fires onChanged', (tester) async {
    var called = false;
    await pumpApp(
      tester,
      AppStepper(value: 8, onChanged: (_) => called = true, min: 8, max: 18),
    );

    await tester.tap(find.text('−'));
    expect(called, isFalse);
  });

  testWidgets('+ is inert at max: no tap fires onChanged', (tester) async {
    var called = false;
    await pumpApp(
      tester,
      AppStepper(value: 18, onChanged: (_) => called = true, min: 8, max: 18),
    );

    await tester.tap(find.text('+'));
    expect(called, isFalse);
  });

  testWidgets('no max means + is always enabled', (tester) async {
    int? newValue;
    await pumpApp(tester, AppStepper(value: 999, onChanged: (v) => newValue = v));

    await tester.tap(find.text('+'));
    expect(newValue, 1000);
  });
}
