# Liquid Glass Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将薇拉中央五项导航与右侧工具组升级为带共享循环高光、滑动选中镜片和完整键盘支持的 Liquid Glass 刊头。

**Architecture:** 新建纯展示 `LiquidGlassSurface`，只负责静态模糊、玻璃渐变、描边、阴影和由外部进度驱动的高光。`_Masthead` 持有唯一 14 秒控制器和生命周期暂停逻辑，并将同一进度以不同相位传给中央导航、工具组和紧凑入口；路由回调及 `ViraDestination` 保持不变。

**Tech Stack:** Flutter Material、`BackdropFilter`、`AnimationController`、`TickerMode`、Widget tests

---

### Task 1: 共享 Liquid Glass 材质

**Files:**
- Create: `lib/widgets/liquid_glass_surface.dart`
- Create: `test/liquid_glass_surface_test.dart`

- [ ] **Step 1: 写入失败的材质结构测试**

```dart
testWidgets('LiquidGlassSurface 提供静态模糊与可移动高光', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: LiquidGlassSurface(
          motionProgress: 0.25,
          phase: 0.1,
          borderRadius: BorderRadius.circular(24),
          child: const Text('导航'),
        ),
      ),
    ),
  );

  expect(find.byType(BackdropFilter), findsOneWidget);
  expect(find.byKey(const ValueKey('liquid-glass-highlight')), findsOneWidget);
  expect(find.text('导航'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试并确认失败**

Run: `flutter test test/liquid_glass_surface_test.dart`

Expected: FAIL，提示 `liquid_glass_surface.dart` 或 `LiquidGlassSurface` 不存在。

- [ ] **Step 3: 实现纯展示玻璃表面**

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.motionProgress = 0,
    this.phase = 0,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double motionProgress;
  final double phase;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final travel = (((motionProgress + phase) % 1) * 2.4) - 1.2;
    final glassTop = dark
        ? colors.paper.withValues(alpha: 0.82)
        : Colors.white.withValues(alpha: 0.82);
    final glassBottom = dark
        ? colors.bgCard.withValues(alpha: 0.68)
        : colors.paper.withValues(alpha: 0.66);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [glassTop, glassBottom],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: dark ? 0.2 : 0.78),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.24 : 0.1),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: FractionalTranslation(
                    key: const ValueKey('liquid-glass-highlight'),
                    translation: Offset(travel, 0),
                    child: Opacity(
                      opacity: 0.22,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white,
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行材质测试并确认通过**

Run: `flutter test test/liquid_glass_surface_test.dart`

Expected: PASS，1 test passed。

- [ ] **Step 5: 提交共享材质**

```powershell
git add lib/widgets/liquid_glass_surface.dart test/liquid_glass_surface_test.dart
git commit -m "feat: add liquid glass surface"
```

### Task 2: 中央玻璃轨道、滑动镜片与工具组

**Files:**
- Modify: `lib/widgets/vira_page_chrome.dart`
- Modify: `test/vira_page_chrome_test.dart`

- [ ] **Step 1: 写入失败的刊头结构与交互测试**

在 `test/vira_page_chrome_test.dart` 增加：

```dart
testWidgets('刊头使用玻璃导航轨道、选中镜片与玻璃工具组', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: ViraPageScaffold(
        activeDestination: ViraDestination.following,
        onDestinationSelected: (_) {},
        onSearch: () {},
        onThemeToggle: () {},
        onProfile: () {},
        child: const SizedBox(),
      ),
    ),
  );

  expect(
    find.byKey(const ValueKey('vira-navigation-glass')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('vira-nav-lens-following')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('vira-tools-glass')),
    findsOneWidget,
  );
  expect(find.byType(LiquidGlassSurface), findsNWidgets(2));
});

testWidgets('导航可通过键盘触发并保留焦点提示', (tester) async {
  ViraDestination? selected;
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: ViraPageScaffold(
        activeDestination: ViraDestination.home,
        onDestinationSelected: (value) => selected = value,
        onSearch: () {},
        onThemeToggle: () {},
        onProfile: () {},
        child: const SizedBox(),
      ),
    ),
  );

  await tester.tap(find.text('发现'));
  expect(selected, ViraDestination.discover);
  expect(
    find.byKey(const ValueKey('vira-nav-focus-discover')),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: 运行刊头测试并确认失败**

Run: `flutter test test/vira_page_chrome_test.dart`

Expected: FAIL，找不到 `vira-navigation-glass`、`vira-nav-lens-following` 和 `vira-tools-glass`。

- [ ] **Step 3: 将 `_Masthead` 改为共享控制器的有状态组件**

为 `vira_page_chrome.dart` 增加：

```dart
class _Masthead extends StatefulWidget {
  const _Masthead({
    required this.activeDestination,
    required this.onDestinationSelected,
    required this.onSearch,
    required this.onThemeToggle,
    required this.onProfile,
  });

  final ViraDestination? activeDestination;
  final ValueChanged<ViraDestination> onDestinationSelected;
  final VoidCallback onSearch;
  final VoidCallback onThemeToggle;
  final VoidCallback onProfile;

  @override
  State<_Masthead> createState() => _MastheadState();
}

class _MastheadState extends State<_Masthead>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _glassMotion;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _glassMotion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncMotion();
  }

  void _syncMotion() {
    final disable =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final enabled =
        mounted &&
        !disable &&
        tickerEnabled &&
        _lifecycle == AppLifecycleState.resumed;
    if (enabled && !_glassMotion.isAnimating) {
      _glassMotion.repeat();
    } else if (!enabled && _glassMotion.isAnimating) {
      _glassMotion.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glassMotion.dispose();
    super.dispose();
  }
}
```

在 `build` 中使用一个 `AnimatedBuilder`，把 `_glassMotion.value` 同时传给中央轨道、工具组和紧凑导航：

```dart
@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: _glassMotion,
    builder: (context, _) {
      return _buildMastheadLayout(
        context,
        motionProgress: _glassMotion.value,
      );
    },
  );
}
```

`_buildMastheadLayout` 保留当前 `LayoutBuilder`、品牌区和 920px 分界，只替换中央导航与工具组的展示组件。

刊头容器使用固定 72px 高度，并将原纯色装饰改为不参与动画的环境渐变：

```dart
decoration: BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: Theme.of(context).brightness == Brightness.dark
        ? [
            colors.paper.withValues(alpha: 0.96),
            colors.bgCard.withValues(alpha: 0.98),
          ]
        : [
            colors.paper.withValues(alpha: 0.98),
            colors.sky.withValues(alpha: 0.06),
            colors.sakura.withValues(alpha: 0.05),
          ],
  ),
  border: Border(
    bottom: BorderSide(color: colors.divider.withValues(alpha: 0.72)),
  ),
),
```

- [ ] **Step 4: 实现中央轨道与滑动镜片**

新增 `_GlassNavigationRail`，外层使用：

```dart
LiquidGlassSurface(
  key: const ValueKey('vira-navigation-glass'),
  motionProgress: motionProgress,
  phase: 0,
  borderRadius: BorderRadius.circular(24),
  padding: const EdgeInsets.all(5),
  child: SizedBox(
    width: 340,
    height: 42,
    child: Stack(
      children: [
        if (activeDestination != null)
          AnimatedPositioned(
            key: ValueKey(
              'vira-nav-lens-${activeDestination!.name}',
            ),
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            left: ViraDestination.values.indexOf(activeDestination!) * 68,
            top: 0,
            width: 68,
            height: 42,
            child: const _SelectedGlassLens(),
          ),
        Row(
          children: [
            for (final destination in ViraDestination.values)
              _NavigationItem(
                destination: destination,
                selected: destination == activeDestination,
                onTap: () => onSelected(destination),
              ),
          ],
        ),
      ],
    ),
  ),
)
```

`_SelectedGlassLens` 使用白色/天空蓝半透明渐变、内侧白色描边和轻柔蓝色投影。`_NavigationItem` 保持 68×42 稳定尺寸，使用 `InkWell` 与 `Focus`，焦点时增加：

```dart
DecoratedBox(
  key: ValueKey('vira-nav-focus-${destination.name}'),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(17),
    border: Border.all(
      color: focused ? colors.sky : Colors.transparent,
      width: focused ? 1.5 : 0,
    ),
  ),
)
```

- [ ] **Step 5: 实现玻璃工具组和紧凑胶囊**

桌面工具组：

```dart
LiquidGlassSurface(
  key: const ValueKey('vira-tools-glass'),
  motionProgress: motionProgress,
  phase: 0.34,
  borderRadius: BorderRadius.circular(24),
  padding: const EdgeInsets.all(4),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _MastheadTool(
        tooltip: '搜索',
        icon: Icons.search_rounded,
        onTap: widget.onSearch,
      ),
      _MastheadTool(
        tooltip: '切换主题',
        icon: Theme.of(context).brightness == Brightness.dark
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
        onTap: widget.onThemeToggle,
      ),
      _MastheadTool(
        tooltip: '个人与设置',
        icon: Icons.person_outline_rounded,
        onTap: widget.onProfile,
        accent: true,
      ),
    ],
  ),
)
```

紧凑模式将 `_CompactNavigation` 的 `Padding` 外包进 `LiquidGlassSurface`，使用 key `vira-compact-navigation-glass`。弹出菜单逻辑不变。

同时把 `_MastheadTool` 的 `GestureDetector` 改为 `InkWell`，并增加稳定的 `id` 字段。搜索、主题和个人入口分别使用 `search`、`theme`、`profile`；焦点时绘制 key 为 `vira-tool-focus-$id` 的天空蓝外环。这样三个工具均可通过 Tab 聚焦，并由 Enter 或 Space 触发现有回调。

- [ ] **Step 6: 运行刊头测试并确认通过**

Run: `flutter test test/vira_page_chrome_test.dart`

Expected: PASS，现有测试和新增玻璃/键盘测试全部通过。

- [ ] **Step 7: 提交刊头改造**

```powershell
git add lib/widgets/vira_page_chrome.dart test/vira_page_chrome_test.dart
git commit -m "feat: apply liquid glass to masthead navigation"
```

### Task 3: 减少动态效果、响应式与全量验证

**Files:**
- Modify: `test/vira_page_chrome_test.dart`

- [ ] **Step 1: 写入减少动态效果和响应式失败测试**

```dart
testWidgets('减少动态效果时玻璃高光保持静止', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
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

  final before = tester.widget<LiquidGlassSurface>(
    find.byKey(const ValueKey('vira-navigation-glass')),
  );
  await tester.pump(const Duration(seconds: 2));
  final after = tester.widget<LiquidGlassSurface>(
    find.byKey(const ValueKey('vira-navigation-glass')),
  );
  expect(after.motionProgress, before.motionProgress);
});

testWidgets('紧凑宽度使用单一玻璃导航入口', (tester) async {
  await tester.binding.setSurfaceSize(const Size(880, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
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

  expect(
    find.byKey(const ValueKey('vira-compact-navigation-glass')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey('vira-navigation-glass')),
    findsNothing,
  );
});
```

- [ ] **Step 2: 运行测试并确认测试针对真实行为**

Run: `flutter test test/vira_page_chrome_test.dart`

Expected: 如果前一任务遗漏暂停或紧凑玻璃，测试 FAIL；补齐后两项 PASS。

- [ ] **Step 3: 运行定向测试**

Run:

```powershell
flutter test test/liquid_glass_surface_test.dart test/vira_page_chrome_test.dart
```

Expected: PASS，无布局溢出、Ticker 泄漏或待处理定时器。

- [ ] **Step 4: 运行全量验证**

Run:

```powershell
flutter test
flutter analyze
flutter build windows --release
```

Expected:

- 所有测试通过。
- `flutter analyze` 输出 `No issues found!`。
- Windows Release 输出 `Built build\windows\x64\runner\Release\weila.exe`。

- [ ] **Step 5: 截图验收**

启动 Release，分别在 1280×800 和 1600×1000 检查：

- 日间中央玻璃轨道和工具组轮廓清晰。
- 夜间玻璃不透明度足以支撑文字对比。
- 选中镜片滑动不改变导航宽度。
- 14 秒高光缓慢漂移且不抢正文注意力。
- 880px 紧凑模式无溢出。

- [ ] **Step 6: 提交验证补充并推送**

```powershell
git add test/vira_page_chrome_test.dart
git commit -m "test: cover liquid glass navigation states"
git push origin master
```
