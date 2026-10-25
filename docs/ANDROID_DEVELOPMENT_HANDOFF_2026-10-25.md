# 薇拉 Android 开发交接：移动壳、全屏与播放诊断

整理日期：2026-10-25  
适用分支：`codex/android-mvp`  
交接基线：`91b23a6` + 当前工作区未提交改动

> **先读本文件。** [原 Android 交接文档](ANDROID_HANDOFF.md)保留历史背景，但其中“尚无底部导航、没有 600/840、全屏仍为 Noop、阶段 A 未完成”等描述已经过时。不要照旧提示词重新实现阶段 A。
>
> 本次只整理文档，不继续开发、不重新运行全量测试、不提交或推送。下文测试和设备结果是本会话上一轮工程收尾记录；整理时已复核日志、截图、关键源码和 Git 状态。

## 1. 30 秒了解当前状态

| 事项 | 当前结论 |
|---|---|
| Android MVP 基础 | 双入口、平台抽象、能力门控已有；历史版本在 arm64 真机播放过真实 HLS |
| 阶段 A：移动壳 | 已实现 600/840 断点、窄屏底栏、导航均分及四档外壳测试 |
| Android 全屏与返回 | 已接入 SystemChrome；面板 → 抽屉 → 全屏 → 页面分层返回 |
| 下载依赖隔离 | 已完成，Android 入口不依赖 DownloadService 或 Windows 专属实现 |
| Android 渲染失败诊断 | 已修复本轮复现的“视频输出初始化失败，却记为首帧成功” |
| 模拟器黑屏本身 | **未修复**；已定位旧 native mpv 与模拟器 EGL 属性兼容问题 |
| 真实网络播放中断 | **根因未确定**，不能直接归因于模拟器 EGL 问题 |
| 最新工程验证 | 528 项测试通过、1 项按设计跳过；analyze 零问题；Android debug APK 构建成功 |
| 真机回归缺口 | 新诊断改动后，尚未在 arm64 真机复测正常播放路径 |
| 移动页面重排 | 首页、详情、播放器独立移动排版**尚未开展，不在已批准范围内** |
| Git | 全部本轮开发改动仍未提交；暂存区为空；未合并、未推送 |

**下一步优先建议：在 arm64 真机验证新诊断不会误伤正常播放，再明确选择网络中断调查、native 兼容修复或移动排版中的一个独立任务。此建议不是自动扩展开发权限。**

## 2. 唯一工作区与阅读顺序

```text
C:\Users\nina\Desktop\自己vibe coding玩玩\薇拉\.worktrees\android-mvp
```

- 当前分支：`codex/android-mvp`，跟踪 `origin/codex/android-mvp`。
- HEAD：`91b23a6 docs(android): 360dp overflow family cleared on device`。
- 不切换到原仓库根目录，不从主工作区判断 Android 实现情况。
- 移动壳、下载隔离、全屏和本轮诊断修复主要都在未提交文件中；仅查看 HEAD 或远端会漏掉这些工作。
- 对主人默认用中文，称呼“主人”，工具操作前说明目的。

接手阅读顺序：

1. 本文件。
2. [AGENTS.md](../agents.md)。
3. [ANDROID_MVP_PLAN.md](ANDROID_MVP_PLAN.md)：产品边界与长期计划。
4. [ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md](ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md)：较早模拟器和真机验收。
5. [PROJECT_HANDOFF.md](../PROJECT_HANDOFF.md)：项目整体历史背景；其中旧问题不能当作当前 Android 状态。
6. 根据所选任务阅读第 5 节关键代码，而不是一次性重读全仓。

## 3. 授权边界与不可触碰项

### 3.1 主人明确要求保留的硬约束

- “不要让 main_android.dart 的导入图接触 window_manager / win32 / WindowsDanmakuCredentialStore / DownloadService”
- “不打开明文 HTTP，usesCleartextTraffic 保持 false”
- “不改 Windows 桌面布局与窗口行为”
- “不修改 *_page.dart 里的业务逻辑，改动放在 *_view.dart 或 lib/widgets/mobile/”
- “不使用 git reset --hard / git checkout --”
- “不自行 commit 或 push”
- “不提交 android/gradle.properties 与 windows/flutter/generated_* 构建产物”
- “首页/详情/播放器的移动排版不在本次范围，不要提前做。”

### 3.2 已获得的有限例外

1. 下载依赖隔离作为阶段 A 的前置修补，且播放器、设置页的两处接线调整已单独获批。
2. 最近一次工程授权是“只修诊断误报”：允许局部播放器页面 Android 诊断接线及回归测试，明确报告渲染失败，**不替换原生库、不改 Windows 行为**。
3. 该例外不等于允许普遍重构播放业务，也不等于修复模拟器画面。
4. 最新请求仅为整理交接文档；没有追加 native 升级、移动重排、发布或提交授权。

### 3.3 持续安全要求

- 不读签名配置、keystore、凭据；不上传 Cookie、完整媒体 URL、原始验收日志。
- 不覆盖、回滚或清理用户原有未提交文件；不全仓格式化、不随手重生成文件。
- 不新增产品依赖，不擅改 Store、Service、路由或持久化格式；必要改动先说明影响并确认范围。
- Flutter 原生实现，播放器视频舞台保持纯黑；持续动画考虑 TickerMode、生命周期和 disableAnimations。
- 临时探针、合成视频和运行证据放在被忽略的 `.dart_tool/shell_preview/`，不混入正式入口或提交。
- 不将 metadata、播放进度、媒体库的首帧 Future 或 `vo-configured=yes` 单独当作屏幕已显示画面的证明。
- UI 改动需实际运行并交互验证；浏览器组件验收不能替代 Android 原生视频验收。

## 4. 已完成的工作与用户可见变化

### 4.1 下载依赖隔离

- 新增纯回调载体 `PlayerDownloadActions`；Windows 入口构造 DownloadService，注入下载动作、设置配置回调及下载页 builder。
- 共用启动器和 AppModule 接收这些可选注入，不直接导入 DownloadService。
- Android 不注入下载服务，能力仍为 `downloads=false`、`pluginEditing=false`、`secureCredentialStorage=false`。
- Android 隐藏下载入口；Windows 保留下载功能。不要仅隐藏 UI 却重新把 Windows 依赖拉回 Android 导入图。

### 4.2 阶段 A：移动壳

| 宽度 | 实际布局 |
|---|---|
| <600dp | 顶部品牌/工具区 + 底部导航；Android 为首页、发现、追番、资料库四项 |
| 600–839dp | 紧凑顶部导航，隐藏品牌文字；**无底栏** |
| ≥840dp | 宽屏顶部导航，保留桌面视觉组合 |

- `AdaptiveScaffold` 是**共享、按宽度决定的布局**，不是独立的 Windows/Android 两套导航组件。
- `_GlassNavigationRail` 是现有顶部导航组件的名称，不代表新增了侧边 Material NavigationRail。
- Windows 正常最小窗口宽度 960，使用宽屏组合，仍有五项导航；窗口控制器未改。
- 移除窄屏 PopupMenuButton 导航分支，导航项改为容器内 Expanded 均分。
- 测试覆盖 360/411/600/840、深浅主题、2 倍字体、安全区、横屏键盘、无当前项与跨断点正文状态保持。
- 这些是外壳和已测组件的覆盖，**不是全 App 所有页面都已完成移动排版或全量视觉验收**。

### 4.3 全屏、返回与抽屉关闭

- Android 进入全屏：`landscapeLeft` + `landscapeRight`，`immersiveSticky`。
- Android 退出全屏：方向恢复 `[]`，系统栏恢复 `edgeToEdge`；不是强制竖屏。
- SystemChrome 请求串行执行，同向在途请求合并，避免连续点击导致状态交错。
- 返回顺序：面板 → 集数抽屉 → 全屏 → 页面路由；顶栏返回和系统返回一致。
- 显式 `_exitFullscreen`，成功恢复系统状态后才清 `_isFullscreen`，不使用 toggle 代替退出。
- Android 抽屉关闭从 easeOutBack 改为 easeOutCubic，修复负宽导致的红屏；展开及 Windows 曲线保留。
- API36 当前模拟器已实测横屏与系统栏隐藏，不能外推到所有 API36 设备或平板。
- **抽屉展开仍固定 220 宽、可能挤压窄屏正文；此布局问题未在本轮处理。**

### 4.4 Android 渲染失败诊断

之前 metadata + 正播放进度即可记首帧；即使 EGL/video output 初始化失败，也可能显示播放成功、走无效自动恢复。

现在仅 Android 增加原生输出门槛：

```dart
await native.getProperty('vo-configured') == 'yes'
```

- metadata、正进度和输出已配置都满足后，才允许首帧证据通过。
- 首帧查询同代次最多一个在途；false/异常后靠后续 metadata/position 事件重试，没有新增 Timer 轮询。
- 每次 open 重置门槛，即使切集复用同一原生输出，也会重新查询。
- 精确识别 error/fatal 级的两种最终失败：`vo/gpu` 的 GPU context 初始化失败，或 `cplayer` 的 video_out 初始化失败。
- 单条 GLES context 创建失败、warn 或解码 fallback 不直接视为最终失败。
- 每次 open 重建日志订阅并捕获 generation；确认错误时重查输出，await 后再验证 generation/dispose。
- 当前输出已配置时忽略晚到错误；确认失败后释放首帧等待者，但 `firstFrameEvidenceReady` 保持 false。
- 取消 watchdog/待执行重连；页面废弃在途播放请求和集数加载代次，防止异步解析晚到后再次打开。
- 直接展示“视频画面渲染失败”，不走自动换源；用户仍可手动重新加载。
- 错误面板不再显示“已尝试自动恢复”，改为设备/视频输出兼容性提示；其他故障默认文案不变。
- 原生日志只写固定 `video_output_init_failed failure_kind=noVideo`，不输出原始错误文本或媒体 URL。
- Windows 不传输出查询回调，保留原首帧判定路径。未改 diagnostics 服务、enum 或本地报告格式。

## 5. 接手代码地图

以下行号在整理时核对；后续编辑会移动，必要时按符号搜索。

| 文件 / 位置 | 重点 |
|---|---|
| [lib/layout/breakpoints.dart:3](../lib/layout/breakpoints.dart#L3) | compact=600、medium=840，宽度分类 |
| [lib/layout/adaptive_scaffold.dart:23](../lib/layout/adaptive_scaffold.dart#L23) | 仅 compact 底栏，SafeArea 与正文稳定挂载 |
| [lib/widgets/vira_page_chrome.dart:65](../lib/widgets/vira_page_chrome.dart#L65) | 按能力过滤导航项并接入共享壳 |
| [lib/widgets/vira_page_chrome.dart:186](../lib/widgets/vira_page_chrome.dart#L186) | 三档顶部组合；底栏在 637 行起 |
| [lib/platform/player_download_actions.dart:3](../lib/platform/player_download_actions.dart#L3) | 三个下载回调，不依赖具体服务 |
| [lib/main.dart:29](../lib/main.dart#L29) | Windows 下载服务及动作注入 |
| [lib/main_android.dart:9](../lib/main_android.dart#L9) | AndroidFullscreenController，无下载注入 |
| [lib/bootstrap/app_launcher.dart:17](../lib/bootstrap/app_launcher.dart#L17) | 共用启动器接收下载回调/builder |
| [lib/app_module.dart:32](../lib/app_module.dart#L32) | 能力与注入约束，条件注册下载路由 |
| [lib/platform/android_fullscreen_controller.dart:11](../lib/platform/android_fullscreen_controller.dart#L11) | 串行请求与系统 UI 恢复 |
| [lib/widgets/mobile/player_back_scope.dart:23](../lib/widgets/mobile/player_back_scope.dart#L23) | 顶栏与系统返回分层 |
| [lib/pages/player/widgets/player_page_view.dart:167](../lib/pages/player/widgets/player_page_view.dart#L167) | 显式退出全屏；392 行起接入返回 scope |
| [lib/pages/player/widgets/episode_sidebar.dart:22](../lib/pages/player/widgets/episode_sidebar.dart#L22) | Android 关闭抽屉曲线修补 |
| [lib/pages/player/player_playback_lifecycle_coordinator.dart:16](../lib/pages/player/player_playback_lifecycle_coordinator.dart#L16) | 错误确认；71 行首帧门槛；205 行起输出查询 |
| [lib/pages/player/player_page.dart:91](../lib/pages/player/player_page.dart#L91) | Android 原生输出回调；411 行订阅；537 行首帧保护；590 行失败处理 |
| [lib/pages/player/widgets/player_page_view.dart:684](../lib/pages/player/widgets/player_page_view.dart#L684) | 向展示组件传递 videoOutputInitializationFailed |
| [lib/pages/player/widgets/player_diagnostics_overlay.dart:13](../lib/pages/player/widgets/player_diagnostics_overlay.dart#L13) | 新展示字段；316/375 行按故障类别显示标签/建议 |
| [android/app/src/main/AndroidManifest.xml:11](../android/app/src/main/AndroidManifest.xml#L11) | usesCleartextTraffic=false，未更改 |

相关测试：

- `test/platform/download_wiring_test.dart`、`test/platform/android_source_boundary_test.dart`：下载接线及 Android 导入边界。
- `test/vira_page_chrome_test.dart`：四档外壳、字体、安全区、导航、状态保持。
- `test/platform/platform_controllers_test.dart`、`test/platform/player_back_scope_test.dart`：SystemChrome 与分层返回。
- `test/player_episode_sidebar_test.dart`：抽屉逐帧关闭，不出现负宽。
- `test/pages/player/player_playback_lifecycle_coordinator_test.dart`：共 19 项，其中本轮新增 13 项，覆盖输出门槛、错误过滤、旧代次、dispose、重复错误、手动 reopen、桌面默认路径；含真实 PlaybackDiagnosticsSession 断言。
- `test/platform/player_platform_boundary_test.dart`：本轮新增 3 项诊断接线断言；它们主要检查源码边界，不是完整页面运行测试。
- `test/player_diagnostics_overlay_test.dart`：本轮新增 1 项输出初始化失败文案测试。

诊断轮新增 17 项测试，全量计数由前阶段 511 增至 528。

## 6. 黑屏调查：已证实什么，没证实什么

### 6.1 环境与依赖

| 项目 | 本轮环境 |
|---|---|
| Flutter / Dart | 3.41.9 / 3.11.5 |
| media_kit | 1.2.6 |
| media_kit_video | 2.0.1 |
| media_kit_libs_android_video | 1.3.8 |
| native mpv 标识 | `v0.36.0-549-g78d43740f5-dirty` |
| 模拟器 | Weila_API_36_Google_APIs，emulator-5554，API36，x86_64 |
| 模拟器屏幕 | 1080×2400、420dpi，约 411dp 宽 |
| 较早真机 | vivo V2505A，Android16/API36，arm64-v8a，1440×3168@640dpi，360dp |

### 6.2 已做对照，不要无理由重做

用本地合成 H264/AAC 视频排除网络和产品页面布局：

| 图形后端 | 解码设置 | 观察 |
|---|---|---|
| 默认 | 强制 auto-safe | 黑屏 |
| 默认 | 库默认软件解码 | 黑屏 |
| SwiftShader | 强制 auto-safe | 黑屏 |
| SwiftShader | 软件解码 | 黑屏 |

四组都能推进到 6 秒，但 native screenshot=null、current-vo 为空。最终错误为 GPU context / video_out 初始化失败，不能因为进度推进就说有画面。

EGL 单变量实验：同一 Display、Config1、GLES2，EGL1.4 且声明 KHR 扩展。

- 带 `EGL_CONTEXT_FLAGS_KHR, 0`：3/3 失败，`0x3004 / EGL_BAD_ATTRIBUTE`。
- 去掉该属性：3/3 成功，`0x3000 / EGL_SUCCESS`。
- 已查阅新版 mpv 中不带 flags 重试的实现，**但没有升级或 patch 产品 native 库**。

这些支持当前旧库与此模拟器之间存在 EGL 属性兼容问题；不证明所有 Android 黑屏同因，更不能证明真实网络中断同因。

### 6.3 误报来源与残余限制

- media_kit_video 2.0.1 Android 的 `waitUntilFirstFrameRenderedCompleter` 可在 videoParams 尺寸更新时完成，早于 EGL 最终失败。
- media_kit 的 stream.log 能接到 fatal 和 vo/gpu 日志，但 stream.error 仅转发部分 prefix/级别，可能漏掉这些输出错误。
- `PlaybackDiagnosticsSession.fail()` 不撤销已记首帧；本轮在页面/协调器源头阻止误记，没有修改服务格式。
- **vo-configured 是必要门槛，不是可见像素的充分证据**。独立 `vo=null` 探针也返回 `yes`，它只验证原生属性字符串格式；产品仍是原 GPU 输出和 auto-safe 配置。
- 原生日志没有 mediaId。当前保护可过滤部分旧日志，但若旧日志在新 open 尚未配置输出时晚到，仍可能误归属。不得声称已完全解决跨代次归属。
- 本轮保证的是已复现“输出初始化失败误记成功”这一类，不是所有渲染失败、网络失败或首帧测量问题的总修复。

## 7. 验证记录与证据边界

### 7.1 上一轮工程收尾结果

| 验证 | 结果 | 不能据此宣称 |
|---|---|---|
| `flutter test --no-pub` | 528 通过、1 跳过 | 所有真机/网络场景已覆盖 |
| `flutter analyze --no-pub` | No issues found | 原生播放必然正常 |
| `flutter build apk --debug -t lib/main_android.dart --no-pub` | 构建成功 | 已签名发布或可上架 |
| `git diff --check` | 通过，仅见 CRLF 转换提示 | 用户原有改动可丢弃 |
| 四档外壳测试/预览 | 360/411/600/840；明暗、放大字体等已测 | 全 App 移动重排已完成 |
| 四档诊断 Web 组件 | retry/copy/back 可用，旧分支未变，console errors=[] | Android 视频已实际渲染 |
| API36 实际 PlayerPage 探针 | 本地视频首播及手动重试准确失败，不误记首帧、不自动循环 | 模拟器黑屏已修 |
| 正式产品 APK 恢复 | 重新按 main_android 构建、install -r、冷启动成功，有正式首页截图 | arm64 最新回归通过 |
| Windows | 默认诊断路径、展示分支与平台测试通过，审查未发现行为变化 | 本轮已重新构建并启动 Windows Release；**本轮未做这项实机验收** |

唯一跳过项：`test/services/danmaku/dandanplay_live_test.dart`，需 `DANDANPLAY_LIVE_TEST=1`。未开启，避免消耗真实 API 额度及凭据使用。

模拟器安全报告摘录：

| 字段 | 初次打开 | 手动重新加载 |
|---|---|---|
| stage | failed | failed |
| firstFrameRendered | false | false |
| firstFrameMs | null | null |
| failureKind | noVideo | noVideo |
| automaticRecoveryCount | 0 | 0 |
| playedDurationMs | 249 | 0 |

日志共两次固定输出失败事件，对应首播一次、手动重试一次；采样中未见自动无限重开或 Flutter 未处理异常。已完成两轮只读代码审查，首轮发现的旧日志与在途恢复问题已补测试和修补；仍保留第 6.3 节限制。

### 7.2 本机证据位置

忽略目录 `.dart_tool/shell_preview/` 中保留：

| 文件 | 用途 |
|---|---|
| `browser-results.json`、`phone-360.png`、`windows-1280.png` | 移动壳和宽屏预览 |
| `fullscreen-browser-results.json`、`api36-final-fullscreen.png`、`api36-final-exit.png` | 返回/全屏验收 |
| `decoder-*-log.txt`、`decoder-*-screen.png` | 四组解码/图形对照；原始日志仅本机按需脱敏阅读 |
| `egl_attribute_probe.c`、`egl-attribute-result.txt` | EGL 单变量实验代码/结果 |
| `mpv-egl-0.40-reference.c` | 只读上游实现参考，不是产品源码补丁 |
| `diagnostics-page-final.png`、`diagnostics-page-retry.png` | 实际产品 PlayerPage 错误展示 |
| `diagnostics-page-final-log.txt`、`diagnostics-page-retry-log.txt` | 模拟器安全字段与运行记录，不整份上传 |
| `native-flag-check.txt` | vo=null 字符串格式探针，不是成功渲染证据 |
| `diagnostics-browser-results.json`、`diagnostics-browser-{360,411,600,840}.png` | 四档真实诊断展示组件的浏览器交互 |
| `product-restored-after-diagnostics.png` | 最后已恢复正式产品首页 |
| `.dart_tool/shell_preview/lib/decoder_probe_main.dart`、`.dart_tool/shell_preview/lib/diagnostics_page_probe_main.dart` | 此行写出完整项目相对路径；独立 Android 探针，不在产品 lib/ 下 |
| `.dart_tool/shell_preview/lib/diagnostics_web_main.dart`、`verify_diagnostics_browser.py` | 独立 Web 展示组件验收宿主与脚本，均在忽略目录下 |

上一轮命令输出根目录：

```text
C:\Users\nina\AppData\Local\Temp\qoder-cli\C--Users-nina-Desktop---vibe-coding-------worktrees-android-mvp\9ab3691d-2435-4a55-9d06-944eeedb34fb\tasks\
```

- `b2w1p9bx9.output:666`：528 通过、1 跳过；669 行 analyze；674 行 APK 构建。
- `b1mrm1e2u.output`：最后正式 APK 重建、安装、冷启动，Status=ok，TotalTime=5009ms。
- 临时路径仅在本机有效，可能被系统清理；其他机器接手应复验，不把文件缺失当作产品缺陷。
- 无需重新读取审查代理完整会话或轮询已结束任务。

## 8. 未提交改动与归属

交接整理前复核：暂存区为空，分支与 HEAD 未变。不要使用 `git add .` 打包所有改动。

### 8.1 原有本地文件，勿覆盖或提交

- `android/gradle.properties`
- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugin_registrant.h`
- `windows/flutter/generated_plugins.cmake`
- `design.md.format-design-md.canvas.data.json`：用户原有未跟踪文件。
- `docs/ANDROID_HANDOFF.md`：用户原有未跟踪文档；本次仅在开头加最新交接入口，旧正文保留。

### 8.2 累计产品与测试改动

```text
M  lib/app_module.dart
M  lib/bootstrap/app_launcher.dart
M  lib/main.dart
M  lib/main_android.dart
M  lib/pages/player/player_page.dart
M  lib/pages/player/player_playback_lifecycle_coordinator.dart
M  lib/pages/player/widgets/episode_sidebar.dart
M  lib/pages/player/widgets/player_diagnostics_overlay.dart
M  lib/pages/player/widgets/player_page_view.dart
M  lib/pages/settings/settings_page.dart
M  lib/widgets/vira_page_chrome.dart
M  test/pages/player/player_playback_lifecycle_coordinator_test.dart
M  test/platform/android_source_boundary_test.dart
M  test/platform/platform_controllers_test.dart
M  test/platform/player_platform_boundary_test.dart
M  test/player_diagnostics_overlay_test.dart
M  test/player_episode_sidebar_test.dart
M  test/vira_page_chrome_test.dart
?? lib/layout/breakpoints.dart
?? lib/layout/adaptive_scaffold.dart
?? lib/platform/android_fullscreen_controller.dart
?? lib/platform/player_download_actions.dart
?? lib/widgets/mobile/player_back_scope.dart
?? test/platform/download_wiring_test.dart
?? test/platform/player_back_scope_test.dart
```

本轮诊断修复主要涉及 7 个文件：player_page、lifecycle_coordinator、player_page_view、diagnostics_overlay，以及 coordinator_test、player_platform_boundary_test、diagnostics_overlay_test。同一个文件还可能含前阶段改动，不能整文件回滚来“只撤销诊断”。

本次新增文档：`docs/ANDROID_DEVELOPMENT_HANDOFF_2026-10-25.md`。所有文件均未由本会话暂存、提交、合并或推送。

## 9. 构建与验收命令

以下命令必须在唯一 worktree 执行；不要先 cd 到主仓库。当前依赖已下载，默认不必重新 pub get。

```bash
git status --short --branch
/c/flutter/bin/flutter test --no-pub
/c/flutter/bin/flutter analyze --no-pub
/c/flutter/bin/flutter build apk --debug -t lib/main_android.dart --no-pub
git diff --check
```

依赖状态确实缺失时才运行 `/c/flutter/bin/flutter pub get`。

定向回归：

```bash
/c/flutter/bin/flutter test --no-pub \
  test/pages/player/player_playback_lifecycle_coordinator_test.dart \
  test/platform/android_source_boundary_test.dart \
  test/platform/download_wiring_test.dart \
  test/platform/platform_controllers_test.dart \
  test/platform/player_back_scope_test.dart \
  test/platform/player_platform_boundary_test.dart \
  test/player_diagnostics_overlay_test.dart \
  test/player_episode_sidebar_test.dart \
  test/vira_page_chrome_test.dart
```

本机工具：

- Flutter：`C:/flutter/bin/flutter`（Git Bash 用 `/c/flutter/bin/flutter`）。
- ADB：`D:/VeraMobile/Android/Sdk/platform-tools/adb.exe`。
- Emulator：`D:/VeraMobile/Android/Sdk/emulator/emulator.exe`。
- NDK：`D:/VeraMobile/Android/Sdk/ndk/28.2.13676358`。
- ffmpeg/ffprobe 已安装；上述路径是本机信息，不代表其他机器也可直接使用。

设备操作前先核对连接目标，不盲用旧 serial。安装会替换该设备上的同包应用，按主人批准的目标执行。

```bash
"D:/VeraMobile/Android/Sdk/platform-tools/adb.exe" devices -l
```

- 正式 APK：`build/app/outputs/flutter-apk/app-debug.apk`。
- 正式 Android 入口只能是 `lib/main_android.dart`；`lib/main.dart` 为 Windows 入口。
- 包名：`io.github.nina27486486.weila`；Activity：`.MainActivity`。
- Git Bash 中传 `/data/local/tmp/...` 等 Android 路径时加 `MSYS_NO_PATHCONV=1`，避免被转为 Windows 路径。
- 模拟器启动需等 boot 完成再启动 Activity；不要为启动时序错误盲改 Manifest。
- 内置浏览器曾因 viewport=0x0 不可用，验收改用独立 Chrome profile/CDP，不使用用户日常 profile；等待实际绘制后再点击。
- 需要 Windows Release 回归时用已有 `tool/build_windows_release.ps1`，本次交接未运行。

## 10. 剩余问题与建议顺序

| 优先级 | 工作 | 当前缺口 / 下一步边界 |
|---|---|---|
| 1 | arm64 正常路径回归 | 旧版本真机播放成功不能替代新诊断验收；优先验证视频可见、首帧报告、切集、切线、手动重试、前后台、全屏退出 |
| 2 | 真实网络中断调查 | 需要最小脱敏采样区分 manifest、媒体传输、buffering、生命周期和渲染；先证据后改动 |
| 独立任务 | 模拟器 native EGL 兼容修复 | 需确认依赖升级/补丁范围，不能自行换库；已有实验已排除简单软硬解和 SwiftShader 切换 |
| 独立任务 | 首页/详情/播放器移动重排 | 需新的设计与范围确认；先选一个页面，复用业务和 token，不 fork 整套前端 |
| 后续 | 抽屉展开挤压正文 | 固定 220 宽仍在，关闭负宽问题已修，不要混为同一个 bug |
| 后续 | CatalogController dispose 后异步异常 | 前阶段观察到，未在本轮修复；若选择处理需重新复现并确认调用链 |
| 历史待复核 | 看板娘资源、其他页窄屏、弹幕移动验收、安全存储、便携数据、签名/CI | 旧文档含待办，本轮未系统复核，不能直接标完成或当作当前已复现缺陷 |

arm64 验收最低清单：

- [ ] 明确设备/ABI/系统/屏宽，安装由 `main_android.dart` 构建的当前包。
- [ ] 实际看见视频画面且有声音，安全报告首帧状态与观察一致。
- [ ] 切集与手动重新加载后仍可播放，没有旧错误覆盖新会话。
- [ ] 有多线路时切线并核对续播位置；单线路时注明未覆盖。
- [ ] 返回键依次关闭面板、抽屉、全屏，再离开页面；连续返回不重新进入全屏。
- [ ] 横屏与系统栏恢复符合设备实测，前后台/锁屏行为如实记录。
- [ ] 对无法覆盖的失败路径明确写“未验证”，不编造通过结果。

没有真机时可以继续只读分析或准备测试，但必须保留“arm64 未验证”，不能用模拟器、Web 或 vo=null 代替。

## 11. 当前环境收尾状态

上一轮工程结束时：

- 已重新构建正式 Android APK，并覆盖安装回模拟器，截图确认正式首页，非探针。
- 设备上的本轮合成视频临时文件已定点删除；本机证据仍保留。
- 本会话启动的模拟器、Web 服务、独立 Chrome 都已结束。
- 没有待等待的构建、测试或审查代理；不需要轮询旧任务。
- 本机忽略目录仍有探针 APK/入口，不表示设备仍装探针。重建时务必指定正式入口。
- 接手时设备/进程状态可能已变化，按实际观察核对，不照旧记录清理其他进程。

## 12. 可直接交给下一模型的启动提示词

```text
你接手薇拉 Android 开发。默认中文，称呼我为“主人”。

唯一工作目录：
C:\Users\nina\Desktop\自己vibe coding玩玩\薇拉\.worktrees\android-mvp
分支：codex/android-mvp；不要切回主工作区。

先读 docs/ANDROID_DEVELOPMENT_HANDOFF_2026-10-25.md，再读 AGENTS.md、
docs/ANDROID_MVP_PLAN.md、docs/ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md
与 PROJECT_HANDOFF.md。原 docs/ANDROID_HANDOFF.md 的阶段 A 待办已过时。

先运行 git status --short --branch 和 flutter test --no-pub，核对当前基线。
上一轮是 528 通过、1 项真实 API 测试按设计跳过；analyze 与 Android debug 构建通过。
这不是你本轮的验证结果，如实区分。

已经实现：下载依赖隔离、600/840 移动壳、Android 四项窄屏底栏、SystemChrome
横屏沉浸与退出恢复、面板→抽屉→全屏→页面分层返回，以及 Android 输出初始化
失败的首帧诊断误报修复。不要重新实现这些内容。

尚未解决：模拟器旧 native mpv/EGL 黑屏、真实网络播放中断根因、新诊断在
arm64 真机正常路径的回归。vo-configured=yes 不是屏幕可见画面的充分证据。
首页、详情、播放器移动排版未开展。

所有本轮开发代码仍未提交，保留原有脏改动。不要 reset/checkout 丢弃修改，
不自行提交、合并、推送，不提交 android/gradle.properties 或 Windows 生成文件。
Android 导入图不能接触 window_manager/win32/WindowsDanmakuCredentialStore/
DownloadService；usesCleartextTraffic 保持 false；Windows 行为不变。
不读签名/keystore/凭据，不上传媒体 URL、Cookie 或原始日志。

建议先做 arm64 真机正常播放、切集、手动重试、全屏返回与首帧诊断一致性验收；
无真机要明确限制。继续开发前，先说明建议推进哪一个独立问题和影响范围，等我
明确选择。不要擅自升级 native 库、重构播放业务或进入移动页面重排。

交付说明改动文件、用户可见变化、实际验证与未覆盖项。
```
