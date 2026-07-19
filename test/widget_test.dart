import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/app_widget.dart';
import 'package:weila/stores/theme_store.dart';

class _TestModule extends Module {
  @override
  void binds(Injector i) {
    i.addLazySingleton<ThemeStore>(ThemeStore.new);
  }

  @override
  void routes(RouteManager r) {
    r.child(
      '/',
      child: (_) => const Scaffold(body: Center(child: Text('薇拉'))),
    );
  }
}

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ModularApp(module: _TestModule(), child: const AppWidget()),
    );
    await tester.pump();
    expect(find.text('薇拉'), findsOneWidget);
  });
}
