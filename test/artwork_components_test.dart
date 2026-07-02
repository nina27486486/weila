import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/artwork_palette_service.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/utils/animations.dart';
import 'package:weila/widgets/artwork_components.dart';

Widget _app(
  Widget child, {
  bool disableAnimations = false,
  bool darkMode = false,
}) {
  return MaterialApp(
    theme: darkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

Widget _sharedSurface({
  required VoidCallback onOpen,
  Widget? foreground,
  ValueChanged<ArtworkCardInteraction>? onInteraction,
}) {
  return SizedBox(
    width: 188,
    height: 280,
    child: ArtworkCardSurface(
      id: 'shared',
      semanticLabel: 'Shared artwork',
      onOpen: onOpen,
      foreground: foreground,
      contentBuilder: (context, interaction) {
        onInteraction?.call(interaction);
        return AnimatedScale(
          key: const ValueKey('shared-cover-scale'),
          duration: interaction.duration,
          scale: interaction.coverScale,
          child: const ColoredBox(color: Colors.blue),
        );
      },
    ),
  );
}

void main() {
  testWidgets('shared artwork surface activates on hover and focus',
      (tester) async {
    ArtworkCardInteraction? interaction;
    await tester.pumpWidget(
      _app(
        _sharedSurface(
          onOpen: () {},
          onInteraction: (value) => interaction = value,
        ),
      ),
    );

    expect(interaction?.active, isFalse);
    expect(interaction?.motionEnabled, isTrue);
    expect(interaction?.coverScale, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('artwork-card-shared')),
      ),
    );
    await tester.pump();

    expect(interaction?.active, isTrue);
    expect(interaction?.coverScale, 1.025);

    await mouse.moveTo(Offset.zero);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(interaction?.active, isTrue);
    expect(
      find.byKey(const ValueKey('artwork-card-focus-shared')),
      findsOneWidget,
    );
  });

  testWidgets('shared artwork surface opens by click enter and space',
      (tester) async {
    var openCount = 0;
    await tester.pumpWidget(
      _app(_sharedSurface(onOpen: () => openCount += 1)),
    );

    await tester.tap(
      find.byKey(const ValueKey('artwork-card-action-shared')),
    );
    expect(openCount, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(openCount, 3);
  });

  testWidgets('shared artwork surface disables motion with reduced motion',
      (tester) async {
    ArtworkCardInteraction? interaction;
    await tester.pumpWidget(
      _app(
        _sharedSurface(
          onOpen: () {},
          onInteraction: (value) => interaction = value,
        ),
        disableAnimations: true,
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('artwork-card-shared')),
      ),
    );
    await tester.pump();

    final card = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('artwork-card-shared')),
    );
    expect(card.duration, Duration.zero);
    expect(card.transform?.getTranslation().y, 0);
    expect(interaction?.active, isTrue);
    expect(interaction?.motionEnabled, isFalse);
    expect(interaction?.duration, Duration.zero);
    expect(interaction?.coverScale, 1);
  });

  testWidgets('shared artwork surface exposes one complete button semantic',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(_sharedSurface(onOpen: () {})),
    );

    final button = find.bySemanticsLabel('Shared artwork');
    expect(button, findsOneWidget);
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: 'Shared artwork',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('shared artwork foreground handles input above the open layer',
      (tester) async {
    var openCount = 0;
    var foregroundCount = 0;
    await tester.pumpWidget(
      _app(
        _sharedSurface(
          onOpen: () => openCount += 1,
          foreground: Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              key: const ValueKey('shared-foreground-action'),
              behavior: HitTestBehavior.opaque,
              onTap: () => foregroundCount += 1,
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('shared-foreground-action')));

    expect(foregroundCount, 1);
    expect(openCount, 0);
  });

  testWidgets('artwork card badge applies light and dark glass treatments',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ArtworkCardBadge(
              key: ValueKey('light-badge'),
              padding: EdgeInsets.all(8),
              child: Text('01'),
            ),
            ArtworkCardBadge(
              key: ValueKey('dark-badge'),
              dark: true,
              child: Text('9.0'),
            ),
          ],
        ),
      ),
    );

    Container badgeContainer(String key) => tester.widget<Container>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(Container),
          ),
        );

    final light = badgeContainer('light-badge');
    final dark = badgeContainer('dark-badge');
    final lightDecoration = light.decoration! as BoxDecoration;
    final darkDecoration = dark.decoration! as BoxDecoration;

    expect(light.padding, const EdgeInsets.all(8));
    expect(lightDecoration.borderRadius, BorderRadius.circular(9));
    expect(lightDecoration.boxShadow?.single.blurRadius, 12);
    expect(darkDecoration.color, Colors.black.withValues(alpha: 0.62));
  });

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

    expect(
      find.byKey(const ValueKey('artwork-card-poster-0')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('poster-cover-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('poster-rank-pill-0')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('artwork-card-focus-poster-0')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(openedId, 'season-1');

    openedId = null;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(openedId, 'season-1');
  });

  testWidgets('poster hover keeps the lifted top edge clickable',
      (tester) async {
    String? openedId;
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 520,
          child: PosterRail(
            items: const [
              PosterRailItem(
                id: 'season-1',
                title: 'Season one',
                imageUrl: null,
              ),
            ],
            onOpen: (item) => openedId = item.id,
          ),
        ),
      ),
    );

    final card = find.byKey(const ValueKey('artwork-card-poster-0'));
    final action = find.byKey(
      const ValueKey('artwork-card-action-poster-0'),
    );
    final hoverRegion = find.ancestor(
      of: card,
      matching: find.byType(MouseRegion),
    );
    expect(hoverRegion, findsOneWidget);
    expect(
      tester.widget<MouseRegion>(hoverRegion).cursor,
      isNot(SystemMouseCursors.click),
    );
    expect(tester.widget<InkWell>(action).onTap, isNotNull);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pump();
    await tester.pump(AppAnimations.fast);

    final topInside =
        tester.getTopLeft(card) + Offset(tester.getSize(card).width / 2, 2);
    await mouse.moveTo(topInside);
    await mouse.down(topInside);
    await tester.pump();
    await mouse.up();
    await tester.pump();

    expect(openedId, 'season-1');
  });

  testWidgets('poster rail preserves card outlines and shadows',
      (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 520,
          child: PosterRail(
            items: const [
              PosterRailItem(
                id: 'season-1',
                title: 'Season one',
                imageUrl: null,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final rail = find.byKey(const ValueKey('poster-rail'));
    final listFinder = find.descendant(
      of: find.byType(PosterRail),
      matching: find.byType(ListView),
    );
    final list = tester.widget<ListView>(listFinder);
    final padding = list.padding! as EdgeInsets;
    final card = find.byKey(const ValueKey('artwork-card-poster-0'));

    expect(list.clipBehavior, Clip.none);
    expect(padding.horizontal, greaterThan(0));
    expect(
      tester.getTopLeft(card).dx - tester.getTopLeft(rail).dx,
      greaterThanOrEqualTo(18),
    );
  });

  testWidgets('海报卡片使用全尺寸按钮操作层', (tester) async {
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
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final card = find.byKey(const ValueKey('artwork-card-poster-0'));
    final action = find.byKey(
      const ValueKey('artwork-card-action-poster-0'),
    );
    expect(action, findsOneWidget);
    expect(tester.getSize(action), tester.getSize(card));
    expect(
      find.ancestor(
        of: action,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label == '第一季',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('海报卡片只暴露一个完整按钮语义', (tester) async {
    final semantics = tester.ensureSemantics();
    var semanticsDisposed = false;
    void disposeSemantics() {
      if (semanticsDisposed) return;
      semantics.dispose();
      semanticsDisposed = true;
    }

    addTearDown(disposeSemantics);
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
                meta: '12 集',
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final button = find.bySemanticsLabel('第一季，12 集');
    expect(button, findsOneWidget);
    expect(
      tester.getSemantics(button),
      matchesSemantics(
        label: '第一季，12 集',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(find.bySemanticsLabel('第一季'), findsNothing);
    expect(find.bySemanticsLabel('12 集'), findsNothing);
    disposeSemantics();
  });

  testWidgets('海报卡片悬停时上浮并放大封面', (tester) async {
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
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('artwork-card-poster-0')),
      ),
    );
    await tester.pump();
    await tester.pump(AppAnimations.fast);

    final card = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('artwork-card-poster-0')),
    );
    final cover = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('poster-cover-scale-0')),
    );
    expect(card.transform?.getTranslation().y, -6);
    expect(cover.scale, 1.025);
  });

  testWidgets('减少动态效果时海报卡片保持静止', (tester) async {
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
            onOpen: (_) {},
          ),
        ),
        disableAnimations: true,
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('artwork-card-poster-0')),
      ),
    );
    await tester.pump();
    await tester.pump(AppAnimations.fast);

    final card = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('artwork-card-poster-0')),
    );
    final cover = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('poster-cover-scale-0')),
    );
    expect(card.transform?.getTranslation().y, 0);
    expect(cover.scale, 1);
  });

  testWidgets('poster cards build and hover in dark theme', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 520,
          child: PosterRail(
            items: const [
              PosterRailItem(
                id: 'season-1',
                title: 'Season one',
                imageUrl: null,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
        darkMode: true,
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('artwork-card-poster-0')),
      ),
    );
    await tester.pump();
    await tester.pump(AppAnimations.fast);

    expect(
      find.byKey(const ValueKey('artwork-card-action-poster-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
