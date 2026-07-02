# Unified Artwork Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将今日放送、资料库收藏、发现页片库和本季选片统一到 A 方案柔光玻璃卡片，同时保留各页面原有布局与业务逻辑。

**Architecture:** 在 `artwork_components.dart` 中提炼纯展示 `ArtworkCardSurface`、`ArtworkCardInteraction` 与 `ArtworkCardBadge`。共享组件集中处理玻璃装饰、稳定悬停包络、Ink、键盘、语义和减少动态效果；各页面只通过 builder 提供封面与信息布局，并将独立删除按钮放在前景操作层。

**Tech Stack:** Flutter、Dart、Material、flutter_test、现有 `ViraColors`、`AppAnimations` 与 `CoverImage`

---

## 文件结构

- 修改 `lib/widgets/artwork_components.dart`
  - 新增共享 A 卡片外壳、交互状态和玻璃胶囊。
  - 将 `PosterRail` 迁移到共享外壳。
- 修改 `test/artwork_components_test.dart`
  - 覆盖共享外壳的鼠标、键盘、语义、前景操作和减少动态效果。
  - 保留现有 PosterRail 交互回归。
- 修改 `lib/pages/home/home_editorial_view.dart`
  - 将今日放送 Hero 与横卡迁移到共享外壳。
- 修改 `test/home_editorial_view_test.dart`
  - 覆盖五张今日卡和 Hero/横卡打开行为。
- 修改 `lib/pages/library/personal_archive_view.dart`
  - 将精选舞台和网格的 `_PosterArchiveCard` 迁移到共享外壳。
- 修改 `test/personal_archive_view_test.dart`
  - 覆盖精选/网格共享外壳和删除操作隔离。
- 修改 `lib/pages/discover/anime_catalog_view.dart`
  - 将 `_CatalogAnimeCard` 迁移到共享外壳与共享胶囊。
- 修改 `test/anime_catalog_view_test.dart`
  - 覆盖目录网格、编号/评分胶囊和响应式。

### Task 1: 提炼共享 A 卡片外壳并迁移 PosterRail

**Files:**
- Modify: `lib/widgets/artwork_components.dart`
- Modify: `test/artwork_components_test.dart`
- Test: `test/artwork_components_test.dart`

- [ ] **Step 1: 写入共享组件失败测试**

在 `test/artwork_components_test.dart` 添加：

```dart
testWidgets('共享封面卡片统一鼠标键盘语义与前景操作', (tester) async {
  var opened = 0;
  var removed = 0;

  await tester.pumpWidget(
    _app(
      SizedBox(
        width: 220,
        height: 330,
        child: ArtworkCardSurface(
          id: 'demo',
          semanticLabel: '打开测试番剧',
          onOpen: () => opened++,
          foreground: Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              key: const ValueKey('demo-remove'),
              onPressed: () => removed++,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
          contentBuilder: (context, interaction) => AnimatedScale(
            key: const ValueKey('demo-cover'),
            duration: interaction.duration,
            scale: interaction.coverScale,
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    ),
  );

  expect(
    find.byKey(const ValueKey('artwork-card-demo')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('artwork-card-action-demo')),
    findsOneWidget,
  );

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(
    tester.getCenter(find.byKey(const ValueKey('artwork-card-demo'))),
  );
  await tester.pump(AppAnimations.fast);

  final surface = tester.widget<AnimatedContainer>(
    find.byKey(const ValueKey('artwork-card-demo')),
  );
  final cover = tester.widget<AnimatedScale>(
    find.byKey(const ValueKey('demo-cover')),
  );
  expect(surface.transform?.getTranslation().y, -6);
  expect(cover.scale, 1.025);

  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
  expect(
    find.byKey(const ValueKey('artwork-card-focus-demo')),
    findsOneWidget,
  );
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  expect(opened, 1);
  await tester.sendKeyEvent(LogicalKeyboardKey.space);
  expect(opened, 2);

  await tester.tap(find.byKey(const ValueKey('demo-remove')));
  expect(removed, 1);
  expect(opened, 2);
});

testWidgets('共享封面卡片在减少动态效果时保持静止', (tester) async {
  await tester.pumpWidget(
    _app(
      SizedBox(
        width: 220,
        height: 330,
        child: ArtworkCardSurface(
          id: 'reduced',
          semanticLabel: '打开静止卡片',
          onOpen: () {},
          contentBuilder: (context, interaction) => AnimatedScale(
            key: const ValueKey('reduced-cover'),
            duration: interaction.duration,
            scale: interaction.coverScale,
            child: const ColoredBox(color: Colors.blue),
          ),
        ),
      ),
      disableAnimations: true,
    ),
  );

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(
    tester.getCenter(find.byKey(const ValueKey('artwork-card-reduced'))),
  );
  await tester.pump();

  final surface = tester.widget<AnimatedContainer>(
    find.byKey(const ValueKey('artwork-card-reduced')),
  );
  final cover = tester.widget<AnimatedScale>(
    find.byKey(const ValueKey('reduced-cover')),
  );
  expect(surface.transform?.getTranslation().y ?? 0, 0);
  expect(cover.scale, 1);
  expect(cover.duration, Duration.zero);
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```powershell
flutter test test/artwork_components_test.dart --plain-name "共享封面卡片统一鼠标键盘语义与前景操作"
flutter test test/artwork_components_test.dart --plain-name "共享封面卡片在减少动态效果时保持静止"
```

Expected: FAIL，`ArtworkCardSurface`、`ArtworkCardInteraction` 尚不存在。

- [ ] **Step 3: 实现共享交互类型、外壳和胶囊**

在 `lib/widgets/artwork_components.dart` 的 `PosterRail` 之前新增：

```dart
@immutable
class ArtworkCardInteraction {
  final bool active;
  final bool motionEnabled;
  final Duration duration;

  const ArtworkCardInteraction({
    required this.active,
    required this.motionEnabled,
    required this.duration,
  });

  double get coverScale => motionEnabled && active ? 1.025 : 1;
}

typedef ArtworkCardContentBuilder = Widget Function(
  BuildContext context,
  ArtworkCardInteraction interaction,
);

class ArtworkCardSurface extends StatefulWidget {
  final String id;
  final String semanticLabel;
  final VoidCallback onOpen;
  final ArtworkCardContentBuilder contentBuilder;
  final Widget? foreground;
  final double lift;
  final BorderRadius borderRadius;

  const ArtworkCardSurface({
    super.key,
    required this.id,
    required this.semanticLabel,
    required this.onOpen,
    required this.contentBuilder,
    this.foreground,
    this.lift = 6,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<ArtworkCardSurface> createState() => _ArtworkCardSurfaceState();
}

class _ArtworkCardSurfaceState extends State<ArtworkCardSurface> {
  var _hovered = false;
  var _focused = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final motionEnabled =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final active = _hovered || _focused;
    final duration = motionEnabled ? AppAnimations.fast : Duration.zero;
    final interaction = ArtworkCardInteraction(
      active: active,
      motionEnabled: motionEnabled,
      duration: duration,
    );

    return MouseRegion(
      key: ValueKey('artwork-card-hover-${widget.id}'),
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Padding(
        padding: EdgeInsets.only(top: widget.lift),
        child: AnimatedContainer(
          key: ValueKey('artwork-card-${widget.id}'),
          duration: duration,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            motionEnabled && active ? -widget.lift : 0,
            0,
          ),
          transformAlignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      colors.paper.withValues(alpha: 0.96),
                      colors.bgCard.withValues(alpha: 0.90),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.96),
                      colors.paper.withValues(alpha: 0.90),
                    ],
            ),
            border: Border.all(
              color: active
                  ? colors.sky.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: dark ? 0.20 : 0.82),
              width: active ? 1.4 : 1,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(
                  alpha: active ? 0.16 : 0.08,
                ),
                blurRadius: active ? 28 : 18,
                offset: Offset(0, active ? 13 : 8),
              ),
              BoxShadow(
                color: colors.sky.withValues(
                  alpha: active ? 0.14 : 0.06,
                ),
                blurRadius: active ? 20 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: widget.contentBuilder(context, interaction),
              ),
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: widget.semanticLabel,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('artwork-card-action-${widget.id}'),
                      onTap: widget.onOpen,
                      mouseCursor: SystemMouseCursors.click,
                      onFocusChange: (value) {
                        if (_focused == value) return;
                        setState(() => _focused = value);
                      },
                      borderRadius: widget.borderRadius,
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      splashColor: colors.sky.withValues(alpha: 0.12),
                      highlightColor: colors.sky.withValues(alpha: 0.08),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              if (_focused)
                IgnorePointer(
                  key: ValueKey('artwork-card-focus-${widget.id}'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius,
                      border: Border.all(color: colors.sky, width: 2),
                    ),
                  ),
                ),
              if (widget.foreground case final foreground?) foreground,
            ],
          ),
        ),
      ),
    );
  }
}

class ArtworkCardBadge extends StatelessWidget {
  final Widget child;
  final bool dark;
  final EdgeInsets padding;

  const ArtworkCardBadge({
    super.key,
    required this.child,
    this.dark = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withValues(alpha: 0.62)
            : colors.paper.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.22 : 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: 将 PosterRail 迁移到共享外壳**

删除 `_PosterRailCardState` 与 `_PosterHoverEnvelope` 的重复状态和装饰逻辑，将 `_PosterRailCard` 改为 StatelessWidget，并在 `build` 中返回：

```dart
return SizedBox(
  width: 188,
  child: ArtworkCardSurface(
    id: 'poster-$index',
    semanticLabel: item.meta.isEmpty
        ? item.title
        : '${item.title}，${item.meta}',
    onOpen: onOpen,
    contentBuilder: (context, interaction) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            key: ValueKey('poster-cover-$index'),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(15),
              bottom: Radius.circular(8),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedScale(
                  key: ValueKey('poster-cover-scale-$index'),
                  duration: interaction.duration,
                  curve: Curves.easeOutCubic,
                  scale: interaction.coverScale,
                  child: CoverImage(url: item.imageUrl),
                ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: ArtworkCardBadge(
                    key: ValueKey('poster-rank-pill-$index'),
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.sky,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.colors.textPrimary,
                    ),
              ),
              if (item.meta.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  item.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  ),
);
```

将 PosterRail 测试 key 更新为：

```dart
const ValueKey('artwork-card-poster-0')
const ValueKey('artwork-card-action-poster-0')
const ValueKey('artwork-card-focus-poster-0')
const ValueKey('artwork-card-hover-poster-0')
```

封面和编号 key 保持不变。

- [ ] **Step 5: 运行组件测试与分析**

Run:

```powershell
dart format lib/widgets/artwork_components.dart test/artwork_components_test.dart
flutter test test/artwork_components_test.dart
flutter analyze lib/widgets/artwork_components.dart test/artwork_components_test.dart
git diff --check
```

Expected: 全部组件测试 PASS；分析输出 `No issues found!`。

- [ ] **Step 6: 提交共享组件**

```powershell
git add lib/widgets/artwork_components.dart test/artwork_components_test.dart
git commit -m "refactor: extract shared artwork card surface"
```

### Task 2: 迁移今日放送 Hero 与横卡

**Files:**
- Modify: `lib/pages/home/home_editorial_view.dart`
- Modify: `test/home_editorial_view_test.dart`
- Test: `test/home_editorial_view_test.dart`

- [ ] **Step 1: 写入今日放送失败测试**

在 `test/home_editorial_view_test.dart` 添加：

```dart
testWidgets('今日放送主卡与横卡使用统一 A 卡片', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Map<String, dynamic>? opened;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: HomeEditorialView(
          latestItems: animeItems,
          seasonalItems: animeItems,
          trendingItems: animeItems,
          continueStories: continueStories,
          onOpenAnime: (item) => opened = item,
          onOpenContinue: (_) {},
          onRetry: () {},
        ),
      ),
    ),
  );

  for (var index = 0; index < 5; index++) {
    expect(
      find.byKey(ValueKey('artwork-card-today-$index')),
      findsOneWidget,
    );
  }

  await tester.tap(
    find.byKey(const ValueKey('artwork-card-action-today-0')),
  );
  expect(opened, animeItems.first);
  expect(
    find.byKey(const ValueKey('today-cover-scale-0')),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```powershell
flutter test test/home_editorial_view_test.dart --plain-name "今日放送主卡与横卡使用统一 A 卡片"
```

Expected: FAIL，找不到 `artwork-card-today-0`。

- [ ] **Step 3: 为 _AiringCard 增加稳定 id 并接入共享外壳**

在 `_TodaySection` 的窄屏和宽屏 builder 中，分别传入：

```dart
cardId: 'today-$index'
```

首张宽屏主卡传入：

```dart
cardId: 'today-0'
```

其余宽屏网格传入：

```dart
cardId: 'today-${index + 1}'
```

将 `_AiringCard` 增加：

```dart
final String cardId;
```

并将返回值改为：

```dart
return ArtworkCardSurface(
  id: cardId,
  semanticLabel: '打开${_nameOf(item)}',
  onOpen: onOpen,
  contentBuilder: (context, interaction) {
    if (featured) {
      return Stack(
        fit: StackFit.expand,
        children: [
          AnimatedScale(
            key: ValueKey('today-cover-scale-${cardId.split('-').last}'),
            duration: interaction.duration,
            curve: Curves.easeOutCubic,
            scale: interaction.coverScale,
            child: CoverImage(
              url: item['cover']?.toString(),
              fit: BoxFit.cover,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.76),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusOf(item),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.skyLight,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  _nameOf(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 104,
          height: double.infinity,
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(15),
              right: Radius.circular(8),
            ),
            child: AnimatedScale(
              key: ValueKey('today-cover-scale-${cardId.split('-').last}'),
              duration: interaction.duration,
              curve: Curves.easeOutCubic,
              scale: interaction.coverScale,
              child: CoverImage(
                url: item['cover']?.toString(),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusOf(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.sky,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  _nameOf(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                if (_scoreOf(item) case final score?)
                  Text(
                    '评分 ${score.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  },
);
```

`_HoverSurface` 保留给首页其他非本任务卡片，不做范围外迁移。

- [ ] **Step 4: 运行首页测试和响应式回归**

Run:

```powershell
dart format lib/pages/home/home_editorial_view.dart test/home_editorial_view_test.dart
flutter test test/home_editorial_view_test.dart
flutter analyze lib/pages/home/home_editorial_view.dart test/home_editorial_view_test.dart
```

Expected: 首页测试全部 PASS；960、1280、1600 无溢出。

- [ ] **Step 5: 提交今日放送迁移**

```powershell
git add lib/pages/home/home_editorial_view.dart test/home_editorial_view_test.dart
git commit -m "feat: unify today artwork cards"
```

### Task 3: 迁移资料库精选舞台与封面网格

**Files:**
- Modify: `lib/pages/library/personal_archive_view.dart`
- Modify: `test/personal_archive_view_test.dart`
- Test: `test/personal_archive_view_test.dart`

- [ ] **Step 1: 写入资料库失败测试**

添加：

```dart
testWidgets('资料库精选与网格使用统一 A 卡片且删除不触发打开', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  ArchiveEntry? opened;
  ArchiveEntry? removed;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: PersonalArchiveView(
          title: '我的资料库',
          description: '统一卡片测试',
          mode: ArchiveDisplayMode.poster,
          entries: entries,
          onOpen: (entry) => opened = entry,
          onRemove: (entry) => removed = entry,
        ),
      ),
    ),
  );

  for (final entry in entries) {
    expect(
      find.byKey(ValueKey('artwork-card-archive-${entry.id}')),
      findsOneWidget,
    );
  }

  await tester.tap(find.byTooltip('移除${entries.first.title}'));
  expect(removed, entries.first);
  expect(opened, isNull);

  await tester.tap(
    find.byKey(
      ValueKey('artwork-card-action-archive-${entries.first.id}'),
    ),
  );
  expect(opened, entries.first);
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```powershell
flutter test test/personal_archive_view_test.dart --plain-name "资料库精选与网格使用统一 A 卡片且删除不触发打开"
```

Expected: FAIL，找不到 `artwork-card-archive-entry:0`。

- [ ] **Step 3: 将 _PosterArchiveCard 改为共享外壳**

将 `_PosterArchiveCard` 改为 StatelessWidget，并返回：

```dart
return ArtworkCardSurface(
  id: 'archive-${entry.id}',
  semanticLabel: '打开${entry.title}',
  onOpen: onOpen,
  foreground: Positioned(
    right: 7,
    top: 7,
    child: _RemoveButton(
      title: entry.title,
      onRemove: onRemove,
    ),
  ),
  contentBuilder: (context, interaction) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(15),
            bottom: Radius.circular(8),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedScale(
                key: ValueKey('archive-cover-scale-${entry.id}'),
                duration: interaction.duration,
                curve: Curves.easeOutCubic,
                scale: interaction.coverScale,
                child: CoverImage(
                  url: entry.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 9,
                top: 9,
                child: ArtworkCardBadge(
                  key: ValueKey('archive-rank-${entry.id}'),
                  child: Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.colors.sky,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 5),
            Text(
              entry.meta.isEmpty ? entry.sourceLabel : entry.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  ),
);
```

精选舞台保留现有 `Transform.rotate`、重叠位置和前三项逻辑。将舞台卡片 `Positioned.height` 从 294 调整为 300，为共享外壳的 6px 上浮包络保留原视觉高度。

- [ ] **Step 4: 运行资料库测试与响应式回归**

Run:

```powershell
dart format lib/pages/library/personal_archive_view.dart test/personal_archive_view_test.dart
flutter test test/personal_archive_view_test.dart
flutter analyze lib/pages/library/personal_archive_view.dart test/personal_archive_view_test.dart
```

Expected: 精选、网格、少于三项、时间线、进度和 960/1280/1600 测试全部 PASS。

- [ ] **Step 5: 提交资料库迁移**

```powershell
git add lib/pages/library/personal_archive_view.dart test/personal_archive_view_test.dart
git commit -m "feat: unify archive artwork cards"
```

### Task 4: 迁移发现页片库网格

**Files:**
- Modify: `lib/pages/discover/anime_catalog_view.dart`
- Modify: `test/anime_catalog_view_test.dart`
- Test: `test/anime_catalog_view_test.dart`

- [ ] **Step 1: 写入发现页失败测试**

添加：

```dart
testWidgets('片库网格使用统一 A 卡片与玻璃编号评分', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  Map<String, dynamic>? opened;

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AnimeCatalogView(
          title: '分类浏览',
          description: '统一卡片测试',
          items: items,
          onOpenAnime: (item) => opened = item,
          onRetry: () {},
        ),
      ),
    ),
  );

  expect(
    find.byKey(const ValueKey('artwork-card-catalog-0')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('catalog-rank-0')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('catalog-score-0')),
    findsOneWidget,
  );

  await tester.tap(
    find.byKey(const ValueKey('artwork-card-action-catalog-0')),
  );
  expect(opened, items.first);
});
```

- [ ] **Step 2: 运行测试并确认 RED**

Run:

```powershell
flutter test test/anime_catalog_view_test.dart --plain-name "片库网格使用统一 A 卡片与玻璃编号评分"
```

Expected: FAIL，找不到 `artwork-card-catalog-0`。

- [ ] **Step 3: 将 _CatalogAnimeCard 迁移到共享外壳**

在文件中引入：

```dart
import '../../widgets/artwork_components.dart';
```

将 `_CatalogAnimeCard` 改为 StatelessWidget，并返回：

```dart
return ArtworkCardSurface(
  id: 'catalog-$index',
  semanticLabel: '查看$name',
  onOpen: onTap,
  contentBuilder: (context, interaction) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(15),
            bottom: Radius.circular(8),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedScale(
                key: ValueKey('catalog-cover-scale-$index'),
                duration: interaction.duration,
                curve: Curves.easeOutCubic,
                scale: interaction.coverScale,
                child: CoverImage(
                  url: item['cover']?.toString(),
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 9,
                top: 9,
                child: ArtworkCardBadge(
                  key: ValueKey('catalog-rank-$index'),
                  child: Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.colors.sky,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              if (score != null)
                Positioned(
                  right: 9,
                  top: 9,
                  child: ArtworkCardBadge(
                    key: ValueKey('catalog-score-$index'),
                    dark: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: context.colors.warning,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          score.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 5),
            Text(
              genres.isEmpty ? status : genres.take(2).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  ),
);
```

- [ ] **Step 4: 添加目录响应式回归**

添加：

```dart
testWidgets('片库 A 卡片在 960、1280、1600 宽度下无溢出', (tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));

  for (final width in [960.0, 1280.0, 1600.0]) {
    await tester.binding.setSurfaceSize(Size(width, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: AnimeCatalogView(
            title: '响应式片库',
            description: '不同桌面宽度都保持清楚。',
            items: items,
            onOpenAnime: (_) {},
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('artwork-card-catalog-0')),
      findsOneWidget,
    );
  }
});

testWidgets('片库 A 卡片保持长标题与空封面可用', (tester) async {
  const longTitle = '这是一个用于验证单行省略且不会撑破卡片高度的超长番剧标题';

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AnimeCatalogView(
          title: '异常内容',
          description: '验证封面与标题回退。',
          items: const [
            <String, dynamic>{
              'name': longTitle,
              'cover': null,
              'score': null,
              'status': '已完结',
              'genres': <String>[],
              'url': 'catalog:long',
            },
          ],
          onOpenAnime: (_) {},
          onRetry: () {},
        ),
      ),
    ),
  );

  final title = tester.widget<Text>(find.text(longTitle));
  expect(title.maxLines, 1);
  expect(title.overflow, TextOverflow.ellipsis);
  expect(
    find.byKey(const ValueKey('artwork-card-catalog-0')),
    findsOneWidget,
  );
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 5: 运行发现页测试和分析**

Run:

```powershell
dart format lib/pages/discover/anime_catalog_view.dart test/anime_catalog_view_test.dart
flutter test test/anime_catalog_view_test.dart
flutter analyze lib/pages/discover/anime_catalog_view.dart test/anime_catalog_view_test.dart
```

Expected: 目录网格、筛选、错误、响应式测试全部 PASS。

- [ ] **Step 6: 提交发现页迁移**

```powershell
git add lib/pages/discover/anime_catalog_view.dart test/anime_catalog_view_test.dart
git commit -m "feat: unify catalog artwork cards"
```

### Task 5: 跨页面回归与项目级验证

**Files:**
- Test: `test/artwork_components_test.dart`
- Test: `test/home_editorial_view_test.dart`
- Test: `test/personal_archive_view_test.dart`
- Test: `test/anime_catalog_view_test.dart`

- [ ] **Step 1: 运行四组目标测试**

Run:

```powershell
flutter test test/artwork_components_test.dart
flutter test test/home_editorial_view_test.dart
flutter test test/personal_archive_view_test.dart
flutter test test/anime_catalog_view_test.dart
```

Expected: 四组测试全部 PASS。

- [ ] **Step 2: 运行完整测试**

Run:

```powershell
flutter test
```

Expected: 所有测试 PASS，0 failures。

- [ ] **Step 3: 运行完整静态分析**

Run:

```powershell
flutter analyze
```

Expected: `No issues found!`。

- [ ] **Step 4: 从短路径执行 Windows Release 构建**

确认短路径 Junction 指向功能工作树，然后运行：

```powershell
flutter build windows --release
```

Working directory: `C:\codex_weila_unified_cards`

Expected: `Built build\windows\x64\runner\Release\weila.exe`。若 `media_kit` 生成 0 字节 mpv 包，先验证主工作区同版本缓存 MD5 与插件要求一致，再只替换该生成缓存并重建。

- [ ] **Step 5: 核对范围和工作树**

Run:

```powershell
git diff --check
git status --short --branch
git diff --stat master...HEAD
```

Expected: 只包含计划中的共享组件、三个页面与四个测试文件；工作树干净。

### Task 6: 整体评审、合并与同步

**Files:**
- No source changes

- [ ] **Step 1: 对完整实现执行规格与代码质量评审**

Review range: 功能分支基线到当前 HEAD。

Expected: 所有设计要求有代码与测试证据；Critical 和 Important 均为无。

- [ ] **Step 2: 抓取远端并确认 master 无分叉**

Run:

```powershell
git fetch origin
git status --short --branch
```

Expected: 主工作区无未提交修改，远端没有需要人工解决的分叉。

- [ ] **Step 3: 快进合并功能分支**

Run:

```powershell
git merge --ff-only codex/unified-artwork-cards
```

Expected: Fast-forward 成功。

- [ ] **Step 4: 在 master 上重新验证**

Run:

```powershell
flutter test
flutter analyze
```

Working directory for Release:

```text
C:\codex_weila
```

Run:

```powershell
flutter build windows --release
```

Expected: 测试全部 PASS、分析 0 issues、Release 构建成功。

- [ ] **Step 5: 推送并清理**

Run:

```powershell
git push origin master
git worktree remove .worktrees/unified-artwork-cards
git worktree prune
git branch -d codex/unified-artwork-cards
```

Expected: `master` 与 `origin/master` 同步，独立工作树和已合并分支删除。
