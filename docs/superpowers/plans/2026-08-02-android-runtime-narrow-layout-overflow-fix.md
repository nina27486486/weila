# 薇拉 Android 首页主映窄屏溢出修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 API 36 Pixel 7 约 `411x914` 逻辑尺寸下首页“本周主映”文案区底部溢出 45 像素的问题，同时保持桌面端 Hero 布局和所有交互不变。

**Architecture:** 保持 `_EditorialHero` 现有 `1040` 宽度断点和固定外部高度；桌面分支不变，窄屏分支将图片/文案从 `1:1` 调整为 `5:7`，并由 `_HeroCopy.compact` 选择一组明确的紧凑展示常量。先用真实 `HomeEditorialView`、Pixel 7 逻辑尺寸和长标题复现 RenderFlex overflow，再做最小实现；不改 Store、网络、路由或数据格式。

**Tech Stack:** Flutter 3.41.9、Dart 3.11.5、Flutter Widget Test、API 36 Google APIs x86_64 Emulator、PowerShell。

## Global Constraints

- 工作树固定为 `D:\VeraMobile\Workspace\android-mvp`，分支固定为 `codex/android-mvp`。
- 设计依据固定为 `docs/superpowers/specs/2026-08-12-android-runtime-narrow-layout-overflow-fix-design.md`。
- 业务修复只允许修改 `lib/pages/home/home_editorial_view.dart` 和 `test/home_editorial_view_test.dart`。
- 桌面端 `>=1040` 的 Row、高度 `390`、图片/文案 `13:7` 及现有视觉常量不得改变。
- 窄屏 Hero 总高度保持 `660`；只将图片/文案改为 `5:7` 并启用规格定义的紧凑文案参数。
- 不修改 HomeStore、数据源、网络、路由、本地存储、Android runner、版本号、签名或发布配置。
- 持续动画必须继续遵守现有 `TickerMode`、生命周期和 `MediaQuery.disableAnimations` 行为。
- 三份既存 Windows 生成文件差异不得暂存：`windows/flutter/generated_plugin_registrant.cc`、`windows/flutter/generated_plugin_registrant.h`、`windows/flutter/generated_plugins.cmake`。
- 不得使用 `git reset --hard`、`git checkout --`、`git clean`、`flutter clean` 或宽泛删除。
- 不推送、不合并、不升版、不打标签、不创建 Release。
- 手写修改必须使用 `apply_patch`；每次暂存前后都要核对精确文件范围。

---

## File and Interface Map

### 修改文件

- `test/home_editorial_view_test.dart` — 新增真实 Pixel 7 逻辑宽度、20px 页面边距和长标题的回归测试；测试必须先在旧实现上失败。
- `lib/pages/home/home_editorial_view.dart` — 仅调整 `_EditorialHero` 窄屏 flex，并给 `_HeroCopy` 增加必填 `compact` 展示参数和对应常量。

### 保持不变的接口

- `HomeEditorialView` 的公开构造函数与回调不变。
- `_EditorialHero` 的项目选择、自动轮播、打开详情和动画生命周期不变。
- `_HeroCopy` 的 `item`、`selectedIndex`、`itemCount`、`onSelect`、`onOpen` 语义不变。

### 新增内部接口

```dart
const _HeroCopy({
  required this.item,
  required this.selectedIndex,
  required this.itemCount,
  required this.onSelect,
  required this.compact,
  this.onOpen,
});

final bool compact;
```

---

### Task 1: 用 TDD 修复窄屏 Hero 溢出并提交业务修复

**Files:**
- Modify: `test/home_editorial_view_test.dart`
- Modify: `lib/pages/home/home_editorial_view.dart:307-359`
- Modify: `lib/pages/home/home_editorial_view.dart:497-623`

**Interfaces:**
- Consumes: `HomeEditorialView`、`AppTheme.lightTheme`、现有 `_EditorialHero` 宽度断点和 `_HeroCopy` 回调。
- Produces: `_HeroCopy.compact: bool`；窄屏 `image flex: 5` / `copy flex: 7`；提交 `fix(home): prevent narrow hero overflow`。

- [ ] **Step 1: 验证接手边界**

Run:

```powershell
git status --short --branch -uall
git branch --show-current
git rev-parse HEAD
git diff --cached --name-only
$gitDir = git rev-parse --git-dir
if (Test-Path -LiteralPath (Join-Path $gitDir 'index.lock')) { throw 'index.lock exists' }
```

Expected: 分支为 `codex/android-mvp`；HEAD 为本计划文档提交；index 为空；工作区只剩三份既存 Windows 生成文件差异。

- [ ] **Step 2: 写入能捕获真实回归的失败测试**

Use `apply_patch` to append this test inside `main()` in `test/home_editorial_view_test.dart`, before the final closing brace:

```dart
  testWidgets('首页主映在 Pixel 7 逻辑尺寸和长标题下无底部溢出',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final longTitleItems = List.generate(
      4,
      (index) => <String, dynamic>{
        'name': index == 0
            ? '死神千年血战篇－祸进谭－特别放送篇'
            : '主映作品 ${index + 1}',
        'cover': null,
        'status': '更新至第03集',
        'genres': ['剧情', '动作', '动画'],
        'url': 'pixel-hero:$index',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: HomeEditorialView(
              latestItems: longTitleItems,
              seasonalItems: const [],
              trendingItems: longTitleItems,
              continueStories: const [],
              onOpenAnime: (_) {},
              onOpenContinue: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.takeException(),
      isNull,
      reason: 'Pixel 7 窄屏不应产生 RenderFlex overflow',
    );
    expect(find.widgetWithText(FilledButton, '立即播放'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '查看详情'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-hero-selector-3')),
      findsOneWidget,
    );
  });
```

The production mutation this test catches is restoring the narrow branch to equal flex or removing compact density. It exercises the real `HomeEditorialView`, uses literal expected UI, and does not assert on mocks.

- [ ] **Step 3: 运行测试并确认 RED**

Run:

```powershell
flutter test test/home_editorial_view_test.dart --plain-name "首页主映在 Pixel 7 逻辑尺寸和长标题下无底部溢出" -r expanded
```

Expected: FAIL。输出必须包含 `A RenderFlex overflowed`，失败来自 `_HeroCopy` 文案 Column 的底部溢出，而不是语法、fixture、资源或测试环境错误。保存完整输出到 ignored SDD 报告；在看见该正确失败前不得修改生产代码。

- [ ] **Step 4: 实现最小窄屏布局变更**

Use `apply_patch` in `lib/pages/home/home_editorial_view.dart`.

Pass `compact` when constructing `_HeroCopy`:

```dart
          final copy = _HeroCopy(
            item: item,
            selectedIndex: _selectedIndex,
            itemCount: itemCount,
            onSelect: _selectItem,
            onOpen: item == null ? null : _openSelected,
            compact: !horizontal,
          );
```

Change only the narrow Column flex values:

```dart
              : Column(
                  children: [
                    Expanded(flex: 5, child: image),
                    Expanded(flex: 7, child: copy),
                  ],
                );
```

Add the internal field and constructor parameter:

```dart
  final bool compact;

  const _HeroCopy({
    required this.item,
    required this.selectedIndex,
    required this.itemCount,
    required this.onSelect,
    required this.compact,
    this.onOpen,
  });
```

At the start of `_HeroCopy.build`, derive presentation constants:

```dart
    final contentPadding = compact
        ? const EdgeInsets.fromLTRB(20, 20, 20, 16)
        : const EdgeInsets.fromLTRB(30, 30, 30, 24);
    final labelGap = compact ? 14.0 : 22.0;
    final titleGap = compact ? 10.0 : 12.0;
    final genreGap = compact ? 8.0 : 12.0;
    final actionGap = compact ? 12.0 : 16.0;
    final titleSize = compact ? 30.0 : 34.0;
    final titleHeight = compact ? 1.16 : 1.2;
```

Use those values only at the corresponding existing sites:

```dart
      padding: contentPadding,
```

```dart
          SizedBox(height: labelGap),
```

```dart
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: titleSize,
                  height: titleHeight,
                ),
```

```dart
          SizedBox(height: titleGap),
```

```dart
            SizedBox(height: genreGap),
```

```dart
          SizedBox(height: actionGap),
```

Do not alter strings, max lines, ellipsis, callbacks, selector construction, autoplay, desktop Row, heights, or any other section.

- [ ] **Step 5: 运行新增测试并确认 GREEN**

Run:

```powershell
flutter test test/home_editorial_view_test.dart --plain-name "首页主映在 Pixel 7 逻辑尺寸和长标题下无底部溢出" -r expanded
```

Expected: PASS；输出不包含 RenderFlex overflow、Flutter exception 或资源错误。

- [ ] **Step 6: 运行整个首页测试文件**

Run:

```powershell
flutter test test/home_editorial_view_test.dart -r compact
```

Expected: 全部通过，尤其是桌面宽度、主映点击切换、自动轮播和减少动态效果测试。

- [ ] **Step 7: 检查精确差异与代码质量**

Run:

```powershell
dart format --output=none --set-exit-if-changed lib/pages/home/home_editorial_view.dart test/home_editorial_view_test.dart
git diff --check -- lib/pages/home/home_editorial_view.dart test/home_editorial_view_test.dart
git diff --stat -- lib/pages/home/home_editorial_view.dart test/home_editorial_view_test.dart
git diff -- lib/pages/home/home_editorial_view.dart test/home_editorial_view_test.dart
flutter analyze
```

Expected: 格式、whitespace 与 analyze 通过；差异只包含规格定义的 flex、compact 常量和单个测试。

- [ ] **Step 8: 运行全量测试与覆盖率门禁**

Run:

```powershell
flutter test --coverage -r compact
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/check_coverage.dart
```

Expected: 全量测试通过；唯一真实 API 测试保持按设计跳过；全仓覆盖率不低于 70%，发布关键模块不低于 85%。

- [ ] **Step 9: 只暂存业务修复与测试并提交**

Run:

```powershell
git status --short --branch -uall
git diff --cached --name-only
git add -- lib/pages/home/home_editorial_view.dart test/home_editorial_view_test.dart
git diff --cached --check
git diff --cached --stat
git diff --cached --name-status
```

Expected: staged 范围严格为两个 `M` 文件；三份 Windows 生成文件仍未暂存；设计、计划和 D 盘证据不在本提交。

Commit:

```powershell
git commit -m "fix(home): prevent narrow hero overflow"
```

Expected: 单一业务修复提交成功，index 为空。

---

### Task 2: 执行业务修复后的跨平台回归并恢复运行验收

**Files:**
- Read: `lib/pages/home/home_editorial_view.dart`
- Read: `test/home_editorial_view_test.dart`
- Build, ignored: Windows Release 与 Android Debug APK
- Create, local evidence: 当前 D 盘 acceptance run 下的修复回归与 Task 3 重跑证据
- Modify, ignored: `.superpowers/sdd/2026-08-02-android-runtime-acceptance-baseline/task-3-report.md`

**Interfaces:**
- Consumes: Task 1 的 `fix(home): prevent narrow hero overflow` 提交。
- Produces: Windows/Android 构建结果、API 36 两次零输入首页启动证据，以及主运行验收计划 Task 3 的 PASS/BLOCKED 结论。

- [ ] **Step 1: 复核提交和工作区边界**

Run:

```powershell
git show --stat --oneline --summary HEAD
git show --format= --name-status HEAD
git diff --cached --name-only
git status --short --branch -uall
git diff --check
```

Expected: HEAD 是业务修复提交且只含两个文件；index 为空；仅三份 Windows 生成文件差异；diff check 无 whitespace error。

- [ ] **Step 2: 构建 Windows Release**

Run:

```powershell
$junction = 'D:\VeraMobile\Temp\weila_windows_build_src'
if (Test-Path -LiteralPath $junction) { throw "Windows build junction already exists: $junction" }
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_windows_release.ps1 -JunctionPath $junction -SkipClean
```

Expected: Release 构建退出 0；使用显式 ASCII junction；不运行 clean；脚本完成后不遗留该临时 junction。

- [ ] **Step 3: 构建 Android Debug APK**

Run:

```powershell
$env:GRADLE_USER_HOME = 'D:\VeraMobile\Android\GradleHome'
flutter build apk --debug --target lib/main_android.dart --no-pub
$apk = Get-Item -LiteralPath 'build\app\outputs\flutter-apk\app-debug.apk'
$hash = Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256
$apk | Select-Object FullName, Length, LastWriteTime
$hash
```

Expected: build exit 0；APK 非零；记录新字节数和 SHA-256；不出现 non-ASCII path、SDK whitespace 或 RenderFlex 构建错误。

- [ ] **Step 4: 从主计划 Task 3 的干净安装步骤恢复验收**

Use the exact AVD, package, launch, evidence-preservation, animation-scale recovery and input-isolation rules already established in:

- `docs/superpowers/plans/2026-08-02-android-runtime-acceptance-baseline.md` Task 3 Steps 3–9.
- `.superpowers/sdd/2026-08-02-android-runtime-acceptance-baseline/task-3-retry-brief.md`.

Required concrete sequence:

1. 启动或验证唯一可见 `Weila_API_36_Google_APIs`，必须 `sys.boot_completed=1`。
2. 精确卸载 `io.github.nina27486486.weila`，安装新 APK，并验证设备 `base.apk` SHA-256 与本地一致。
3. 零输入冷启动，15 秒立即抓取首页 PNG；用 `view_image` 原始分辨率目检。
4. 若 UIAutomator 因持续动画无法 idle，保存原始错误和三项 animation scale；临时设为 0 只用于 XML dump，随后恢复并逐项复核原值。
5. force-stop 目标包后零输入第二次启动，10 秒立即抓取第二张首页 PNG/XML并目检。
6. 两轮均收集 app/crash/exit-info；扫描 `FATAL EXCEPTION|ANR in io\.github\.nina27486486\.weila|Unhandled Exception|FlutterError|Lost connection to device|A RenderFlex overflowed|BOTTOM OVERFLOWED`。

Expected: 两次截图都是 `/` 首页；无 splash、白屏、分类页、崩溃框或黄黑 overflow 条；PID 存活；XML 包含“首页”“搜索”，不包含“正在翻阅片库”；阻塞扫描无命中。

- [ ] **Step 5: 更新 ignored Task 3 报告与 SDD ledger**

Use `apply_patch` to update the ignored Task 3 report with:

- 旧分类截图的延迟采集误分类结论。
- 修复前第二轮 `BOTTOM OVERFLOWED BY 45 PIXELS` 证据。
- 修复提交哈希与精确两文件范围。
- Windows/Android 构建结果。
- 修复后两次启动时间、APK hash、PNG/XML、进程和日志扫描结论。
- 若所有条件通过，将 Task 3 状态改为 PASS；否则保留 BLOCKED 并写首个真实失败条件。

Append the same PASS/BLOCKED boundary to `.superpowers/sdd/2026-08-02-android-runtime-acceptance-baseline/progress.md`. Both files remain ignored and must not enter Git.

- [ ] **Step 6: 最终核对并返回主运行验收计划**

Run:

```powershell
git log --oneline -5
git diff --cached --name-only
git status --short --branch -uall
git diff --check
```

Expected: 没有额外提交；index 为空；工作区只剩三份预期 Windows 生成文件差异。Task 3 PASS 时返回主计划 Task 4；仍 BLOCKED 时保留全部证据并停止，不猜测新修复。

---

## Final Review Requirements

在恢复主计划 Task 4 前，必须完成：

1. Task 1 的规格符合性审查：逐条对照已批准设计，确认桌面分支不变、窄屏只采用 `5:7 + compact`、测试先红后绿、提交范围正确。
2. Task 1 的代码质量审查：检查真实响应式行为、可读性、无魔法分支扩散、测试能捕获回退、动画和回调无回归。
3. Task 2 的验证审查：独立复核 Windows/Android 构建与两次 API 36 首页截图/日志，不接受实施者自述代替证据。
4. 全分支审查：从 `eb60059` 之后检查计划和业务修复提交，没有推送、合并、版本、标签或 Release 副作用。
