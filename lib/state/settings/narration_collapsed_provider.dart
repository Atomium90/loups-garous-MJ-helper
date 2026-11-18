import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the MJ folded the narration block away. Kept for the whole session so that folding
/// it once, to give the grid of players its room back on a small phone, holds for every
/// following step; it is not saved, so the next launch starts with the lines open.
final narrationCollapsedProvider = NotifierProvider<NarrationCollapsed, bool>(
  NarrationCollapsed.new,
);

class NarrationCollapsed extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
