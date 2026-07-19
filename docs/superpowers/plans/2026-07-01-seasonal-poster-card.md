# Seasonal Poster Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将首页“本季选片”的 `PosterRail` 升级为柔光玻璃杂志卡，并补齐鼠标、键盘、深浅主题和减少动态效果支持。

**Architecture:** 保持 `PosterRailItem`、`PosterRail` 和首页数据映射接口不变，只重构私有 `_PosterRailCard`。卡片通过现有主题色和动画令牌构建静态玻璃层次，交互状态由卡片本地 State 管理，不引入 Store、Service、外部素材或第三方依赖。

**Tech Stack:** Flutter、Dart、Material、flutter_test、现有 `ViraColors`、`AppAnimations` 与 `CoverImage`

---

## 文件结构

- 修改 `lib/widgets/artwork_components.dart:628-813`
  - 保留横向轨道、滚轮和拖动逻辑。
  - 将 `_PosterRailCard` 改为圆角柔光卡片，管理 hover、focus 和减少动态效果状态。
- 修改 `test/artwork_components_test.dart`
  - 添加卡片结构、悬停、键盘和减少动态效果测试。
- 复用 `test/home_editorial_view_test.dart`
  - 运行已有 960、1280、1600 首页响应式测试，不改变测试夹具或领域数据。

### Task 1: 锁定卡片结构与键盘行为

**Files:**
- Modify: `test/artwork_components_test.dart`
- Test: `test/artwork_components_test.dart`

- [ ] **Step 1: 写入失败的结构与键盘测试**

在现有“海报轨道支持鼠标滚轮横向浏览全部条目”测试之前添加：

```dart
testWidgets('海报轨道使用柔光卡片并支持键盘打开', (tester) async {
  PosterRailItem? opened;

  await tester.pumpWidget(
    _app(
      SizedBox(
        width: 520,
        child: PosterRail(
          items: const [
            PosterRailItem(
              id: 'season-1',
              title: '幼女战记 II',
              imageUrl: null,
              meta: '动作 · 奇幻',
            ),
          ],
          onOpen: (item) => opened = item,
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
  expect(opened?.id, 'season-1');
});
```

同时在文件顶部添加：

```dart
import 'package:flutter/services.dart';
```

- [ ] **Step 2: 运行测试并确认失败**

Run:

```powershell
flutter test test/artwork_components_test.dart --plain-name "海报轨道使用柔光卡片并支持键盘打开"
```

Expected: FAIL，找不到 `poster-card-0`、`poster-cover-0` 或 `poster-rank-pill-0`。

- [ ] **Step 3: 添加卡片结构、焦点与键盘打开的最小实现**

在 `_PosterRailCardState` 中增加焦点状态：

```dart
var _hovered = false;
var _focused = false;
```

将原 `GestureDetector` 改为 `Material` 与 `InkWell`，保留 `MouseRegion`：

```dart
Material(
  type: MaterialType.transparency,
  child: InkWell(
    key: ValueKey('poster-card-action-${widget.index}'),
    borderRadius: BorderRadius.circular(16),
    onTap: widget.onOpen,
    onFocusChange: (value) => setState(() => _focused = value),
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,
    splashColor: colors.sky.withValues(alpha: 0.12),
    highlightColor: colors.sky.withValues(alpha: 0.08),
    child: AnimatedContainer(
      key: ValueKey('poster-card-${widget.index}'),
      duration: AppAnimations.fast,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  key: ValueKey('poster-cover-${widget.index}'),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                    bottom: Radius.circular(8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverImage(url: widget.item.imageUrl),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          key: ValueKey('poster-rank-pill-${widget.index}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.paper.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                          ),
                          child: Text(
                            '${widget.index + 1}'.padLeft(2, '0'),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.sky,
                                  fontWeight: FontWeight.w700,
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
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (widget.item.meta.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        widget.item.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_focused)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  key: ValueKey('poster-focus-ring-${widget.index}'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.sky, width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
)
```

保留现有标题、元信息的单行省略和 `widget.onOpen` 回调，不修改 `PosterRailItem` 或 `PosterRail` 公共接口。

- [ ] **Step 4: 格式化并运行测试**

Run:

```powershell
dart format lib/widgets/artwork_components.dart test/artwork_components_test.dart
flutter test test/artwork_components_test.dart --plain-name "海报轨道使用柔光卡片并支持键盘打开"
```

Expected: PASS。

- [ ] **Step 5: 提交结构与键盘支持**

```powershell
git add lib/widgets/artwork_components.dart test/artwork_components_test.dart
git commit -m "feat: make seasonal posters keyboard-accessible cards"
```

### Task 2: 完成柔光玻璃视觉与悬停动效

**Files:**
- Modify: `test/artwork_components_test.dart`
- Modify: `lib/widgets/artwork_components.dart:694-813`
- Test: `test/artwork_components_test.dart`

- [ ] **Step 1: 写入失败的悬停与减少动态效果测试**

添加辅助构建函数和两个测试：

```dart
Widget posterRailUnderTest({
  required bool disableAnimations,
  ValueChanged<PosterRailItem>? onOpen,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: disableAnimations,
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SizedBox(
        width: 520,
        child: PosterRail(
          items: const [
            PosterRailItem(
              id: 'season-1',
              title: '幼女战记 II',
              imageUrl: null,
              meta: '动作 · 奇幻',
            ),
          ],
          onOpen: onOpen ?? (_) {},
        ),
      ),
    ),
  );
}

testWidgets('海报卡片悬停时上浮并放大封面', (tester) async {
  await tester.pumpWidget(
    posterRailUnderTest(disableAnimations: false),
  );

  final mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(
    tester.getCenter(find.byKey(const ValueKey('poster-card-0'))),
  );
  await tester.pump(AppAnimations.fast);

  final card = tester.widget<AnimatedContainer>(
    find.byKey(const ValueKey('poster-card-0')),
  );
  final cover = tester.widget<AnimatedScale>(
    find.byKey(const ValueKey('poster-cover-scale-0')),
  );
  expect(card.transform?.getTranslation().y, -6);
  expect(cover.scale, 1.025);
});

testWidgets('减少动态效果时海报卡片保持静止', (tester) async {
  await tester.pumpWidget(
    posterRailUnderTest(disableAnimations: true),
  );

  final mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(
    tester.getCenter(find.byKey(const ValueKey('poster-card-0'))),
  );
  await tester.pump();

  final card = tester.widget<AnimatedContainer>(
    find.byKey(const ValueKey('poster-card-0')),
  );
  final cover = tester.widget<AnimatedScale>(
    find.byKey(const ValueKey('poster-cover-scale-0')),
  );
  expect(card.transform?.getTranslation().y ?? 0, 0);
  expect(cover.scale, 1);
});
```

文件顶部需要已有：

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:weila/theme/app_animations.dart';
```

- [ ] **Step 2: 运行两个测试并确认失败**

Run:

```powershell
flutter test test/artwork_components_test.dart --plain-name "海报卡片悬停时上浮并放大封面"
flutter test test/artwork_components_test.dart --plain-name "减少动态效果时海报卡片保持静止"
```

Expected: FAIL，缺少 `poster-cover-scale-0` 或当前卡片没有最终上浮、缩放参数。

- [ ] **Step 3: 实现最终玻璃装饰与动效**

在 `_PosterRailCardState.build` 中读取主题和减少动态效果：

```dart
final colors = context.colors;
final dark = Theme.of(context).brightness == Brightness.dark;
final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
final visuallyActive = _hovered || _focused;
final animate = !disableAnimations;
```

为 `AnimatedContainer` 使用最终参数：

```dart
duration: animate ? AppAnimations.fast : Duration.zero,
curve: Curves.easeOutCubic,
transform: Matrix4.translationValues(
  0,
  animate && visuallyActive ? -6 : 0,
  0,
),
transformAlignment: Alignment.center,
clipBehavior: Clip.antiAlias,
decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(16),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: dark
        ? [
            colors.paper.withValues(alpha: 0.96),
            colors.bgCard.withValues(alpha: 0.9),
          ]
        : [
            Colors.white.withValues(alpha: 0.96),
            colors.paper.withValues(alpha: 0.9),
          ],
  ),
  border: Border.all(
    color: visuallyActive
        ? colors.sky.withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: dark ? 0.2 : 0.82),
    width: visuallyActive ? 1.4 : 1,
  ),
  boxShadow: [
    BoxShadow(
      color: colors.textPrimary.withValues(
        alpha: visuallyActive ? 0.16 : 0.08,
      ),
      blurRadius: visuallyActive ? 28 : 18,
      offset: Offset(0, visuallyActive ? 13 : 8),
    ),
    BoxShadow(
      color: colors.sky.withValues(
        alpha: visuallyActive ? 0.14 : 0.06,
      ),
      blurRadius: visuallyActive ? 20 : 12,
      offset: const Offset(0, 4),
    ),
  ],
),
```

在封面 `ClipRRect` 内用 `AnimatedScale` 包裹 `CoverImage`：

```dart
AnimatedScale(
  key: ValueKey('poster-cover-scale-${widget.index}'),
  duration: animate ? AppAnimations.fast : Duration.zero,
  curve: Curves.easeOutCubic,
  scale: animate && visuallyActive ? 1.025 : 1,
  child: CoverImage(url: widget.item.imageUrl),
),
```

编号胶囊补齐阴影和文字样式：

```dart
boxShadow: [
  BoxShadow(
    color: colors.textPrimary.withValues(alpha: 0.1),
    blurRadius: 12,
    offset: const Offset(0, 4),
  ),
],
```

```dart
style: Theme.of(context).textTheme.labelSmall?.copyWith(
  color: colors.sky,
  fontWeight: FontWeight.w800,
  letterSpacing: 0.4,
),
```

删除原来的奇偶 `rotateZ`，信息区保持现有 12px padding、标题和 meta 单行省略。

- [ ] **Step 4: 运行组件测试与静态分析**

Run:

```powershell
dart format lib/widgets/artwork_components.dart test/artwork_components_test.dart
flutter test test/artwork_components_test.dart
flutter analyze lib/widgets/artwork_components.dart test/artwork_components_test.dart
```

Expected: 组件测试全部 PASS；分析输出 `No issues found!`。

- [ ] **Step 5: 提交视觉与动效**

```powershell
git add lib/widgets/artwork_components.dart test/artwork_components_test.dart
git commit -m "feat: style seasonal posters as glass magazine cards"
```

### Task 3: 首页响应式与项目级验证

**Files:**
- Test: `test/home_editorial_view_test.dart`
- Test: all files under `test/`

- [ ] **Step 1: 运行首页响应式和交互回归**

Run:

```powershell
flutter test test/home_editorial_view_test.dart
flutter test test/artwork_components_test.dart
```

Expected: 首页 960、1280、1600 宽度测试通过；本季选片点击、滚轮、键盘与卡片状态测试通过。

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

确认 `C:\codex_weila` 指向项目根目录，然后运行：

```powershell
flutter build windows --release
```

Working directory: `C:\codex_weila`

Expected: `Built build\windows\x64\runner\Release\weila.exe`。

- [ ] **Step 5: 核对 Git 状态与提交记录**

Run:

```powershell
git status --short --branch
git log -5 --oneline --decorate
```

Expected: 功能分支工作树干净，包含 Task 1、Task 2 两个实现提交。

### Task 4: 合并并同步

**Files:**
- No source changes

- [ ] **Step 1: 在主工作区抓取远端并确认无分叉**

Run:

```powershell
git fetch origin
git status --short --branch
```

Expected: `master` 无未提交修改，远端没有需要人工解决的分叉。

- [ ] **Step 2: 将功能分支快进合并到 master**

Run:

```powershell
git merge --ff-only codex/seasonal-poster-cards
```

Expected: Fast-forward 成功。

- [ ] **Step 3: 在合并后的 master 上复验**

Run:

```powershell
flutter test
flutter analyze
```

Expected: 所有测试 PASS；分析输出 `No issues found!`。

- [ ] **Step 4: 推送远端 master**

Run:

```powershell
git push origin master
```

Expected: `master -> master`。

- [ ] **Step 5: 清理独立工作树和功能分支**

在主工作区确认功能工作树位于项目的 `.worktrees/` 内，再运行：

```powershell
git worktree remove .worktrees/seasonal-poster-cards
git worktree prune
git branch -d codex/seasonal-poster-cards
```

Expected: 独立工作树和已合并功能分支删除，`master...origin/master` 同步且工作树干净。
