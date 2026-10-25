import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/widgets/mobile/player_back_scope.dart';

void main() {
  testWidgets(
      'Android back closes panel then drawer then fullscreen then route',
      (tester) async {
    final state = await _openPlayer(tester);
    state.currentState!.setLayers(panel: true, drawer: true, fullscreen: true);
    await tester.pump();
    for (final expected in ['panel', 'drawer', 'fullscreen']) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('player'), findsOneWidget);
      expect(state.currentState!.events.last, expected);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('details'), findsOneWidget);
    expect(find.text('player'), findsNothing);
  });

  testWidgets('inline back uses the same fullscreen exit before leaving',
      (tester) async {
    final state = await _openPlayer(tester);
    state.currentState!.setLayers(fullscreen: true);
    await tester.pump();
    await tester.tap(find.text('inline back'));
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
    expect(state.currentState!.events, ['fullscreen']);
    await tester.tap(find.text('inline back'));
    await tester.pumpAndSettle();
    expect(find.text('player'), findsNothing);
  });

  testWidgets('two back requests before rebuilding cannot reenter fullscreen',
      (tester) async {
    final state = await _openPlayer(tester);
    state.currentState!.setLayers(fullscreen: true);
    await tester.pump();
    await Future.wait([
      tester.binding.handlePopRoute(),
      tester.binding.handlePopRoute(),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('player'), findsOneWidget);
    expect(state.currentState!.fullscreen, isFalse);
  });

  testWidgets('a popup route is dismissed before changing fullscreen',
      (tester) async {
    final state = await _openPlayer(tester);
    state.currentState!.setLayers(fullscreen: true);
    await tester.pump();
    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('menu'), findsNothing);
    expect(state.currentState!.events, isEmpty);
    expect(state.currentState!.fullscreen, isTrue);
  });

  testWidgets('normal Android back leaves immediately without transient UI',
      (tester) async {
    await _openPlayer(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('player'), findsNothing);
  });

  testWidgets('Windows inline back keeps its original callback',
      (tester) async {
    final state = await _openPlayer(tester, platform: TargetPlatform.windows);
    state.currentState!.setLayers(panel: true, drawer: true, fullscreen: true);
    await tester.pump();
    await tester.tap(find.text('inline back'));
    await tester.pumpAndSettle();
    expect(find.text('player'), findsNothing);
  });

  testWidgets('Windows system navigation is not intercepted', (tester) async {
    final state = await _openPlayer(tester, platform: TargetPlatform.windows);
    state.currentState!.setLayers(panel: true, drawer: true, fullscreen: true);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('player'), findsNothing);
  });
}

Future<GlobalKey<_PlayerHostState>> _openPlayer(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
}) async {
  final state = GlobalKey<_PlayerHostState>();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: platform),
    home: Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('details'),
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => _PlayerHost(key: state),
                )),
              ),
            )),
  ));
  await tester.tap(find.text('details'));
  await tester.pumpAndSettle();
  return state;
}

class _PlayerHost extends StatefulWidget {
  const _PlayerHost({super.key});

  @override
  State<_PlayerHost> createState() => _PlayerHostState();
}

class _PlayerHostState extends State<_PlayerHost> {
  bool panel = false;
  bool drawer = false;
  bool fullscreen = false;
  final events = <String>[];

  void setLayers(
      {bool panel = false, bool drawer = false, bool fullscreen = false}) {
    setState(() {
      this.panel = panel;
      this.drawer = drawer;
      this.fullscreen = fullscreen;
    });
  }

  @override
  Widget build(BuildContext context) => _guard(
        child: Scaffold(
            body: Column(children: [
          const Text('player'),
          TextButton(
            onPressed: () => PlayerBackScope.requestBack(
              context,
              onDesktopBack: () => Navigator.of(context).pop(),
            ),
            child: const Text('inline back'),
          ),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(content: Text('menu')),
            ),
            child: const Text('open menu'),
          ),
        ])),
      );

  Widget _guard({required Widget child}) => PlayerBackScope(
        fullscreen: fullscreen,
        hasOpenPanel: panel,
        hasOpenDrawer: drawer,
        onClosePanel: () => setState(() {
          events.add('panel');
          panel = false;
        }),
        onCloseDrawer: () => setState(() {
          events.add('drawer');
          drawer = false;
        }),
        onExitFullscreen: () => setState(() {
          events.add('fullscreen');
          fullscreen = false;
        }),
        child: child,
      );
}
