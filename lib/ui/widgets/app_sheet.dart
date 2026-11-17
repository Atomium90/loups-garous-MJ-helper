import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// The app's bottom sheet: screen background, rounded top corners, grows with its content.
/// Every full sheet goes through here so they look and behave the same.
Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: context.colors.bgScreen,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheetTop)),
    ),
    builder: builder,
  );
}

/// The small grab bar at the top of a sheet, centered, with [bottomGap] below it.
class SheetHandle extends StatelessWidget {
  const SheetHandle({this.bottomGap = 14, super.key});

  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(bottom: bottomGap),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.colors.borderHairline,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    );
  }
}
