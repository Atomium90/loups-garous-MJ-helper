import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/theme/app_colors.dart';
import 'package:loup_garou_mj/ui/widgets/app_button.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('active primary button renders accent styling and fires onPressed', (
    tester,
  ) async {
    var tapped = false;
    await pumpApp(
      tester,
      AppButton(label: 'Nouvelle partie', onPressed: () => tapped = true),
    );

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppButton), matching: find.byType(Material)),
    );
    expect(material.color, AppColors.light.accentBg);

    await tester.tap(find.text('Nouvelle partie'));
    expect(tapped, isTrue);
  });

  testWidgets('inert button (onPressed: null) renders the inert look and never fires', (
    tester,
  ) async {
    await pumpApp(tester, const AppButton(label: 'Choisissez deux joueurs', onPressed: null));

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppButton), matching: find.byType(Material)),
    );
    expect(material.color, AppColors.light.bgScreen);

    final text = tester.widget<Text>(find.text('Choisissez deux joueurs'));
    expect(text.style?.color, AppColors.light.textTertiary);

    // No callback is wired at all, so there's nothing to assert *not* firing beyond the
    // widget tree itself carrying no tap handler.
    final inkWell = tester.widget<InkWell>(
      find.descendant(of: find.byType(AppButton), matching: find.byType(InkWell)),
    );
    expect(inkWell.onTap, isNull);
  });

  testWidgets('secondary variant renders border/control outline, not accent', (tester) async {
    await pumpApp(
      tester,
      AppButton(
        label: 'Annuler',
        variant: AppButtonVariant.secondary,
        onPressed: () {},
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppButton), matching: find.byType(Material)),
    );
    expect(material.color, Colors.transparent);
    final shape = material.shape as RoundedRectangleBorder;
    expect(shape.side.color, AppColors.light.borderControl);
  });
}
