# 薇拉 1.0 Git 提交计划

更新日期：2026-07-31

适用分支：`codex/weila-1.0-readiness`

本文只定义建议的暂存边界和提交说明，不代表已经暂存、提交或推送。每组提交前后均应
检查 `git diff --cached --check`，并至少运行与该组对应的测试；最终目标提交仍需运行
全量质量门槛。

## 1. 目录缓存恢复

提交说明：

```text
feat(catalog): harden catalog cache recovery
```

文件：

- `lib/services/catalog/catalog_hive_stores.dart`
- `lib/services/storage/storage_service.dart`
- `test/services/catalog/catalog_hive_stores_test.dart`

该提交只允许在目录查询缓存出现未知 Hive `typeId` 时删除并重建
`catalog_query_cache_v1`；不能触碰目录实体、外部引用或旧用户数据盒。

## 2. 弹弹play 凭据安全

提交说明：

```text
security(credentials): migrate dandanplay secrets to Credential Manager
```

文件：

- `lib/main.dart`
- `lib/pages/settings/settings_page.dart` 中凭据读取、保存、清除、迁移重试相关区块
- `lib/services/danmaku/dandanplay_credential_manager.dart`
- `lib/services/danmaku/dandanplay_credential_migrator.dart`
- `lib/services/danmaku/danmaku_credential_store.dart`
- `lib/services/danmaku/windows_danmaku_credential_store.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `test/services/danmaku/dandanplay_live_test.dart`
- `test/services/danmaku/danmaku_credential_manager_test.dart`
- `test/services/danmaku/danmaku_credential_migrator_test.dart`
- `test/services/danmaku/windows_danmaku_credential_store_test.dart`

`settings_page.dart` 必须逐块暂存；GitHub Releases 手动更新入口留给第 7 组。
`pubspec.yaml` 和 `pubspec.lock` 一起提交，将锁文件已有的 `win32` 提升为直接依赖。

## 3. 安全验收报告与播放诊断基础

提交说明：

```text
feat(playback): add safe acceptance reports and diagnostics
```

文件：

- `lib/services/diagnostics/acceptance_report.dart`
- `lib/services/diagnostics/acceptance_report_service.dart`
- `lib/services/playback/playback_diagnostics.dart`
- `lib/services/playback/playback_error_sanitizer.dart`
- `test/services/diagnostics/acceptance_report_service_test.dart`
- `test/services/diagnostics/acceptance_report_test.dart`
- `test/services/playback/playback_diagnostics_test.dart`
- `test/services/playback/playback_error_sanitizer_test.dart`

这一组只提交纯模型、序列化、错误分类和测试，不提前修改播放器组件的必填参数，
避免中间提交无法编译。

## 4. 弹幕匹配、同步与 FakePlayer 回归

提交说明：

```text
feat(danmaku): improve matching and seek synchronization
```

文件：

- `lib/debug/danmaku_debug_session.dart`
- `lib/pages/debug/danmaku_debug_page.dart`
- `lib/pages/debug/widgets/danmaku_debug_components.dart`
- `lib/services/danmaku/danmaku_matcher.dart`
- `lib/services/danmaku/danmaku_repository.dart`
- `lib/widgets/danmaku_overlay.dart`
- `test/pages/debug/danmaku_debug_page_test.dart`
- `test/services/danmaku/danmaku_matcher_test.dart`
- `test/services/danmaku/danmaku_repository_test.dart`
- `test/widgets/danmaku_overlay_test.dart`

该提交包含数字续作/季度别名、装饰符号归一、异步晚到定位和显式 seek 清屏，
以及 FakePlayer 的安全报告入口。不得加入真实弹幕正文或 API 凭据夹具。

## 5. 播放器协调器拆分与常驻报告入口

提交说明：

```text
refactor(player): extract playback and danmaku coordinators
```

文件：

- `lib/pages/player/player_page.dart`
- `lib/pages/player/player_danmaku_session.dart`
- `lib/pages/player/player_episode_selection.dart`
- `lib/pages/player/player_playback_lifecycle_coordinator.dart`
- `lib/pages/player/widgets/player_control_bar.dart`
- `lib/pages/player/widgets/player_diagnostics_overlay.dart`
- `lib/pages/player/widgets/player_page_view.dart`
- `test/pages/player/player_danmaku_session_test.dart`
- `test/pages/player/player_episode_selection_test.dart`
- `test/pages/player/player_playback_lifecycle_coordinator_test.dart`
- `test/player_control_bar_test.dart`
- `test/player_diagnostics_overlay_test.dart`

这组依赖第 3、4 组。它应保持换线续播、首帧/缓冲诊断、非首集弹幕、seek 同步和
播放器视觉行为不变，并加入正常播放时常驻的“验收报告”入口。

## 6. 详情页控制器拆分

提交说明：

```text
refactor(detail): extract detail controller and view
```

文件：

- `lib/pages/detail/detail_page.dart`
- `lib/pages/detail/detail_controller.dart`
- `lib/pages/detail/widgets/detail_page_view.dart`
- `test/pages/detail/detail_controller_test.dart`

该提交保留现有路由、`contentId` 双写、播放源确认、收藏和追番行为；底层错误只能映射
为受控提示，不能重新向界面输出原始异常。

## 7. Windows 发布工程与 CI

提交说明：

```text
build(release): add coverage gates installer and package checks
```

文件：

- `.github/workflows/ci.yml`
- `installer/weila.iss`
- `lib/pages/settings/settings_page.dart` 中 GitHub Releases 手动更新入口相关区块
- `lib/utils/constants.dart`
- `tool/build_windows_installer.ps1`
- `tool/build_windows_release.ps1`
- `tool/check_coverage.dart`
- `tool/coverage_gate.dart`
- `tool/package_windows_release.ps1`
- `tool/test_windows_package.ps1`
- `tool/write_release_hashes.ps1`
- `windows/runner/Runner.rc`
- `test/tool/coverage_gate_test.dart`
- `test/tool/release_source_privacy_test.dart`
- `test/tool/windows_release_metadata_test.dart`
- `test/utils/app_constants_test.dart`

`settings_page.dart` 必须逐块暂存，不能把第 2 组遗漏的凭据改动混入本组。构建产物、
安装器输出和 `SHA256SUMS.txt` 不进入 Git。

## 8. 发布、隐私、交接与 Android 规划文档

提交说明：

```text
docs(release): document privacy acceptance and 1.0 readiness
```

文件：

- `CHANGELOG.md`
- `PRIVACY.md`
- `PROJECT_HANDOFF.md`
- `README.md`
- `SECURITY.md`
- `docs/ANDROID_MVP_PLAN.md`
- `docs/GIT_COMMIT_PLAN_1.0.md`
- `docs/MAINLAND_ACCEPTANCE_MATRIX.md`
- `docs/RELEASE_CHECKLIST_1.0.md`
- `docs/RELEASE_READINESS_REPORT_1.0.md`

此时 CHANGELOG 仍保持 Unreleased，版本仍保持 `0.4.0+4`。正式改为 `1.0.0+5`、
关闭 Unreleased、生成最终产物和标签必须等待主人另行确认。

## 明确排除

以下文件只有工作树换行符状态差异，忽略行尾空白后没有实际内容差异，不暂存：

- `windows/flutter/generated_plugin_registrant.cc`
- `windows/flutter/generated_plugin_registrant.h`
- `windows/flutter/generated_plugins.cmake`

以下内容不得暂存：

- `build/`、`coverage/`、`.dart_tool/`
- 桌面安全 JSON、原始播放器日志和网络抓包
- AppId、AppSecret、Cookie、Header、代理凭据或签名材料
- Inno Setup 下载缓存、安装后的用户数据和本机配置

## 每组提交前检查

```powershell
git diff --cached --check
git diff --cached --stat
git diff --cached
```

逐块暂存 `settings_page.dart` 时必须同时检查未暂存差异，确保两个提交边界没有漏块：

```powershell
git diff -- lib/pages/settings/settings_page.dart
git diff --cached -- lib/pages/settings/settings_page.dart
```

如果某一拆分后的暂存快照无法通过 `flutter analyze`，应把存在编译依赖的相邻组并成
一个提交，而不是为了维持提交数量引入不可构建的中间历史。
