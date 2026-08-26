import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/theme/app_colors.dart';
import 'package:loup_garou_mj/ui/widgets/app_chip.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('unselected chip renders a plain hairline outline, no fill', (tester) async {
    await pumpApp(tester, AppChip(label: 'Voyante', selected: false, onTap: () {}));

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppChip), matching: find.byType(Material)),
    );
    expect(material.color, Colors.transparent);
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.light.borderHairline);
  });

  testWidgets('selected chip renders accent fill/border/text', (tester) async {
    await pumpApp(tester, AppChip(label: 'Voyante', selected: true, onTap: () {}));

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppChip), matching: find.byType(Material)),
    );
    expect(material.color, AppColors.light.accentBg);
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.light.accentBorder);

    final text = tester.widget<Text>(find.text('Voyante'));
    expect(text.style?.color, AppColors.light.accentText);
  });

  testWidgets('tapping a chip fires onTap with no arguments needed by the caller', (
    tester,
  ) async {
    var tapCount = 0;
    await pumpApp(
      tester,
      AppChip(label: 'Cupidon', selected: false, onTap: () => tapCount++),
    );

    await tester.tap(find.byType(AppChip));
    expect(tapCount, 1);
  });
}
