# 薇拉 Android 首页主映窄屏溢出修复设计

## 背景与已确认根因

API 36 Google APIs x86_64 Pixel 7 验收设备在 `1080x2400`、密度 `420` 下，以约 `411` 逻辑像素宽度显示首页。第二次零输入启动稳定进入 Modular 路由 `/`，应用进程持续存活，日志无崩溃或 ANR，但首页“本周主映”卡片底部出现 Flutter 黄黑警示条：`BOTTOM OVERFLOWED BY 45 PIXELS`。

问题归属 `lib/pages/home/home_editorial_view.dart` 的 `_EditorialHero` 与 `_HeroCopy`。当前窄屏分支将固定 `660` 高度平均分给图片与文案：

```dart
Column(
  children: [
    Expanded(child: image),
    Expanded(child: copy),
  ],
)
```

扣除环境卡片内边距后，文案区约有 `320` 逻辑像素，却必须容纳章节标签、最多三行标题、状态、题材、两枚操作按钮和主映选择器。真实长标题使文案 Column 超出约束 45 像素。桌面横向 Hero 不受影响。

## 目标

- 在 Android 验收尺寸约 `411x914` 逻辑像素下完整显示首页主映文案、操作按钮和选择器，不出现 RenderFlex overflow。
- 保持桌面端 `>=1040` 宽度的横向布局、`390` 高度、`13:7` 图片/文案比例和现有视觉参数不变。
- 保持窄屏 Hero 外部总高度 `660` 不变，避免无关地改变首页后续章节位置与滚动节奏。
- 保留主映自动轮播、手动选择、立即播放、查看详情、环境取色、动画生命周期和减少动态效果行为。
- 用能复现真实 Pixel 7 约束与长标题的失败测试证明修复有效。

## 非目标

- 不修改首页数据源、HomeStore、网络请求、路由或本地存储。
- 不重新设计首页视觉语言，不改变桌面端 Hero。
- 不处理 Jikan 504；它是独立的外部服务风险。
- 不修改 Android runner、AVD、SDK、版本号、签名或发布配置。
- 不借机重构整个 `home_editorial_view.dart` 或其他首页章节。

## 方案比较

### 方案 A：窄屏重新分配高度并启用紧凑文案密度（采用）

窄屏 Column 将图片与文案从 `1:1` 改为 `5:7`，把约 `373` 逻辑像素分配给文案。`_HeroCopy` 接收明确的 `compact` 展示参数；仅窄屏使用更小的内边距、段间距和标题字号，桌面端沿用原值。

优点：修改集中、行为边界清楚、桌面视觉零变化；固定 Hero 高度不变；真实长标题和默认 Android 字体缩放下有余量。缺点：仍是受约束的杂志卡片，不承诺任意极端系统字号都能展示所有三行标题。

### 方案 B：只把窄屏 Hero 高度从 `660` 增大

优点：实现最少。缺点：会推迟所有后续首页章节；对更长标题或字体缩放仍脆弱；没有修正文案与图片在手机上的不合理等分。

### 方案 C：改为内容驱动的无限制自适应高度

优点：理论上最灵活。缺点：`AmbientArtworkBackdrop` 使用 `StackFit.expand`，需要有界尺寸；改造会影响环境背景、切换动画和首页整体节奏，超出本轮单一缺陷范围。

## 详细布局设计

### 响应式边界

继续以 `_EditorialHero` 当前的 `constraints.maxWidth >= 1040` 作为唯一桌面/窄屏分界：

- 横向布局：维持现状，图片 `flex: 13`、文案 `flex: 7`、Hero 高度 `390`，`compact: false`。
- 窄屏布局：保持 Hero 高度 `660`，图片 `flex: 5`、文案 `flex: 7`，`compact: true`。

### 紧凑文案参数

`_HeroCopy` 新增必填 `bool compact`。参数只控制展示密度，不改变文案、按钮回调或选择器逻辑。

窄屏使用：

- 容器内边距：`EdgeInsets.fromLTRB(20, 20, 20, 16)`。
- 章节标签后的间距：`14`。
- 标题字号与行高：`30`、`1.16`，仍为最多三行并使用省略号。
- 标题后间距：`10`。
- 状态后题材间距：`8`。
- 操作按钮后间距：`12`。

桌面端继续使用当前 `30/30/30/24` 内边距、`34` 标题字号和现有所有间距。

按钮仍保持一行，因为 Pixel 7 可用文案宽度在新的左右内边距下足够容纳当前两枚按钮。选择器仍位于文案区底部；`Spacer` 保留，用剩余空间维持杂志式留白。

## 数据与交互流

首页数据、选中项和回调流不变：

1. `_EditorialHeroState` 选择当前主映项目。
2. 父级 LayoutBuilder 根据宽度决定 `horizontal`。
3. 同一决定同时控制 Row/Column、flex 和 `_HeroCopy.compact`。
4. `_HeroCopy` 只选择布局常量；播放、详情、选择器回调仍原样向上传递。

不新增状态，不持久化新数据，也不引入依赖。

## 测试设计

在 `test/home_editorial_view_test.dart` 增加一个真实组件测试，名称为“首页主映在 Pixel 7 逻辑尺寸和长标题下无底部溢出”。

测试环境：

- Surface：`Size(411, 914)`。
- 用 `Padding(horizontal: 20)` 模拟 `ViraPageScaffold` 在窄屏下的真实内容边距，使 Hero 可用宽度约为 `371`。
- 使用完整 `HomeEditorialView`，不 mock `_EditorialHero` 或 `_HeroCopy`。
- 主映数据使用足以稳定复现三行标题的字面量，例如 `今天，继续\n死神千年血战篇－祸进谭－特别放送。`，并提供非空状态和三个题材。
- 首次运行必须在旧实现上通过 `tester.takeException()` 捕获 RenderFlex overflow，证明测试进入正确失败分支。
- 实现后要求 `tester.takeException()` 为 `null`，并断言“立即播放”“查看详情”和最后一个主映选择器仍存在。

现有 `960/1280/1600` 无溢出测试继续保护桌面与平板宽度。修改生产代码后至少运行：

```powershell
flutter test test/home_editorial_view_test.dart -r compact
flutter analyze
flutter test --coverage -r compact
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/check_coverage.dart
```

随后按总验收计划执行 Windows Release 构建、Android Debug APK 构建，并从 Task 3 的干净安装步骤重跑两次首页启动证据。

## Git 与安全边界

业务修复提交只允许包含：

- `lib/pages/home/home_editorial_view.dart`
- `test/home_editorial_view_test.dart`

独立设计和实施计划各自作为文档提交，不与业务修复揉在一起。三份既存 Windows Flutter 生成文件换行差异不得暂存。不得 push、merge、升版、打标签、创建 Release，也不得使用 reset、checkout、clean 或 `flutter clean`。

原始 Android 截图、日志、VM Service 对象图和本机路径继续只留在 D 盘验收目录；可提交文档不得包含秘密、凭据、Cookie、Header、代理认证或签名材料。

## 成功标准

- 新测试在旧代码上因底部 RenderFlex overflow 失败，并在最小实现后通过。
- 首页主映在 `411x914`、约 `371` 内容宽度下不溢出，按钮和选择器保留。
- 现有首页测试、全量 Flutter 测试、覆盖率门禁和 analyze 通过。
- Windows Release 与 Android Debug APK 均成功构建。
- API 36 Pixel 7 上两次零输入启动均显示首页，第二轮不再出现 `BOTTOM OVERFLOWED` 黄黑条。
- Git 提交边界精确，最终 index 为空，工作区只剩三份预期 Windows 生成文件换行差异。
