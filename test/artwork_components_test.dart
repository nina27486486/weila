import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/artwork_palette_service.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/artwork_components.dart';

Widget _app(Widget child, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  final items = List.generate(
    5,
    (index) => ArtworkStackItem(
      id: 'item:$index',
      title: '故事 ${index + 1}',
      subtitle: '看到第 ${index + 2} 集',
      imageUrl: null,
      progress: 0.5,
    ),
  );

  testWidgets('层叠卡片支持键盘翻组并保留全部条目', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 900,
          child: LayeredArtworkStack(
            items: items,
            onOpen: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('故事 1'), findsOneWidget);
    expect(find.text('故事 4'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('layered-artwork-stack')));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('故事 4'), findsOneWidget);
    expect(find.text('故事 1'), findsNothing);
  });

  testWidgets('展开式工具栏在悬停时显示标签并触发选择', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _app(
        ExpandableToolTabs(
          items: const [
            ExpandableToolTab(
              id: 'episodes',
              icon: Icons.list_rounded,
              label: '选集',
              tooltip: '打开选集',
            ),
          ],
          onSelected: (value) => selected = value,
        ),
      ),
    );

    expect(find.text('选集'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byTooltip('打开选集')));
    await tester.pumpAndSettle();
    expect(find.text('选集'), findsOneWidget);

    await tester.tap(find.byTooltip('打开选集'));
    expect(selected, 'episodes');
  });

  testWidgets('海报轨道支持鼠标滚轮横向浏览全部条目', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 520,
          child: PosterRail(
            items: List.generate(
              10,
              (index) => PosterRailItem(
                id: '$index',
                title: '海报 ${index + 1}',
                imageUrl: null,
              ),
            ),
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final scrollable = find.descendant(
      of: find.byType(PosterRail),
      matching: find.byType(Scrollable),
    );
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(PosterRail)),
        scrollDelta: const Offset(0, 280),
      ),
    );
    await tester.pump();
    final after = tester.state<ScrollableState>(scrollable).position.pixels;

    expect(before, 0);
    expect(after, greaterThan(0));
  });

  testWidgets('海报轨道使用柔光卡片并支持键盘打开', (tester) async {
    String? openedId;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 520,
          child: PosterRail(
            items: const [
              PosterRailItem(
                id: 'season-1',
                title: '第一季',
                imageUrl: null,
              ),
            ],
            onOpen: (item) => openedId = item.id,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('poster-card-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('poster-cover-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('poster-rank-pill-0')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.byKey(const ValueKey('poster-focus-ring-0')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(openedId, 'season-1');
  });

  testWidgets('环境背景在减少动态效果时仍能稳定呈现内容', (tester) async {
    await tester.pumpWidget(
      _app(
        const SizedBox(
          width: 600,
          height: 300,
          child: AmbientArtworkBackdrop(
            palette: ArtworkPalette.fallback,
            child: Text('正文内容'),
          ),
        ),
        disableAnimations: true,
      ),
    );

    expect(find.text('正文内容'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ambient-artwork-static')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('海报视差随指针移动且在减少动态效果时保持静止', (tester) async {
    Future<Matrix4?> renderAndHover({required bool reduceMotion}) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 300,
            height: 200,
            child: ArtworkParallax(child: ColoredBox(color: Colors.blue)),
          ),
          disableAnimations: reduceMotion,
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getTopLeft(find.byType(ArtworkParallax)) + const Offset(280, 20),
      );
      await tester.pump(const Duration(milliseconds: 240));
      final transform = tester.widget<AnimatedContainer>(
        find.byKey(const ValueKey('artwork-parallax-transform')),
      );
      await mouse.removePointer();
      return transform.transform;
    }

    final active = await renderAndHover(reduceMotion: false);
    final reduced = await renderAndHover(reduceMotion: true);

    expect(active, isNot(equals(Matrix4.identity())));
    expect(reduced, equals(Matrix4.identity()));
  });

  testWidgets('封面取色构建器忽略已过期的异步结果', (tester) async {
    final first = Completer<Uint8List>();
    final second = Completer<Uint8List>();
    final service = ArtworkPaletteService(
      pixelLoader: (provider) {
        final bytes = (provider as MemoryImage).bytes;
        return bytes.first == 1 ? first.future : second.future;
      },
    );

    Widget build(String key, int marker) {
      return _app(
        ArtworkPaletteBuilder(
          cacheKey: key,
          provider: MemoryImage(Uint8List.fromList([marker])),
          service: service,
          builder: (context, palette) => Text(
            palette.primary.toARGB32().toRadixString(16),
          ),
        ),
      );
    }

    await tester.pumpWidget(build('first', 1));
    await tester.pumpWidget(build('second', 2));

    second.complete(Uint8List.fromList([
      76,
      159,
      216,
      255,
      76,
      159,
      216,
      255,
    ]));
    await tester.pump();
    await tester.pump();

    first.complete(Uint8List.fromList([
      230,
      111,
      134,
      255,
      230,
      111,
      134,
      255,
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.text(const Color(0xFF4C9FD8).toARGB32().toRadixString(16)),
        findsOneWidget);
  });
}
