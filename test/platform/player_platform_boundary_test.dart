import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared player does not import window_manager', () {
    final source = File('lib/pages/player/player_page.dart').readAsStringSync();
    expect(source, isNot(contains('package:window_manager')));
    expect(source, isNot(contains('windowManager.')));
  });

  test('player gates every download entry behind capabilities', () {
    final page = File('lib/pages/player/player_page.dart').readAsStringSync();
    final view = File('lib/pages/player/widgets/player_page_view.dart')
        .readAsStringSync();
    expect(page, contains('widget.capabilities.downloads'));
    expect(view, contains('if (widget.capabilities.downloads)'));
  });
}
