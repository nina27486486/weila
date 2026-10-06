import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/platform/app_capabilities.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/vira_page_chrome.dart';

Widget _app(AppCapabilities capabilities) {
  return AppCapabilitiesScope(
    capabilities: capabilities,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: ViraPageScaffold(
        activeDestination: ViraDestination.home,
        onDestinationSelected: (_) {},
        onSearch: () {},
        onThemeToggle: () {},
        onProfile: () {},
        child: const SizedBox(),
      ),
    ),
  );
}

void main() {
  testWidgets('Android baseline hides download navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(AppCapabilities.androidCompileBaseline));
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('下载'), findsNothing);
  });

  testWidgets('Windows retains download navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(AppCapabilities.windows));
    expect(find.text('下载'), findsOneWidget);
  });
}
