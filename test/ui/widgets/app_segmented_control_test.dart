import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loup_garou_mj/ui/widgets/app_segmented_control.dart';

import '../../support/pump_app.dart';

void main() {
  const options = <SegmentOption<String>>[
    (value: 'a', icon: Icons.circle, label: 'Un'),
    (value: 'b', icon: Icons.square, label: 'Deux'),
    (value: 'c', icon: Icons.star, label: 'Trois'),
  ];

  testWidgets('renders every option and reports a tap', (tester) async {
    String? picked;
    await pumpApp(
      tester,
      AppSegmentedControl<String>(
        options: options,
        selected: 'a',
        onChanged: (v) => picked = v,
      ),
    );

    expect(find.text('Un'), findsOneWidget);
    expect(find.text('Deux'), findsOneWidget);
    expect(find.text('Trois'), findsOneWidget);

    await tester.tap(find.text('Trois'));
    expect(picked, 'c');
  });
}
