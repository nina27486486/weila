# Poster Rail Mascot Scrollbar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-visible, custom draggable “crystal capsule” scrollbar with an original chibi projectionist mascot to the seasonal poster rail.

**Architecture:** Keep `PosterRail` as the owner of the existing `ScrollController` and add a private `_MascotRailScrollbar` sibling below the current `ListView`. The custom control derives thumb size and position from `ScrollPosition`, maps drag/tap/keyboard/semantics actions back to the same controller, and uses only transform/opacity/color animations that become zero-duration when reduced motion is enabled.

**Tech Stack:** Flutter Material, Dart, existing Vira theme tokens, Flutter widget tests, built-in imagegen asset with local chroma-key removal.

---

## File Map

- Create: `assets/images/scrollbar_navigator.webp` — transparent 256×256 original chibi mascot.
- Modify: `pubspec.yaml` — register the mascot asset.
- Modify: `lib/widgets/artwork_components.dart` — lay out the extra scrollbar region and implement `_MascotRailScrollbar`.
- Modify: `test/artwork_components_test.dart` — cover visuals, geometry, drag/tap/keyboard/semantics, reduced motion, disabled state, and regressions.

### Task 1: Add the Mascot Scrollbar Visual Shell

**Files:**
- Create: `assets/images/scrollbar_navigator.webp`
- Modify: `pubspec.yaml:60-64`
- Modify: `lib/widgets/artwork_components.dart:840-905`
- Test: `test/artwork_components_test.dart`

- [ ] **Step 1: Write the failing visual-shell test**

Add a widget test with ten items so the rail overflows:

```dart
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
  await tester.pump();

  expect(
    find.byKey(const ValueKey('poster-rail-scrollbar')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('poster-rail-scroll-track')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('poster-rail-scroll-thumb')),
    findsOneWidget,
  );
  final mascot = find.byKey(
    const ValueKey('poster-rail-scroll-mascot'),
  );
  expect(mascot, findsOneWidget);
  final image = tester.widget<Image>(mascot);
  expect(
    (image.image as AssetImage).assetName,
    'assets/images/scrollbar_navigator.webp',
  );

  final rail = find.byKey(const ValueKey('poster-rail'));
  expect(tester.getSize(rail).height, 358);
});
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
flutter test test/artwork_components_test.dart --plain-name "海报轨道展示冰晶拖动条与随行放映员"
```

Expected: FAIL because `poster-rail-scrollbar` does not exist.

- [ ] **Step 3: Prepare and register the final asset**

Copy the validated preview asset:

```powershell
Copy-Item -LiteralPath `
  '.superpowers\brainstorm\scrollbar-20260702170824\content\scrollbar-navigator-preview.webp' `
  -Destination 'assets\images\scrollbar_navigator.webp'
```

Add to `pubspec.yaml`:

```yaml
  assets:
    - assets/images/ranking_hero_anime.png
    - assets/images/scrollbar_navigator.webp
    - assets/textures/paper-light.webp
```

Verify the file remains 256×256, has Alpha, and is at most 40KB:

```powershell
ffprobe -v error -select_streams v:0 `
  -show_entries stream=width,height,pix_fmt `
  -of default=noprint_wrappers=1 `
  assets/images/scrollbar_navigator.webp
(Get-Item assets/images/scrollbar_navigator.webp).Length
```

Expected: `width=256`, `height=256`, `pix_fmt=argb`, size `<= 40960`.

- [ ] **Step 4: Add the static 48px scrollbar region**

Add constants near `PosterRail`:

```dart
const _posterRailScrollbarExtent = 48.0;
const _posterRailTrackHeight = 12.0;
const _posterRailThumbHeight = 10.0;
const _posterRailMascotSize = 40.0;
const _posterRailMinThumbWidth = 96.0;
```

Change `PosterRail` so the card stage keeps `widget.height` and the new region is added below it:

```dart
return SizedBox(
  key: const ValueKey('poster-rail'),
  height: widget.height + _posterRailScrollbarExtent,
  child: Column(
    children: [
      SizedBox(
        height: widget.height,
        child: Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            if (!_controller.hasClients) return;
            final position = _controller.position;
            final delta = event.scrollDelta.dy == 0
                ? event.scrollDelta.dx
                : event.scrollDelta.dy;
            position.jumpTo(
              (position.pixels + delta).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              ),
            );
          },
          child: ScrollConfiguration(
            behavior: const _DesktopDragScrollBehavior(),
            child: ListView.separated(
              controller: _controller,
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: widget.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return _PosterRailCard(
                  item: item,
                  index: index,
                  onOpen: () => widget.onOpen(item),
                );
              },
            ),
          ),
        ),
      ),
      SizedBox(
        height: _posterRailScrollbarExtent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: _MascotRailScrollbar(controller: _controller),
        ),
      ),
    ],
  ),
);
```

Add the initial private widget:

```dart
class _MascotRailScrollbar extends StatelessWidget {
  final ScrollController controller;

  const _MascotRailScrollbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('poster-rail-scrollbar'),
      height: _posterRailScrollbarExtent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomLeft,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            height: _posterRailTrackHeight,
            child: DecoratedBox(
              key: const ValueKey('poster-rail-scroll-track'),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: context.colors.sky.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                  alignment: Alignment.bottomLeft,
                  child: SizedBox(
                    key: const ValueKey('poster-rail-scroll-thumb'),
                    width: _posterRailMinThumbWidth,
                    height: 44,
                  ),
                ),
                const Positioned(
                  left: _posterRailMinThumbWidth - 16,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Image(
                      key: ValueKey('poster-rail-scroll-mascot'),
                      image: AssetImage(
                        'assets/images/scrollbar_navigator.webp',
                      ),
                      width: _posterRailMascotSize,
                      height: _posterRailMascotSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the visual-shell test and verify GREEN**

Run:

```powershell
flutter test test/artwork_components_test.dart --plain-name "海报轨道展示冰晶拖动条与随行放映员"
```

Expected: PASS.

- [ ] **Step 6: Commit the visual shell**

```powershell
git add assets/images/scrollbar_navigator.webp pubspec.yaml `
  lib/widgets/artwork_components.dart test/artwork_components_test.dart
git commit -m "feat: add poster rail mascot scrollbar"
```

### Task 2: Synchronize Thumb Geometry With the Poster Rail

**Files:**
- Modify: `lib/widgets/artwork_components.dart`
- Test: `test/artwork_components_test.dart`

- [ ] **Step 1: Write failing geometry tests**

Add a helper inside the test file for retrieving the rail position:

```dart
ScrollableState posterRailScrollable(WidgetTester tester) {
  final scrollable = find.descendant(
    of: find.byType(PosterRail),
    matching: find.byType(Scrollable),
  );
  return tester.state<ScrollableState>(scrollable);
}
```

Add:

```dart
testWidgets('冰晶滑块按视口比例缩放并跟随滚动位置', (tester) async {
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
  await tester.pump();

  final track = find.byKey(
    const ValueKey('poster-rail-scroll-track'),
  );
  final thumb = find.byKey(
    const ValueKey('poster-rail-scroll-thumb'),
  );
  final initialLeft =
      tester.getTopLeft(thumb).dx - tester.getTopLeft(track).dx;
  expect(tester.getSize(thumb).width, greaterThanOrEqualTo(96));
  expect(tester.getSize(thumb).width, lessThan(tester.getSize(track).width));

  final position = posterRailScrollable(tester).position;
  position.jumpTo(position.maxScrollExtent / 2);
  await tester.pump();

  final movedLeft =
      tester.getTopLeft(thumb).dx - tester.getTopLeft(track).dx;
  expect(initialLeft, 0);
  expect(movedLeft, greaterThan(0));
  expect(
    find.descendant(
      of: thumb,
      matching: find.byKey(
        const ValueKey('poster-rail-scroll-mascot'),
      ),
    ),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: Run the geometry test and verify RED**

Run:

```powershell
flutter test test/artwork_components_test.dart --plain-name "冰晶滑块按视口比例缩放并跟随滚动位置"
```

Expected: FAIL because the static thumb neither scales nor moves.

- [ ] **Step 3: Convert `_MascotRailScrollbar` to stateful geometry**

Use `ScrollController` as the animation source and refresh once after layout:

```dart
class _MascotRailScrollbar extends StatefulWidget {
  final ScrollController controller;

  const _MascotRailScrollbar({required this.controller});

  @override
  State<_MascotRailScrollbar> createState() =>
      _MascotRailScrollbarState();
}

class _MascotRailScrollbarState extends State<_MascotRailScrollbar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didUpdateWidget(_MascotRailScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }
}
```

Inside `LayoutBuilder`, calculate:

```dart
final position =
    widget.controller.hasClients ? widget.controller.position : null;
final viewport = position?.viewportDimension ?? constraints.maxWidth;
final maxScrollExtent = position?.maxScrollExtent ?? 0;
final contentExtent = viewport + maxScrollExtent;
final scrollable = maxScrollExtent > precisionErrorTolerance;
final trackWidth = constraints.maxWidth;
final proportionalWidth = contentExtent <= 0
    ? trackWidth
    : trackWidth * viewport / contentExtent;
final thumbWidth = scrollable
    ? proportionalWidth
        .clamp(
          math.min(_posterRailMinThumbWidth, trackWidth),
          trackWidth,
        )
        .toDouble()
    : trackWidth;
final travel = math.max(0.0, trackWidth - thumbWidth);
final progress = scrollable
    ? (position!.pixels / maxScrollExtent).clamp(0.0, 1.0)
    : 0.0;
final thumbLeft = travel * progress;
```

Import `dart:math` as `math`, and position one thumb subtree at `left: thumbLeft`, `width: thumbWidth`. Put the mascot inside that subtree using:

```dart
Positioned(
  right: -14,
  bottom: 0,
  child: IgnorePointer(
    child: Image.asset(
      'assets/images/scrollbar_navigator.webp',
      key: const ValueKey('poster-rail-scroll-mascot'),
      width: _posterRailMascotSize,
      height: _posterRailMascotSize,
    ),
  ),
),
```

- [ ] **Step 4: Run geometry and existing poster tests**

Run:

```powershell
flutter test test/artwork_components_test.dart
```

Expected: all component tests PASS.

- [ ] **Step 5: Commit geometry synchronization**

```powershell
git add lib/widgets/artwork_components.dart test/artwork_components_test.dart
git commit -m "feat: sync poster scrollbar geometry"
```

### Task 3: Add Drag, Track Tap, Keyboard, and Semantics

**Files:**
- Modify: `lib/widgets/artwork_components.dart`
- Test: `test/artwork_components_test.dart`

- [ ] **Step 1: Write failing drag and track-tap tests**

```dart
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
  await tester.pump();

  final position = posterRailScrollable(tester).position;
  final thumb = find.byKey(
    const ValueKey('poster-rail-scroll-thumb'),
  );
  await tester.drag(thumb, const Offset(140, 0));
  await tester.pump();
  expect(position.pixels, greaterThan(0));

  position.jumpTo(0);
  await tester.pump();
  final track = find.byKey(
    const ValueKey('poster-rail-scroll-track'),
  );
  await tester.tapAt(
    tester.getTopLeft(track) +
        Offset(tester.getSize(track).width * 0.75, 6),
  );
  await tester.pumpAndSettle();
  expect(position.pixels, greaterThan(0));
});
```

- [ ] **Step 2: Run and verify RED**

Run:

```powershell
flutter test test/artwork_components_test.dart --plain-name "冰晶滑块支持直接拖动和点击轨道"
```

Expected: FAIL because the thumb is not interactive.

- [ ] **Step 3: Implement drag and track tap**

Add state:

```dart
final _focusNode = FocusNode();
var _hovered = false;
var _focused = false;
var _dragging = false;
```

Dispose `_focusNode`. Add helpers:

```dart
void _scrollTo(double offset, {required bool animate}) {
  if (!widget.controller.hasClients) return;
  final position = widget.controller.position;
  final target =
      offset.clamp(position.minScrollExtent, position.maxScrollExtent);
  if (animate) {
    widget.controller.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 180),
      curve: AppAnimations.easeOut,
    );
  } else {
    widget.controller.jumpTo(target.toDouble());
  }
}

void _pageBy(double direction, {required bool animate}) {
  final position = widget.controller.position;
  _scrollTo(
    position.pixels + position.viewportDimension * 0.5 * direction,
    animate: animate,
  );
}
```

Wrap the track region in a `GestureDetector` whose `onTapUp` ignores taps inside the current thumb bounds and otherwise centers the thumb on the tap:

```dart
onTapUp: !scrollable
    ? null
    : (details) {
        final x = details.localPosition.dx;
        if (x >= thumbLeft && x <= thumbLeft + thumbWidth) return;
        final targetProgress =
            ((x - thumbWidth / 2) / travel).clamp(0.0, 1.0);
        _scrollTo(
          maxScrollExtent * targetProgress,
          animate: motionEnabled,
        );
      },
```

Wrap the 44px thumb hit target in `MouseRegion` and `GestureDetector`:

```dart
onHorizontalDragStart: !scrollable
    ? null
    : (_) {
        _focusNode.requestFocus();
        setState(() => _dragging = true);
      },
onHorizontalDragUpdate: !scrollable
    ? null
    : (details) {
        if (travel <= 0) return;
        _scrollTo(
          widget.controller.offset +
              details.delta.dx / travel * maxScrollExtent,
          animate: false,
        );
      },
onHorizontalDragEnd: !scrollable
    ? null
    : (_) => setState(() => _dragging = false),
onHorizontalDragCancel: !scrollable
    ? null
    : () => setState(() => _dragging = false),
```

Use `SystemMouseCursors.grab` while idle and `grabbing` while dragging.

- [ ] **Step 4: Add keyboard and semantics tests**

```dart
testWidgets('冰晶滑块支持方向键和读屏增减操作', (tester) async {
  final semantics = tester.ensureSemantics();
  addTearDown(semantics.dispose);
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
  await tester.pump();

  final position = posterRailScrollable(tester).position;
  final thumb = find.byKey(
    const ValueKey('poster-rail-scroll-thumb'),
  );
  await tester.tap(thumb);
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
  await tester.pumpAndSettle();
  expect(position.pixels, greaterThan(0));

  position.jumpTo(0);
  await tester.pump();
  final semanticFinder = find.bySemanticsLabel('拖动浏览本季作品');
  final node = tester.getSemantics(semanticFinder);
  expect(node.hasAction(SemanticsAction.increase), isTrue);
  expect(node.hasAction(SemanticsAction.decrease), isTrue);
  tester.binding.pipelineOwner.semanticsOwner!.performAction(
    node.id,
    SemanticsAction.increase,
  );
  await tester.pumpAndSettle();
  expect(position.pixels, greaterThan(0));
});
```

- [ ] **Step 5: Run and verify RED**

Run:

```powershell
flutter test test/artwork_components_test.dart --plain-name "冰晶滑块支持方向键和读屏增减操作"
```

Expected: FAIL because the thumb has no focus or semantics actions.

- [ ] **Step 6: Implement focus, shortcuts, and semantics**

Add a private intent:

```dart
class _PosterRailScrollIntent extends Intent {
  final double direction;

  const _PosterRailScrollIntent(this.direction);
}
```

Wrap the thumb hit target:

```dart
FocusableActionDetector(
  focusNode: _focusNode,
  mouseCursor: _dragging
      ? SystemMouseCursors.grabbing
      : SystemMouseCursors.grab,
  onShowFocusHighlight: (value) =>
      setState(() => _focused = value),
  shortcuts: const {
    SingleActivator(LogicalKeyboardKey.arrowLeft):
        _PosterRailScrollIntent(-1),
    SingleActivator(LogicalKeyboardKey.arrowRight):
        _PosterRailScrollIntent(1),
  },
  actions: {
    _PosterRailScrollIntent: CallbackAction<_PosterRailScrollIntent>(
      onInvoke: (intent) {
        _pageBy(intent.direction, animate: motionEnabled);
        return null;
      },
    ),
  },
  child: Semantics(
    slider: true,
    enabled: scrollable,
    label: '拖动浏览本季作品',
    value: '${(progress * 100).round()}%',
    increasedValue: '向后浏览',
    decreasedValue: '向前浏览',
    onIncrease: scrollable
        ? () => _pageBy(1, animate: motionEnabled)
        : null,
    onDecrease: scrollable
        ? () => _pageBy(-1, animate: motionEnabled)
        : null,
    child: GestureDetector(
      key: const ValueKey('poster-rail-scroll-thumb'),
      behavior: HitTestBehavior.opaque,
      onTapDown: scrollable
          ? (_) => _focusNode.requestFocus()
          : null,
      onHorizontalDragStart: !scrollable
          ? null
          : (_) {
              _focusNode.requestFocus();
              setState(() => _dragging = true);
            },
      onHorizontalDragUpdate: !scrollable
          ? null
          : (details) {
              if (travel <= 0) return;
              _scrollTo(
                widget.controller.offset +
                    details.delta.dx / travel * maxScrollExtent,
                animate: false,
              );
            },
      onHorizontalDragEnd: !scrollable
          ? null
          : (_) => setState(() => _dragging = false),
      onHorizontalDragCancel: !scrollable
          ? null
          : () => setState(() => _dragging = false),
    ),
  ),
);
```

- [ ] **Step 7: Add reduced-motion and disabled-state tests**

```dart
testWidgets('冰晶滑块在减少动态效果时停用过渡', (tester) async {
  await tester.pumpWidget(
    _app(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: SizedBox(
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
    ),
  );
  await tester.pump();

  final visual = tester.widget<AnimatedContainer>(
    find.byKey(
      const ValueKey('poster-rail-scroll-thumb-visual'),
    ),
  );
  expect(visual.duration, Duration.zero);
});

testWidgets('海报未溢出时冰晶滑块保持静态禁用', (tester) async {
  final semantics = tester.ensureSemantics();
  addTearDown(semantics.dispose);
  await tester.pumpWidget(
    _app(
      SizedBox(
        width: 900,
        child: PosterRail(
          items: const [
            PosterRailItem(id: '1', title: '海报 1', imageUrl: null),
          ],
          onOpen: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();

  final track = find.byKey(
    const ValueKey('poster-rail-scroll-track'),
  );
  final thumb = find.byKey(
    const ValueKey('poster-rail-scroll-thumb'),
  );
  expect(tester.getSize(thumb).width, tester.getSize(track).width);
  final node = tester.getSemantics(
    find.bySemanticsLabel('拖动浏览本季作品'),
  );
  expect(node.hasAction(SemanticsAction.increase), isFalse);
  expect(node.hasAction(SemanticsAction.decrease), isFalse);
});
```

- [ ] **Step 8: Implement visual states and reduced motion**

Use:

```dart
final motionEnabled =
    !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
final active = _hovered || _focused || _dragging;
final duration = motionEnabled ? AppAnimations.fast : Duration.zero;
```

Build the thumb visual with:

```dart
AnimatedContainer(
  key: const ValueKey('poster-rail-scroll-thumb-visual'),
  duration: duration,
  curve: AppAnimations.easeOut,
  height: _posterRailThumbHeight,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(999),
    gradient: LinearGradient(
      colors: [
        context.colors.skyLight,
        context.colors.sky,
        context.colors.skyLight,
      ],
    ),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.78),
    ),
    boxShadow: [
      BoxShadow(
        color: context.colors.sky.withValues(
          alpha: active ? 0.30 : 0.18,
        ),
        blurRadius: active ? 14 : 9,
        offset: const Offset(0, 3),
      ),
    ],
  ),
);
```

Use a light/dark track gradient based on `Theme.of(context).brightness`, with the dark theme using lower white opacity.

- [ ] **Step 9: Run all component tests and analyze**

Run:

```powershell
flutter test test/artwork_components_test.dart
flutter analyze lib/widgets/artwork_components.dart `
  test/artwork_components_test.dart
```

Expected: all tests PASS and analyze reports `No issues found`.

- [ ] **Step 10: Commit interaction support**

```powershell
git add lib/widgets/artwork_components.dart test/artwork_components_test.dart
git commit -m "feat: make mascot scrollbar draggable"
```

### Task 4: Full Regression and Release Verification

**Files:**
- Verify only; no planned source changes.

- [ ] **Step 1: Run the Home and shared-component tests**

```powershell
flutter test test/artwork_components_test.dart `
  test/home_editorial_view_test.dart
```

Expected: all tests PASS.

- [ ] **Step 2: Run the full suite**

```powershell
flutter test
```

Expected: all tests PASS.

- [ ] **Step 3: Run full static analysis**

```powershell
flutter analyze
```

Expected: `No issues found`.

- [ ] **Step 4: Build Windows Release from the short path**

Verify `C:\codex_weila` targets the repository, then run:

```powershell
flutter build windows --release
```

Expected: `Built build\windows\x64\runner\Release\weila.exe`.

- [ ] **Step 5: Check repository scope**

```powershell
git diff --check
git status --short
git log --oneline -5
```

Expected: no whitespace errors; only the planned commits are present; worktree is clean.

- [ ] **Step 6: Merge and push**

If implementation was performed in an isolated worktree:

```powershell
git fetch origin
git merge --ff-only codex/poster-rail-mascot-scrollbar
git push origin master
```

Expected: local and remote `master` point to the same final commit.
