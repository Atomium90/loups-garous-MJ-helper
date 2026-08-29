import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/theme/app_colors.dart';
import 'package:loup_garou_mj/ui/widgets/app_text_field.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('at rest: bg/inset fill, hairline border', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, AppTextField(controller: controller, hintText: 'Joueur 1'));

    final container = tester.widget<AnimatedContainer>(
      find.descendant(of: find.byType(AppTextField), matching: find.byType(AnimatedContainer)),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.light.bgInset);
    expect((decoration.border! as Border).top.color, AppColors.light.borderHairline);
  });

  testWidgets('focused: bg/screen fill, 1.5px accent border', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpApp(tester, AppTextField(controller: controller, hintText: 'Joueur 1'));

    await tester.tap(find.byType(AppTextField));
    await tester.pumpAndSettle();

    final container = tester.widget<AnimatedContainer>(
      find.descendant(of: find.byType(AppTextField), matching: find.byType(AnimatedContainer)),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.light.bgScreen);
    final border = decoration.border! as Border;
    expect(border.top.color, AppColors.light.accentBorder);
    expect(border.top.width, 1.5);
  });

  testWidgets('onChanged fires with the typed text', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? seen;
    await pumpApp(
      tester,
      AppTextField(controller: controller, onChanged: (v) => seen = v),
    );

    await tester.enterText(find.byType(TextField), 'Camille');
    expect(seen, 'Camille');
    expect(controller.text, 'Camille');
  });
}
