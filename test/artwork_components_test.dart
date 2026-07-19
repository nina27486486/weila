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

ScrollableState _posterRailScrollableState(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byType(PosterRail),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable);
}

double _expectedPosterRailThumbWidth(
  WidgetTester tester,
  Finder track,
) {
  final position = _posterRailScrollableState(tester).position;
  final trackWidth = tester.getSize(track).width;
  final contentExtent = position.viewportDimension + position.maxScrollExtent;
  final proportionalWidth =
      trackWidth * position.viewportDimension / contentExtent;
  final minThumbWidth = trackWidth < 96 ? trackWidth : 96.0;
  return proportionalWidth.clamp(minThumbWidth, trackWidth).toDouble();
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
    final lightBorder = lightDecoration.border! as Border;
    final darkBorder = darkDecoration.border! as Border;

    expect(light.padding, const EdgeInsets.all(8));
    expect(lightDecoration.borderRadius, BorderRadius.circular(9));
    expect(lightDecoration.boxShadow?.single.blurRadius, 12);
    expect(
      lightBorder.top.color,
      Colors.white.withValues(alpha: 0.72),
    );
    expect(darkDecoration.color, Colors.black.withValues(alpha: 0.62));
    expect(
      darkBorder.top.color,
      Colors.white.withValues(alpha: 0.22),
    );
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

    final scrollable = _posterRailScrollableState(tester);
    final before = scrollable.position.pixels;
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byType(PosterRail)),
        scrollDelta: const Offset(0, 280),
      ),
    );
    await tester.pump();
    final after = scrollable.position.pixels;

    expect(before, 0);
    expect(after, greaterThan(0));
  });

  testWidgets('冰晶滑块支持直接拖动和点击轨道', (tester) async {
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

    final position = _posterRailScrollableState(tester).position;
    final track = find.byKey(
      const ValueKey('poster-rail-scroll-track'),
    );
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );

    expect(position.pixels, 0);
    await tester.drag(thumb, const Offset(140, 0));
    await tester.pump();
    expect(position.pixels, greaterThan(0));

    position.jumpTo(0);
    await tester.pump();
    final trackRect = tester.getRect(track);
    await tester.tapAt(
      trackRect.topLeft + Offset(trackRect.width * 0.75, trackRect.height / 2),
    );
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));

    position.jumpTo(0);
    await tester.pump();
    await tester.tapAt(tester.getCenter(thumb));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
  });

  testWidgets('冰晶滑块取消轨道点击时不滚动', (tester) async {
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

    final position = _posterRailScrollableState(tester).position;
    final track = find.byKey(
      const ValueKey('poster-rail-scroll-track'),
    );
    final trackRect = tester.getRect(track);
    final gesture = await tester.startGesture(
      trackRect.topLeft + Offset(trackRect.width * 0.75, trackRect.height / 2),
    );

    await tester.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(0, 30));
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 90));

    expect(position.pixels, 0);
  });

  testWidgets('冰晶滑块支持方向键和读屏增减操作', (tester) async {
    final semantics = tester.ensureSemantics();
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

    final position = _posterRailScrollableState(tester).position;
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final slider = find.semantics.byLabel('拖动浏览本季作品');
    final halfViewport = position.viewportDimension / 2;

    expect(slider, findsOne);
    expect(
      slider.evaluate().single,
      matchesSemantics(
        label: '拖动浏览本季作品',
        value: '0%',
        increasedValue: '向后浏览',
        decreasedValue: '向前浏览',
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        isSlider: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(thumb);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(halfViewport, 0.001));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(0, 0.001));

    tester.semantics.increase(slider);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(halfViewport, 0.001));

    tester.semantics.decrease(slider);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(0, 0.001));
    semantics.dispose();
  });

  testWidgets('冰晶滑块连续翻页会累计尚未完成的动画目标', (tester) async {
    final semantics = tester.ensureSemantics();
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

    final position = _posterRailScrollableState(tester).position;
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final slider = find.semantics.byLabel('拖动浏览本季作品');
    final expectedTarget = (position.viewportDimension * 1.5).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await tester.tap(thumb);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(expectedTarget, 0.001));

    position.jumpTo(0);
    await tester.pump();
    tester.semantics.increase(slider);
    tester.semantics.increase(slider);
    await tester.pump(const Duration(milliseconds: 60));
    tester.semantics.increase(slider);
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(expectedTarget, 0.001));
    semantics.dispose();
  });

  testWidgets('冰晶滑块按视口比例缩放并跟随滚动位置', (tester) async {
    const railKey = ValueKey('geometry-poster-rail');

    Widget buildRail(int itemCount) {
      return _app(
        SizedBox(
          width: 520,
          child: PosterRail(
            key: railKey,
            items: List.generate(
              itemCount,
              (index) => PosterRailItem(
                id: '$index',
                title: 'Poster ${index + 1}',
                imageUrl: null,
              ),
            ),
            onOpen: (_) {},
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildRail(10),
    );

    final track = find.byKey(
      const ValueKey('poster-rail-scroll-track'),
    );
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final mascot = find.byKey(
      const ValueKey('poster-rail-scroll-mascot'),
    );
    final trackWidth = tester.getSize(track).width;
    final thumbWidth = tester.getSize(thumb).width;
    final expectedThumbWidth = _expectedPosterRailThumbWidth(tester, track);
    final initialLeft =
        tester.getTopLeft(thumb).dx - tester.getTopLeft(track).dx;

    expect(thumbWidth, closeTo(expectedThumbWidth, 0.001));
    expect(thumbWidth, lessThan(trackWidth));
    expect(initialLeft, closeTo(0, 0.001));
    expect(find.descendant(of: thumb, matching: mascot), findsOneWidget);

    final position = _posterRailScrollableState(tester).position;
    final travel = trackWidth - thumbWidth;
    position.jumpTo(position.maxScrollExtent / 2);
    await tester.pump();

    final halfwayLeft =
        tester.getTopLeft(thumb).dx - tester.getTopLeft(track).dx;
    expect(halfwayLeft, closeTo(travel / 2, 0.001));
    expect(find.descendant(of: thumb, matching: mascot), findsOneWidget);

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();

    final endLeft = tester.getTopLeft(thumb).dx - tester.getTopLeft(track).dx;
    final endTravel = trackWidth - tester.getSize(thumb).width;
    expect(endLeft, closeTo(endTravel, 0.001));
    final railRect = tester.getRect(find.byKey(railKey));
    final mascotRect = tester.getRect(mascot);
    expect(mascotRect.left, greaterThanOrEqualTo(railRect.left));
    expect(mascotRect.right, lessThanOrEqualTo(railRect.right));

    await tester.pumpWidget(buildRail(5));
    await tester.pump();

    final updatedThumbWidth = tester.getSize(thumb).width;
    final expectedUpdatedThumbWidth =
        _expectedPosterRailThumbWidth(tester, track);
    expect(updatedThumbWidth, closeTo(expectedUpdatedThumbWidth, 0.001));
    expect(updatedThumbWidth, isNot(closeTo(thumbWidth, 0.001)));
  });

  testWidgets('极窄轨道隐藏角色且正常宽度保持显示', (tester) async {
    Widget buildRail(double width) {
      return _app(
        SizedBox(
          width: width,
          child: PosterRail(
            items: const [
              PosterRailItem(
                id: 'only',
                title: 'Only poster',
                imageUrl: null,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      );
    }

    const mascotKey = ValueKey('poster-rail-scroll-mascot');
    final track = find.byKey(
      const ValueKey('poster-rail-scroll-track'),
    );

    await tester.pumpWidget(buildRail(60));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(track).width, lessThan(44));
    expect(find.byKey(mascotKey), findsNothing);

    await tester.pumpWidget(buildRail(520));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(track).width, greaterThanOrEqualTo(44));
    expect(find.byKey(mascotKey), findsOneWidget);
  });

  testWidgets('海报未溢出时冰晶滑块占满轨道', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 900,
          child: PosterRail(
            items: const [
              PosterRailItem(
                id: 'only',
                title: 'Only poster',
                imageUrl: null,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final track = find.byKey(
      const ValueKey('poster-rail-scroll-track'),
    );
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final thumbLeft = tester.getTopLeft(thumb).dx - tester.getTopLeft(track).dx;

    expect(tester.getSize(thumb).width, tester.getSize(track).width);
    expect(thumbLeft, closeTo(0, 0.001));
  });

  testWidgets('海报未溢出时冰晶滑块保持静态禁用', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 900,
          child: PosterRail(
            items: const [
              PosterRailItem(
                id: 'only',
                title: 'Only poster',
                imageUrl: null,
              ),
            ],
            onOpen: (_) {},
          ),
        ),
      ),
    );

    final position = _posterRailScrollableState(tester).position;
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final track = find.byKey(
      const ValueKey('poster-rail-scroll-track'),
    );
    final slider = find.semantics.byLabel('拖动浏览本季作品');

    expect(slider, findsOne);
    expect(
      slider.evaluate().single,
      matchesSemantics(
        label: '拖动浏览本季作品',
        value: '0%',
        hasEnabledState: true,
        isSlider: true,
      ),
    );
    expect(position.maxScrollExtent, 0);

    await tester.drag(thumb, const Offset(180, 0));
    await tester.tapAt(tester.getCenter(track));
    await tester.tap(thumb);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('冰晶滑块在减少动态效果时停用过渡', (tester) async {
    final semantics = tester.ensureSemantics();
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
        disableAnimations: true,
      ),
    );

    final position = _posterRailScrollableState(tester).position;
    final track = find.byKey(
      const ValueKey('poster-rail-scroll-track'),
    );
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final visual = find.byKey(
      const ValueKey('poster-rail-scroll-thumb-visual'),
    );
    final slider = find.semantics.byLabel('拖动浏览本季作品');
    final halfViewport = position.viewportDimension / 2;

    expect(tester.widget<AnimatedContainer>(visual).duration, Duration.zero);

    final trackRect = tester.getRect(track);
    await tester.tapAt(
      trackRect.topLeft + Offset(trackRect.width * 0.75, trackRect.height / 2),
    );
    expect(position.pixels, greaterThan(0));

    position.jumpTo(0);
    await tester.pump();
    await tester.tap(thumb);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(position.pixels, closeTo(halfViewport, 0.001));

    position.jumpTo(0);
    await tester.pump();
    tester.semantics.increase(slider);
    expect(position.pixels, closeTo(halfViewport, 0.001));
    semantics.dispose();
  });

  testWidgets('冰晶滑块悬停聚焦和拖动时增强视觉反馈', (tester) async {
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

    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final visual = find.byKey(
      const ValueKey('poster-rail-scroll-thumb-visual'),
    );
    Finder cursor(MouseCursor value) => find.ancestor(
          of: visual,
          matching: find.byWidgetPredicate(
            (widget) => widget is MouseRegion && widget.cursor == value,
          ),
        );
    BoxDecoration decoration() =>
        tester.widget<AnimatedContainer>(visual).decoration! as BoxDecoration;

    expect(tester.getSize(visual).height, 10);
    expect(
        tester.widget<AnimatedContainer>(visual).duration, AppAnimations.fast);
    expect(cursor(SystemMouseCursors.grab), findsOneWidget);
    expect(decoration().boxShadow!.single.blurRadius, 8);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(thumb));
    await tester.pumpAndSettle();
    expect(decoration().boxShadow!.single.blurRadius, 14);
    expect(tester.getSize(visual).height, 10);

    await mouse.down(tester.getCenter(thumb));
    await mouse.moveBy(const Offset(48, 0));
    await tester.pump();
    expect(cursor(SystemMouseCursors.grabbing), findsOneWidget);

    await mouse.up();
    await tester.pump();
    expect(cursor(SystemMouseCursors.grab), findsOneWidget);

    await mouse.down(tester.getCenter(thumb));
    await mouse.moveBy(const Offset(48, 0));
    await tester.pump();
    expect(cursor(SystemMouseCursors.grabbing), findsOneWidget);
    await mouse.cancel();
    await tester.pump();
    expect(cursor(SystemMouseCursors.grab), findsOneWidget);

    await mouse.moveTo(Offset.zero);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(decoration().boxShadow!.single.blurRadius, 8);
    expect(tester.getSize(visual).height, 10);
  });

  testWidgets('海报轨道展示冰晶拖动条与随行放映员', (tester) async {
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

    final rail = find.byKey(const ValueKey('poster-rail'));
    final cardStage = find.byKey(
      const ValueKey('poster-rail-card-stage'),
    );
    final scrollbar = find.byKey(
      const ValueKey('poster-rail-scrollbar'),
    );
    final track = find.byKey(
      const ValueKey('poster-rail-scroll-track'),
    );
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final mascot = find.byKey(
      const ValueKey('poster-rail-scroll-mascot'),
    );

    expect(cardStage, findsOneWidget);
    expect(scrollbar, findsOneWidget);
    expect(track, findsOneWidget);
    expect(thumb, findsOneWidget);
    expect(mascot, findsOneWidget);
    expect(tester.getSize(cardStage).height, 310);
    expect(tester.getSize(scrollbar).height, 48);
    expect(
      tester.getSize(track),
      Size(tester.getSize(rail).width - 36, 12),
    );
    expect(tester.getSize(thumb).height, 44);
    expect(tester.getSize(thumb).width, greaterThanOrEqualTo(96));
    expect(tester.getSize(thumb).width, lessThan(tester.getSize(track).width));
    expect(
      find.descendant(of: thumb, matching: mascot),
      findsOneWidget,
    );

    final mascotPointerGuard = find.ancestor(
      of: mascot,
      matching: find.byWidgetPredicate(
        (widget) => widget is IgnorePointer && widget.ignoring,
      ),
    );
    expect(mascotPointerGuard, findsOneWidget);
    expect(
      find.ancestor(
        of: thumb,
        matching: find.byWidgetPredicate(
          (widget) => widget is IgnorePointer && widget.ignoring,
        ),
      ),
      findsNothing,
    );
    expect(
      tester.widget<IgnorePointer>(mascotPointerGuard).child,
      same(tester.widget<Image>(mascot)),
    );
    expect(
      (tester.widget<Image>(mascot).image as AssetImage).assetName,
      'assets/images/scrollbar_navigator.webp',
    );
    expect(tester.getSize(rail).height, 358);

    await tester.pump();
    expect(tester.takeException(), isNull);
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

  testWidgets('enabling reduce motion stops an active poster rail animation',
      (tester) async {
    var reduceMotion = false;
    late StateSetter updateMediaQuery;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: StatefulBuilder(
          builder: (context, setState) {
            updateMediaQuery = setState;
            return MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 520,
                    child: PosterRail(
                      items: List.generate(
                        10,
                        (index) => PosterRailItem(
                          id: '$index',
                          title: 'Poster ${index + 1}',
                          imageUrl: null,
                        ),
                      ),
                      onOpen: (_) {},
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    final position = _posterRailScrollableState(tester).position;
    final thumb = find.byKey(
      const ValueKey('poster-rail-scroll-thumb'),
    );
    final visual = find.byKey(
      const ValueKey('poster-rail-scroll-thumb-visual'),
    );
    final halfViewport = position.viewportDimension / 2;

    await tester.tap(thumb);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final pixelsAtSwitch = position.pixels;
    expect(pixelsAtSwitch, greaterThan(0));
    expect(pixelsAtSwitch, lessThan(halfViewport));

    updateMediaQuery(() => reduceMotion = true);
    await tester.pump();
    final frozenPixels = position.pixels;
    expect(frozenPixels, closeTo(pixelsAtSwitch, 0.001));
    expect(tester.widget<AnimatedContainer>(visual).duration, Duration.zero);

    await tester.pump(const Duration(milliseconds: 240));
    expect(position.pixels, closeTo(frozenPixels, 0.001));

    updateMediaQuery(() => reduceMotion = false);
    await tester.pump();
    expect(
      tester.widget<AnimatedContainer>(visual).duration,
      AppAnimations.fast,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(position.pixels, greaterThan(frozenPixels));
    await tester.pumpAndSettle();
    expect(
      position.pixels,
      closeTo(
        (frozenPixels + halfViewport).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
        0.001,
      ),
    );
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
