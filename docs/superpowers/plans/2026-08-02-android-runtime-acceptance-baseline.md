# 薇拉 Android 运行验收基线 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在固定的 API 36 Google APIs x86_64 模拟器上建立薇拉 Android 的可重复运行验收基线，证明应用壳、目录网络链路和 Android 能力门控真实可用。

**Architecture:** 使用命令行确定性配置 D 盘工具链、安装 SDK 组件并创建专用 Pixel 7 AVD；使用可见模拟器完成交互，使用 ADB 采集启动、进程、日志、界面层级和截图证据。原始证据只保存在 D 盘，仓库只新增脱敏验收报告；若遇到应用阻塞，先进入根因诊断并为该具体故障另写精确 TDD 修复计划，再恢复本计划的验收流程。

**Tech Stack:** Flutter 3.41.9、Dart 3.11.5、Android SDK/targetSdk/compileSdk 36、JDK 17、Android Emulator、Google APIs x86_64、ADB、PowerShell、Flutter Test。

## Global Constraints

- 工作树固定为 `C:\Users\nina\Desktop\自己vibe coding玩玩\薇拉\.worktrees\android-mvp`，分支固定为 `codex/android-mvp`。
- 工具链根目录固定为 `D:\Vera Mobile Application Development`；Android Studio、SDK、JDK 17 和 AVD 数据不得迁回旧中文目录。
- AVD 固定命名为 `Weila_API_36_Google_APIs`，系统镜像固定为 `system-images;android-36;google_apis;x86_64`，硬件档案固定为 `pixel_7`。
- 应用 ID 固定为 `io.github.nina27486486.weila`，Android 构建入口固定为 `lib/main_android.dart`。
- 只设置 Flutter 自身 JDK 路径和当前命令进程的 `JAVA_HOME`；不得修改系统级或用户级 `JAVA_HOME`。
- 用户级 `ANDROID_AVD_HOME` 固定为 `D:\Vera Mobile Application Development\Android\Avd`，Android Studio、Flutter、`avdmanager` 与 `emulator` 必须读取同一 AVD。
- 正式验收使用可见模拟器窗口、硬件加速和 `-no-snapshot-load` 冷启动；不得以旧快照替代首次运行证据。
- 本阶段不验收视频播放、全屏、弹幕、真实凭据、下载、插件编辑、签名或发布。
- 不得启用全局明文流量、关闭 TLS 验证、硬编码代理凭据或提交 Cookie、Header、AppId、AppSecret、签名材料及完整媒体 URL。
- 原始截图、日志、UI hierarchy 和机器诊断只保存在 D 盘；仓库只提交脱敏报告。
- 不得使用 `git reset --hard`、`git checkout --`、`git clean` 或直接执行 `flutter clean`。
- 不得暂存以下三个既存换行差异：`windows/flutter/generated_plugin_registrant.cc`、`windows/flutter/generated_plugin_registrant.h`、`windows/flutter/generated_plugins.cmake`。
- 不推送、不合并、不升版、不打标签、不创建 Release。
- 手写仓库文件修改使用 `apply_patch`；每次暂存前后均检查精确文件范围。

---

## File and State Map

### 本计划直接修改或创建

- Modify, ignored local state: `android/local.properties` — 将 `sdk.dir` 从已删除的旧目录指向新的 D 盘 SDK；不得暂存。
- Modify, machine state: Flutter config — 更新 Android Studio、Android SDK 与 JDK 17 路径；不得提交。
- Modify, user environment: `ANDROID_AVD_HOME` — 固定 AVD 目录；不得提交。
- Create, local state: `D:\Vera Mobile Application Development\Android\Avd\Weila_API_36_Google_APIs.avd` — 专用验收 AVD；不得提交。
- Create, local evidence: `D:\Vera Mobile Application Development\Acceptance` 下由 `Get-Date -Format 'yyyyMMdd-HHmmss-api36'` 生成的本轮目录；不得提交。
- Create: `docs/ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md` — 唯一进入仓库的运行验收报告。

### 本计划只读取

- `lib/main_android.dart` — Android 入口与 `AppCapabilities.androidCompileBaseline` 组合。
- `lib/app_module.dart` — `/`、`/search`、`/detail`、`/settings`、`/category` 路由及能力门控。
- `lib/platform/app_capabilities.dart` — Android 的下载、插件编辑和安全凭据开关。
- `lib/widgets/vira_page_chrome.dart` — “首页”“发现”“搜索”“个人与设置”等交互标签。
- `lib/pages/search/search_page.dart` — 稳定验收搜索词“葬送的芙莉莲”。
- `lib/pages/settings/settings_page.dart` — “暂不可用”凭据状态与 Android 隐藏入口。
- `android/app/build.gradle.kts` — API 36、JDK 17 与应用 ID。
- `android/app/src/main/AndroidManifest.xml` — INTERNET、禁用 cleartext 和 MainActivity。
- `tool/build_windows_release.ps1` — 发生业务代码修复后的 Windows 回归脚本。
- `tool/check_coverage.dart` — 发生业务代码修复后的覆盖率门禁。

### 应用阻塞时的文件边界

本计划不预设业务源码改动。若 Task 3 或 Task 4 暴露应用阻塞，立即执行“应用阻塞分支”，用真实堆栈和失败测试确定具体文件后，创建一份以故障命名的独立修复计划；在该计划完成前不得猜测性修改 Store、Service、路由、网络接口或本地数据格式。

---

### Task 1: 重新锚定 D 盘 Android 工具链

**Files:**
- Modify, ignored: `android/local.properties`
- Create, local: `D:\Vera Mobile Application Development\Acceptance\current-run.txt`
- Inspect: `.gitignore`

**Interfaces:**
- Consumes: 已存在的 Android Studio、Android SDK、JDK 17 实体目录。
- Produces: Flutter 可识别的新工具链配置、固定 `ANDROID_AVD_HOME`、本轮证据目录路径。

- [ ] **Step 1: 复核 Git 安全边界**

Run:

```powershell
git status --short --branch -uall
git branch --show-current
git rev-parse --short HEAD
git diff --cached --name-only
```

Expected: branch 为 `codex/android-mvp`；index 为空；工作区只列出三个 `windows/flutter/generated_*` 换行差异。

- [ ] **Step 2: 验证新工具链实体文件完整**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$required = @(
  "$toolRoot\Android Studio\bin\studio64.exe",
  "$toolRoot\Android\Sdk\platform-tools\adb.exe",
  "$toolRoot\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat",
  "$toolRoot\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat",
  "$toolRoot\JDK17\bin\java.exe"
)
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missing.Count -gt 0) { throw "Missing toolchain files: $($missing -join ', ')" }
$required | Get-Item | Select-Object FullName, Length, LastWriteTime
```

Expected: 五个文件全部存在；没有引用 `D:\移动端开发`。

- [ ] **Step 3: 建立本轮 D 盘原始证据目录**

Run:

```powershell
$acceptanceRoot = 'D:\Vera Mobile Application Development\Acceptance'
$runDir = Join-Path $acceptanceRoot (Get-Date -Format 'yyyyMMdd-HHmmss-api36')
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
Set-Content -LiteralPath (Join-Path $acceptanceRoot 'current-run.txt') -Value $runDir -NoNewline -Encoding UTF8
Get-Item -LiteralPath $runDir | Select-Object FullName, CreationTime
```

Expected: `current-run.txt` 的唯一一行是本轮 D 盘目录；仓库内没有新增证据文件。

- [ ] **Step 4: 更新 Flutter 的 Android 工具路径**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
flutter config --android-studio-dir "$toolRoot\Android Studio"
flutter config --android-sdk "$toolRoot\Android\Sdk"
flutter config --jdk-dir "$toolRoot\JDK17"
```

Expected: 三条命令成功；Flutter 不再引用已删除的旧目录。

- [ ] **Step 5: 用 apply_patch 更新忽略的 local.properties**

Apply this exact patch from the worktree root:

```diff
*** Begin Patch
*** Update File: android/local.properties
@@
-sdk.dir=D:\\移动端开发\\Android\\Sdk
+sdk.dir=D:\\Vera Mobile Application Development\\Android\\Sdk
*** End Patch
```

Expected: `flutter.sdk`、`flutter.buildMode`、`flutter.versionName`、`flutter.versionCode` 保持原值；`git status` 不出现 `android/local.properties`，因为它是忽略文件。

- [ ] **Step 6: 固定用户级 AVD 数据目录，不修改 JAVA_HOME**

Run:

```powershell
$avdRoot = 'D:\Vera Mobile Application Development\Android\Avd'
New-Item -ItemType Directory -Force -Path $avdRoot | Out-Null
[Environment]::SetEnvironmentVariable('ANDROID_AVD_HOME', $avdRoot, 'User')
$env:ANDROID_AVD_HOME = $avdRoot
$env:JAVA_HOME = 'D:\Vera Mobile Application Development\JDK17'
[pscustomobject]@{
  UserAndroidAvdHome = [Environment]::GetEnvironmentVariable('ANDROID_AVD_HOME', 'User')
  ProcessAndroidAvdHome = $env:ANDROID_AVD_HOME
  UserJavaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
  ProcessJavaHome = $env:JAVA_HOME
}
```

Expected: 两个 AVD 值均为新 D 盘目录；用户级 `JAVA_HOME` 保持原值，只有当前进程使用 JDK 17。

- [ ] **Step 7: 验证 Flutter 配置与 Android Doctor**

Run:

```powershell
$acceptanceRoot = 'D:\Vera Mobile Application Development\Acceptance'
$runDir = Get-Content -LiteralPath (Join-Path $acceptanceRoot 'current-run.txt') -Encoding UTF8
flutter config --list | Tee-Object -FilePath (Join-Path $runDir 'flutter-config.txt')
flutter doctor -v | Tee-Object -FilePath (Join-Path $runDir 'flutter-doctor.txt')
Get-Content -LiteralPath 'android\local.properties' -Encoding UTF8 | Tee-Object -FilePath (Join-Path $runDir 'android-local-properties.txt')
```

Expected: Flutter 的三条 Android 路径均位于新 D 盘；Android SDK 36 和 JDK 17 可识别。Emulator 尚未安装可以在此步显示为后续任务缺口，但不得出现旧目录不存在错误。

- [ ] **Step 8: 确认没有仓库变更或提交**

Run:

```powershell
git diff --cached --name-only
git status --short --branch -uall
```

Expected: index 为空；仍只有三个既存 Windows 生成文件差异。本任务只改变机器配置，不创建 Git 提交。

---

### Task 2: 安装 Emulator 与创建固定 Pixel 7 AVD

**Files:**
- Create, local: `D:\Vera Mobile Application Development\Android\Sdk\emulator`
- Create, local: `D:\Vera Mobile Application Development\Android\Sdk\system-images\android-36\google_apis\x86_64`
- Create, local: `D:\Vera Mobile Application Development\Android\Avd\Weila_API_36_Google_APIs.avd`
- Create, local evidence: `sdk-installed.txt`, `avd-list.txt`, `avd-config.ini`, `emulator-accel-check.txt`

**Interfaces:**
- Consumes: Task 1 的 SDK、JDK 17、`ANDROID_AVD_HOME` 与 `current-run.txt`。
- Produces: 可硬件加速、可被 ADB 启动的 `Weila_API_36_Google_APIs` AVD。

- [ ] **Step 1: 接受 Android SDK 许可证**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$env:JAVA_HOME = "$toolRoot\JDK17"
$env:ANDROID_AVD_HOME = "$toolRoot\Android\Avd"
$sdkmanager = "$toolRoot\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat"
$answers = ((1..100 | ForEach-Object { 'y' }) -join "`n")
$answers | & $sdkmanager --licenses
if ($LASTEXITCODE -ne 0) { throw "sdkmanager --licenses failed: $LASTEXITCODE" }
```

Expected: 许可证命令退出码为 0；输出不包含凭据或代理认证信息。

- [ ] **Step 2: 安装固定 SDK 组件**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$env:JAVA_HOME = "$toolRoot\JDK17"
$sdkmanager = "$toolRoot\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat"
& $sdkmanager 'emulator' 'system-images;android-36;google_apis;x86_64'
if ($LASTEXITCODE -ne 0) { throw "SDK component install failed: $LASTEXITCODE" }
```

Expected: `emulator.exe` 和 API 36 Google APIs x86_64 镜像存在；不安装 Google Play 镜像或其他 API 镜像。

- [ ] **Step 3: 记录并验证已安装组件**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$env:JAVA_HOME = "$toolRoot\JDK17"
$sdkmanager = "$toolRoot\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat"
& $sdkmanager --list_installed | Tee-Object -FilePath (Join-Path $runDir 'sdk-installed.txt')
if (-not (Test-Path -LiteralPath "$toolRoot\Android\Sdk\emulator\emulator.exe")) { throw 'emulator.exe missing' }
if (-not (Test-Path -LiteralPath "$toolRoot\Android\Sdk\system-images\android-36\google_apis\x86_64\package.xml")) { throw 'API 36 Google APIs x86_64 image missing' }
```

Expected: 组件清单包含 `emulator` 和 `system-images;android-36;google_apis;x86_64`。

- [ ] **Step 4: 安全检查同名 AVD**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$avdName = 'Weila_API_36_Google_APIs'
$env:JAVA_HOME = "$toolRoot\JDK17"
$env:ANDROID_AVD_HOME = "$toolRoot\Android\Avd"
$emulator = "$toolRoot\Android\Sdk\emulator\emulator.exe"
$existing = @(& $emulator -list-avds)
$existing
if ($existing -contains $avdName) {
  $config = "$toolRoot\Android\Avd\$avdName.avd\config.ini"
  if (-not (Test-Path -LiteralPath $config)) { throw "Named AVD has no config: $config" }
  $imageOk = Select-String -LiteralPath $config -SimpleMatch 'image.sysdir.1=system-images\android-36\google_apis\x86_64\' -Quiet
  $deviceOk = Select-String -LiteralPath $config -SimpleMatch 'hw.device.name=pixel_7' -Quiet
  if (-not ($imageOk -and $deviceOk)) {
    throw 'Named AVD exists with a different image or device profile; run Step 5 before recreation.'
  }
}
```

Expected: 当前基线没有同名 AVD；若将来重复执行且配置完全匹配，则直接复用并跳过 Step 5 和 Step 6。

- [ ] **Step 5: 仅在同名 AVD 配置不匹配时安全删除它**

Run only after Step 4 reports the named mismatch:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$avdName = 'Weila_API_36_Google_APIs'
$avdRoot = [IO.Path]::GetFullPath("$toolRoot\Android\Avd").TrimEnd('\')
$target = [IO.Path]::GetFullPath("$avdRoot\$avdName.avd")
if (-not $target.StartsWith("$avdRoot\", [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe AVD target: $target" }
if (-not (Test-Path -LiteralPath "$target\config.ini")) { throw "Refusing to delete unverified AVD target: $target" }
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
Copy-Item -LiteralPath "$target\config.ini" -Destination (Join-Path $runDir 'mismatched-avd-config.ini')
$env:JAVA_HOME = "$toolRoot\JDK17"
$env:ANDROID_AVD_HOME = $avdRoot
$avdmanager = "$toolRoot\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat"
& $avdmanager delete avd --name $avdName
if ($LASTEXITCODE -ne 0) { throw "Unable to delete only the named acceptance AVD: $LASTEXITCODE" }
```

Expected: 只删除 `Weila_API_36_Google_APIs`；其他 AVD 不受影响。当前首次执行不需要运行此步。

- [ ] **Step 6: 创建 API 36 Google APIs x86_64 Pixel 7 AVD**

Run when no matching AVD exists:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$avdName = 'Weila_API_36_Google_APIs'
$env:JAVA_HOME = "$toolRoot\JDK17"
$env:ANDROID_AVD_HOME = "$toolRoot\Android\Avd"
$avdmanager = "$toolRoot\Android\Sdk\cmdline-tools\latest\bin\avdmanager.bat"
'no' | & $avdmanager create avd --force --name $avdName --package 'system-images;android-36;google_apis;x86_64' --device 'pixel_7'
if ($LASTEXITCODE -ne 0) { throw "AVD creation failed: $LASTEXITCODE" }
```

Expected: AVD 创建成功，镜像与设备档案完全匹配固定值。

- [ ] **Step 7: 验证 AVD 路径、配置与硬件加速**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$avdName = 'Weila_API_36_Google_APIs'
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$env:ANDROID_AVD_HOME = "$toolRoot\Android\Avd"
$emulator = "$toolRoot\Android\Sdk\emulator\emulator.exe"
$config = "$toolRoot\Android\Avd\$avdName.avd\config.ini"
& $emulator -list-avds | Tee-Object -FilePath (Join-Path $runDir 'avd-list.txt')
& $emulator -accel-check | Tee-Object -FilePath (Join-Path $runDir 'emulator-accel-check.txt')
Copy-Item -LiteralPath $config -Destination (Join-Path $runDir 'avd-config.ini')
if (-not (Select-String -LiteralPath $config -SimpleMatch 'image.sysdir.1=system-images\android-36\google_apis\x86_64\' -Quiet)) { throw 'Wrong AVD image' }
if (-not (Select-String -LiteralPath $config -SimpleMatch 'hw.device.name=pixel_7' -Quiet)) { throw 'Wrong AVD hardware profile' }
```

Expected: AVD 名称唯一出现；配置完全匹配；加速检查报告可用的 Windows hypervisor。

- [ ] **Step 8: 确认本任务没有仓库提交**

Run:

```powershell
git diff --cached --name-only
git status --short --branch -uall
```

Expected: index 为空；仍只有三个既存 Windows 生成文件差异。本任务只新增 D 盘 SDK 与 AVD 文件。

---

### Task 3: 冷启动 AVD 并建立应用两次启动证据

**Files:**
- Build, ignored: `build/app/outputs/flutter-apk/app-debug.apk`
- Create, local evidence: `device.txt`, `apk.txt`, `first-launch.txt`, `first-launch-app.log`, `first-launch-crash.log`, `first-launch-exit-info.txt`, `01-home-first.png`, `01-home-first.xml`, `second-launch.txt`, `second-launch-app.log`, `second-launch-crash.log`, `second-launch-exit-info.txt`, `06-home-second.png`, `06-home-second.xml`

**Interfaces:**
- Consumes: Task 2 的 AVD、Task 1 的 Flutter/JDK/SDK 配置、`lib/main_android.dart`。
- Produces: 首次安装冷启动和 `force-stop` 后第二次启动均可审计的证据。

- [ ] **Step 1: 启动可见模拟器且不加载旧快照**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$env:ANDROID_AVD_HOME = "$toolRoot\Android\Avd"
$emulator = "$toolRoot\Android\Sdk\emulator\emulator.exe"
$running = Get-Process -Name emulator -ErrorAction SilentlyContinue
if ($running) { throw 'An emulator process is already running; identify it before starting the formal acceptance AVD.' }
$process = Start-Process -FilePath $emulator -ArgumentList @('-avd','Weila_API_36_Google_APIs','-no-snapshot-load','-accel','auto','-gpu','auto') -PassThru
$process | Select-Object Id, ProcessName, StartTime
```

Expected: 模拟器以可见窗口启动；没有 `-no-window`、`-wipe-data` 或快照加载参数。

- [ ] **Step 2: 以不超过 55 秒的一轮轮询等待 ADB 与开机完成**

Run this block at most three times, reporting progress between rounds:

```powershell
$adb = 'D:\Vera Mobile Application Development\Android\Sdk\platform-tools\adb.exe'
$deadline = (Get-Date).AddSeconds(55)
do {
  $serials = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
  if ($serials.Count -eq 1) {
    $boot = (& $adb -s $serials[0] shell getprop sys.boot_completed 2>$null).Trim()
    if ($boot -eq '1') { [pscustomobject]@{ Serial = $serials[0]; BootCompleted = $boot }; break }
  }
  Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)
if ($boot -ne '1') { Write-Output 'Boot is still in progress after this 55-second round.' }
```

Expected: 三轮内得到唯一 `emulator-*` serial 且 `sys.boot_completed=1`。三轮仍未完成时收集 `adb devices -l`、Emulator 进程和启动属性后停止，不无限等待。

- [ ] **Step 3: 验证 ADB 连接到正确 AVD并解锁**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$serials = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
if ($serials.Count -ne 1) { throw "Expected exactly one emulator, found $($serials.Count)" }
$serial = $serials[0]
$avd = (& $adb -s $serial emu avd name | Select-Object -First 1).Trim()
if ($avd -ne 'Weila_API_36_Google_APIs') { throw "Wrong AVD: $avd" }
& $adb -s $serial shell input keyevent 82
@(
  "serial=$serial",
  "avd=$avd",
  "sdk=$((& $adb -s $serial shell getprop ro.build.version.sdk).Trim())",
  "abi=$((& $adb -s $serial shell getprop ro.product.cpu.abi).Trim())",
  "model=$((& $adb -s $serial shell getprop ro.product.model).Trim())",
  "size=$((& $adb -s $serial shell wm size | Out-String).Trim())",
  "density=$((& $adb -s $serial shell wm density | Out-String).Trim())"
) | Set-Content -LiteralPath (Join-Path $runDir 'device.txt') -Encoding UTF8
Get-Content -LiteralPath (Join-Path $runDir 'device.txt') -Encoding UTF8
```

Expected: AVD 名称正确、SDK 为 36、ABI 为 x86_64，设备已解锁可交互。

- [ ] **Step 4: 构建 Android Debug APK 并记录摘要**

Run:

```powershell
flutter pub get
flutter build apk --debug --target lib/main_android.dart --no-pub
$apk = Resolve-Path 'build\app\outputs\flutter-apk\app-debug.apk'
$runDir = Get-Content -LiteralPath 'D:\Vera Mobile Application Development\Acceptance\current-run.txt' -Encoding UTF8
$item = Get-Item -LiteralPath $apk
$hash = Get-FileHash -LiteralPath $apk -Algorithm SHA256
@(
  "path=$($item.FullName)",
  "bytes=$($item.Length)",
  "sha256=$($hash.Hash)"
) | Set-Content -LiteralPath (Join-Path $runDir 'apk.txt') -Encoding UTF8
Get-Content -LiteralPath (Join-Path $runDir 'apk.txt') -Encoding UTF8
```

Expected: Debug APK 从 `lib/main_android.dart` 构建成功，摘要包含非零大小和 64 位十六进制 SHA-256。

- [ ] **Step 5: 确保首轮是干净安装并安装 APK**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$package = 'io.github.nina27486486.weila'
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
$avd = (& $adb -s $serial emu avd name | Select-Object -First 1).Trim()
if ($avd -ne 'Weila_API_36_Google_APIs') { throw "Refusing install on wrong AVD: $avd" }
$existing = (& $adb -s $serial shell pm path $package 2>$null | Out-String).Trim()
if ($existing) {
  & $adb -s $serial uninstall $package
  if ($LASTEXITCODE -ne 0) { throw "Unable to remove only $package for first-install acceptance" }
}
& $adb -s $serial install -r 'build\app\outputs\flutter-apk\app-debug.apk'
if ($LASTEXITCODE -ne 0) { throw "APK install failed: $LASTEXITCODE" }
& $adb -s $serial shell pm path $package
```

Expected: 只在已验证的专用 AVD 上清理目标包；安装输出 `Success`，`pm path` 返回 APK 路径。

- [ ] **Step 6: 采集首次启动时间、应用日志、崩溃和退出信息**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$package = 'io.github.nina27486486.weila'
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
& $adb -s $serial logcat -c
& $adb -s $serial shell am start -W -S -n "$package/.MainActivity" | Tee-Object -FilePath (Join-Path $runDir 'first-launch.txt')
Start-Sleep -Seconds 15
$pid = (& $adb -s $serial shell pidof $package).Trim()
if (-not $pid) { throw 'Application process exited during first launch' }
& $adb -s $serial logcat -d --pid=$pid -v threadtime | Set-Content -LiteralPath (Join-Path $runDir 'first-launch-app.log') -Encoding UTF8
& $adb -s $serial logcat -b crash -d -v threadtime | Set-Content -LiteralPath (Join-Path $runDir 'first-launch-crash.log') -Encoding UTF8
& $adb -s $serial shell dumpsys activity exit-info $package | Set-Content -LiteralPath (Join-Path $runDir 'first-launch-exit-info.txt') -Encoding UTF8
```

Expected: `am start -W` 状态为成功，进程仍存在；应用日志不包含未处理 Flutter 异常，crash buffer 与 exit-info 不包含本轮崩溃或 ANR。

- [ ] **Step 7: 保存并视觉检查首次首页证据**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
& $adb -s $serial shell screencap -p /sdcard/weila-01-home-first.png
& $adb -s $serial pull /sdcard/weila-01-home-first.png (Join-Path $runDir '01-home-first.png')
& $adb -s $serial shell uiautomator dump /sdcard/weila-01-home-first.xml
& $adb -s $serial pull /sdcard/weila-01-home-first.xml (Join-Path $runDir '01-home-first.xml')
& $adb -s $serial shell rm -f /sdcard/weila-01-home-first.png /sdcard/weila-01-home-first.xml
```

Then inspect `01-home-first.png` with the image viewer and search `01-home-first.xml` for `首页` and `搜索`.

Expected: 首页真实可见，无永久白屏、启动画面或不可消失的骨架屏；截图不含个人或凭据信息。

- [ ] **Step 8: 执行 force-stop 后第二次启动并采集证据**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$package = 'io.github.nina27486486.weila'
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
& $adb -s $serial shell am force-stop $package
& $adb -s $serial logcat -c
& $adb -s $serial shell am start -W -n "$package/.MainActivity" | Tee-Object -FilePath (Join-Path $runDir 'second-launch.txt')
Start-Sleep -Seconds 10
$pid = (& $adb -s $serial shell pidof $package).Trim()
if (-not $pid) { throw 'Application process exited during second launch' }
& $adb -s $serial logcat -d --pid=$pid -v threadtime | Set-Content -LiteralPath (Join-Path $runDir 'second-launch-app.log') -Encoding UTF8
& $adb -s $serial logcat -b crash -d -v threadtime | Set-Content -LiteralPath (Join-Path $runDir 'second-launch-crash.log') -Encoding UTF8
& $adb -s $serial shell dumpsys activity exit-info $package | Set-Content -LiteralPath (Join-Path $runDir 'second-launch-exit-info.txt') -Encoding UTF8
& $adb -s $serial shell screencap -p /sdcard/weila-06-home-second.png
& $adb -s $serial pull /sdcard/weila-06-home-second.png (Join-Path $runDir '06-home-second.png')
& $adb -s $serial shell uiautomator dump /sdcard/weila-06-home-second.xml
& $adb -s $serial pull /sdcard/weila-06-home-second.xml (Join-Path $runDir '06-home-second.xml')
& $adb -s $serial shell rm -f /sdcard/weila-06-home-second.png /sdcard/weila-06-home-second.xml
```

Expected: 第二次启动进程稳定、首页可见，无本轮 crash、ANR 或未处理 Flutter 异常。

- [ ] **Step 9: 对两轮日志执行阻塞信号扫描**

Run:

```powershell
$runDir = Get-Content -LiteralPath 'D:\Vera Mobile Application Development\Acceptance\current-run.txt' -Encoding UTF8
$patterns = 'FATAL EXCEPTION|ANR in io\.github\.nina27486486\.weila|Unhandled Exception|FlutterError|Lost connection to device'
$hits = Get-ChildItem -LiteralPath $runDir -File | Where-Object { $_.Name -match 'launch.*\.(log|txt)$|exit-info\.txt$' } | Select-String -Pattern $patterns
if ($hits) { $hits; throw 'Blocking startup signal found; enter the application blocker branch.' }
'startup-signal-scan=pass' | Set-Content -LiteralPath (Join-Path $runDir 'startup-signal-scan.txt') -Encoding UTF8
```

Expected: 扫描通过。任何命中都必须结合包名、PID 与时间戳判定，不能删除日志或忽略真实应用异常。

---

### Task 4: 验收目录网络链路与 Android 能力门控

**Files:**
- Create, local evidence: `02-category.png`, `02-category.xml`, `03-search-results.png`, `03-search-results.xml`, `04-detail.png`, `04-detail.xml`, `05-settings.png`, `05-settings.xml`, `acceptance-app.log`, `acceptance-crash.log`, `acceptance-exit-info.txt`, `ui-assertions.txt`

**Interfaces:**
- Consumes: Task 3 正常运行的应用、可见模拟器、“葬送的芙莉莲”稳定搜索词。
- Produces: 首页→发现/分类→搜索→详情→设置的完整证据链和能力门控断言。

- [ ] **Step 1: 加载 GUI 控制技能并建立验收日志起点**

Before controlling the visible emulator, load `computer-use:computer-use` and restrict actions to the `Weila_API_36_Google_APIs` window.

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$package = 'io.github.nina27486486.weila'
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
if ((& $adb -s $serial emu avd name | Select-Object -First 1).Trim() -ne 'Weila_API_36_Google_APIs') { throw 'Wrong AVD' }
if (-not ((& $adb -s $serial shell pidof $package).Trim())) { throw 'Weila is not running' }
& $adb -s $serial logcat -c
```

Expected: GUI 操作目标唯一，应用进程存在，日志起点清晰。

- [ ] **Step 2: 打开“发现”并等待真实目录状态**

In the visible emulator, tap the navigation item labeled `发现`. Wait up to 30 seconds for `动画目录` and for the loading state to resolve.

Pass conditions:

- 页面可达且不是白屏。
- 目录卡片出现，或出现明确的安全错误状态。
- 不允许永久骨架屏，也不允许请求失败后无提示地伪装为空目录。

- [ ] **Step 3: 保存发现/分类证据**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
& $adb -s $serial shell screencap -p /sdcard/weila-02-category.png
& $adb -s $serial pull /sdcard/weila-02-category.png (Join-Path $runDir '02-category.png')
& $adb -s $serial shell uiautomator dump /sdcard/weila-02-category.xml
& $adb -s $serial pull /sdcard/weila-02-category.xml (Join-Path $runDir '02-category.xml')
& $adb -s $serial shell rm -f /sdcard/weila-02-category.png /sdcard/weila-02-category.xml
```

Inspect the PNG visually and verify the XML contains `动画目录`.

Expected: 页面标题与最终目录状态在同一份证据中可见。

- [ ] **Step 4: 打开搜索并提交稳定搜索词**

In the visible emulator:

1. Tap the masthead action labeled `搜索`.
2. Confirm the page title `搜索动画`.
3. Enter the exact text `葬送的芙莉莲` in `输入番剧名、别名或关键词`.
4. Tap `开始寻找` or submit the keyboard search action.
5. Wait up to 30 seconds for result cards or the explicit error state `这次搜索没有顺利抵达`.

Pass conditions:

- 正常外部服务条件下至少返回一个结果。
- 若返回真实空结果，界面必须明确显示空状态。
- 若为 DNS、TLS、超时或服务端错误，记录外部网络失败，不把错误状态记为搜索通过。

- [ ] **Step 5: 保存搜索证据并选择匹配结果**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
& $adb -s $serial shell screencap -p /sdcard/weila-03-search-results.png
& $adb -s $serial pull /sdcard/weila-03-search-results.png (Join-Path $runDir '03-search-results.png')
& $adb -s $serial shell uiautomator dump /sdcard/weila-03-search-results.xml
& $adb -s $serial pull /sdcard/weila-03-search-results.xml (Join-Path $runDir '03-search-results.xml')
& $adb -s $serial shell rm -f /sdcard/weila-03-search-results.png /sdcard/weila-03-search-results.xml
```

Then inspect `03-search-results.xml` and select a visible result whose semantic label begins with `查看` and whose displayed title matches `葬送的芙莉莲` or its recognized title variant. Do not open a playback action.

Expected: 搜索词、结果或明确错误状态可见；选择依据来自实际 UI，而非固定坐标猜测。

- [ ] **Step 6: 打开详情并验证标题、封面和元数据**

Tap the selected result card. Wait up to 30 seconds for the detail hero panel.

Pass conditions:

- 显示非空标题。
- 显示封面图或明确的封面回退占位，不是破损布局。
- 至少显示年份、形态、评分、标签、简介或集数中的一项基础元数据。
- 页面没有未处理异常；不得点击 `立即播放` 或任何剧集。

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
& $adb -s $serial shell screencap -p /sdcard/weila-04-detail.png
& $adb -s $serial pull /sdcard/weila-04-detail.png (Join-Path $runDir '04-detail.png')
& $adb -s $serial shell uiautomator dump /sdcard/weila-04-detail.xml
& $adb -s $serial pull /sdcard/weila-04-detail.xml (Join-Path $runDir '04-detail.xml')
& $adb -s $serial shell rm -f /sdcard/weila-04-detail.png /sdcard/weila-04-detail.xml
```

Inspect `04-detail.png` visually and verify `04-detail.xml` contains the selected title plus at least one non-empty metadata value.

- [ ] **Step 7: 打开设置并验证三项 Android 能力门控**

Tap the masthead action labeled `个人与设置`; wait for `设置中心`.

Verify all of the following visually and through UI hierarchy:

1. 全局导航不存在 `下载`。
2. 数据源区域不存在 `管理数据源` 和 `添加数据源`。
3. `弹幕服务` 显示 `Android 编译基线暂不提供安全凭据存储` 与 `暂不可用`。

Tap `弹幕服务` once and confirm no credential dialog, AppId field, AppSecret field, save action, read action or clear action appears.

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
& $adb -s $serial shell screencap -p /sdcard/weila-05-settings.png
& $adb -s $serial pull /sdcard/weila-05-settings.png (Join-Path $runDir '05-settings.png')
& $adb -s $serial shell uiautomator dump /sdcard/weila-05-settings.xml
& $adb -s $serial pull /sdcard/weila-05-settings.xml (Join-Path $runDir '05-settings.xml')
& $adb -s $serial shell rm -f /sdcard/weila-05-settings.png /sdcard/weila-05-settings.xml
```

Inspect `05-settings.png` visually before running the XML assertions in Step 8.

Expected: 三项能力门控全部成立，禁用项不可触发凭据操作。

- [ ] **Step 8: 用 UI hierarchy 固化门控断言**

Run:

```powershell
$runDir = Get-Content -LiteralPath 'D:\Vera Mobile Application Development\Acceptance\current-run.txt' -Encoding UTF8
$settingsXml = Get-Content -LiteralPath (Join-Path $runDir '05-settings.xml') -Raw -Encoding UTF8
$checks = [ordered]@{
  SettingsCenterPresent = $settingsXml.Contains('设置中心')
  CredentialUnavailablePresent = $settingsXml.Contains('暂不可用')
  AndroidCredentialMessagePresent = $settingsXml.Contains('Android 编译基线暂不提供安全凭据存储')
  DownloadHidden = -not $settingsXml.Contains('text="下载"')
  PluginManagerHidden = -not $settingsXml.Contains('管理数据源')
  PluginAddHidden = -not $settingsXml.Contains('添加数据源')
  AppIdFieldHidden = -not $settingsXml.Contains('AppId')
  AppSecretFieldHidden = -not $settingsXml.Contains('AppSecret')
}
$checks.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } | Set-Content -LiteralPath (Join-Path $runDir 'ui-assertions.txt') -Encoding UTF8
if ($checks.Values -contains $false) { Get-Content -LiteralPath (Join-Path $runDir 'ui-assertions.txt'); throw 'Android capability gate assertion failed' }
Get-Content -LiteralPath (Join-Path $runDir 'ui-assertions.txt')
```

Expected: 八项断言全部为 `True`。

- [ ] **Step 9: 采集整段验收日志并分类网络结果**

Run:

```powershell
$toolRoot = 'D:\Vera Mobile Application Development'
$adb = "$toolRoot\Android\Sdk\platform-tools\adb.exe"
$runDir = Get-Content -LiteralPath "$toolRoot\Acceptance\current-run.txt" -Encoding UTF8
$package = 'io.github.nina27486486.weila'
$serial = @(& $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '^emulator-\d+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] }) | Select-Object -First 1
$pid = (& $adb -s $serial shell pidof $package).Trim()
if (-not $pid) { throw 'Application process exited during acceptance traversal' }
& $adb -s $serial logcat -d --pid=$pid -v threadtime | Set-Content -LiteralPath (Join-Path $runDir 'acceptance-app.log') -Encoding UTF8
& $adb -s $serial logcat -b crash -d -v threadtime | Set-Content -LiteralPath (Join-Path $runDir 'acceptance-crash.log') -Encoding UTF8
& $adb -s $serial shell dumpsys activity exit-info $package | Set-Content -LiteralPath (Join-Path $runDir 'acceptance-exit-info.txt') -Encoding UTF8
$patterns = 'FATAL EXCEPTION|ANR in io\.github\.nina27486486\.weila|Unhandled Exception|FlutterError|Lost connection to device'
$hits = Get-ChildItem -LiteralPath $runDir -File | Where-Object { $_.Name -match '^acceptance-.*\.(log|txt)$' } | Select-String -Pattern $patterns
if ($hits) { $hits; throw 'Blocking runtime signal found; enter the application blocker branch.' }
```

Expected: 应用进程仍存在，无 crash、ANR 或未处理 Flutter 异常。若目录/搜索失败，使用日志证据将其归类为 DNS、TLS、超时、服务端错误、响应结构变化或真实空结果。

---

## Mandatory Failure Branch for Tasks 3–4

当环境、应用或外部网络出现失败时，不跳过、不伪造通过，也不直接进行猜测性代码修改。

### Environment failure

1. 保留本轮 `flutter-doctor.txt`、`sdk-installed.txt`、`avd-config.ini`、`emulator-accel-check.txt`、`adb devices -l` 与 Emulator 进程证据。
2. 只修复工具链、SDK 组件、AVD 或 ADB；不得修改业务代码。
3. 从失败的 Task/Step 重新执行，并保留失败前证据目录。

### External network failure

1. 使用日志把失败明确归类为 DNS、TLS、超时、服务端错误、响应结构变化或真实空结果。
2. 不启用明文流量、不关闭 TLS、不添加代理凭据、不伪造目录结果。
3. 如果应用已经显示安全错误状态，则在报告中记录“应用行为通过、外部链路阻塞”；如果界面永久加载或吞掉错误，则按应用阻塞处理。

### Application blocker

1. 在修改代码前加载 `superpowers:systematic-debugging`，用包名、PID、时间戳、堆栈和最小复现确认根因。
2. 用 `rg` 找到拥有失败行为的最小模块及现有测试文件。
3. 以已经确认的根因生成 kebab-case 文件名并创建独立修复计划，其中列出真实文件、失败测试代码、预期失败、最小实现和回归命令。例如，若根因被证实为 Android 窄屏布局溢出，文件固定为 `docs/superpowers/plans/2026-08-02-android-runtime-narrow-layout-overflow-fix.md`；根因未证实前不得创建泛化修复文件或猜测具体源码改法。
4. 使用 `superpowers:test-driven-development` 先写并运行失败测试，再做最小修复。
5. 使用 `superpowers:subagent-driven-development` 执行该修复计划，每个独立修复创建一个本地提交，并完成规范符合性与代码质量两阶段审查。
6. 执行下方“业务代码修复后的回归门槛”，然后从 Task 3 Step 4 重新构建 APK并重跑 Task 3–4。

### 业务代码修复后的回归门槛

Run in this order:

```powershell
flutter analyze
flutter test --coverage -r compact
& 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe' tool/check_coverage.dart
$junction = 'D:\Vera Mobile Application Development\Temp\weila_windows_build_src'
if (Test-Path -LiteralPath $junction) { throw "Windows build junction already exists: $junction" }
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_windows_release.ps1 -JunctionPath $junction -SkipClean
flutter build apk --debug --target lib/main_android.dart --no-pub
```

Expected:

- `flutter analyze` 通过。
- 全量测试通过；唯一真实 API 测试保持按设计跳过。
- 覆盖率不低于全仓 70% 和发布关键模块 85%。
- Windows Release 构建通过且临时 D 盘 junction 被脚本安全清理。
- Android Debug APK 再次构建通过。
- 使用 `superpowers:requesting-code-review` 做独立审查，无 Critical 或 Important 问题后再恢复运行验收。

---

### Task 5: 生成脱敏报告并完成 Git 边界审计

**Files:**
- Create: `docs/ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md`
- Read, local: current run directory under `D:\Vera Mobile Application Development\Acceptance`
- Inspect: all changed files and index state

**Interfaces:**
- Consumes: Tasks 1–4 的环境、构建、启动、截图、UI hierarchy、日志与门控断言证据。
- Produces: 可提交的脱敏运行验收报告和清晰的已验证/未验证/外部阻塞结论。

- [ ] **Step 1: 建立原始证据清单与 SHA-256**

Run:

```powershell
$runDir = Get-Content -LiteralPath 'D:\Vera Mobile Application Development\Acceptance\current-run.txt' -Encoding UTF8
Get-ChildItem -LiteralPath $runDir -File | Sort-Object Name | ForEach-Object {
  $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
  [pscustomobject]@{ Name = $_.Name; Bytes = $_.Length; Sha256 = $hash.Hash }
} | Format-Table -AutoSize | Out-String -Width 240 | Set-Content -LiteralPath (Join-Path $runDir 'evidence-manifest.txt') -Encoding UTF8
Get-Content -LiteralPath (Join-Path $runDir 'evidence-manifest.txt') -Encoding UTF8
```

Expected: 每项原始证据都有文件名、大小和 SHA-256；manifest 本身留在 D 盘，不提交。

- [ ] **Step 2: 从证据中提取报告事实**

Read these exact sources:

- `device.txt`: AVD、API、ABI、模型、分辨率与密度。
- `apk.txt`: APK 大小与 SHA-256。
- `first-launch.txt` and `second-launch.txt`: `Status`、`TotalTime`、`WaitTime`。
- `startup-signal-scan.txt`: 两次启动异常扫描。
- `ui-assertions.txt`: 八项 Android 门控断言。
- `02-category.xml`, `03-search-results.xml`, `04-detail.xml`, `05-settings.xml`: 页面最终状态。
- `acceptance-app.log`, `acceptance-crash.log`, `acceptance-exit-info.txt`: 运行异常与网络分类。
- `evidence-manifest.txt`: 本地证据完整性。

Expected: 每条报告结论都能回指一个本地证据文件；没有凭肉眼记忆填写的数值。

- [ ] **Step 3: 用 apply_patch 创建脱敏报告**

Create `docs/ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md` with these exact sections and fact sources:

1. `# 薇拉 Android API 36 运行验收报告`
2. `## 范围与结论` — 只描述应用壳、目录网络链路、详情和设置能力门控；明确排除播放、弹幕、凭据、下载、签名和发布。
3. `## 环境` — 填入 `device.txt` 与已安装组件的实际值，不写本机用户名。
4. `## 构建产物` — 填入 `apk.txt` 的字节数与 SHA-256，不写仓库绝对路径。
5. `## 启动稳定性` — 分别填入两次启动的状态、TotalTime、WaitTime、进程与异常扫描结论。
6. `## 页面与网络链路矩阵` — 对首页、发现/分类、搜索“葬送的芙莉莲”、详情、设置逐项写 `通过`、`失败` 或 `外部阻塞`，并列出证据文件 basename。
7. `## Android 能力门控` — 写入下载隐藏、插件编辑隐藏、凭据暂不可用且不可点击的八项断言结果。
8. `## 故障与修复` — 没有故障时写明“本轮未修改业务代码”；有故障时只列根因、修复提交与回归证据。
9. `## 安全与脱敏` — 明确原始证据只在 D 盘，报告不含 URL、Header、Cookie、凭据、签名材料或本机路径。
10. `## 已验证、未验证与风险` — 将本阶段实际通过项、非目标和外部依赖风险分开列出。
11. `## Git 边界` — 明确未 push、merge、升版、打标签或发布，三个 Windows 生成文件未暂存。

Do not include empty status markers or future-fill text. Every result must use the evidence observed in this run.

- [ ] **Step 4: 扫描报告中的敏感内容和模糊结论**

Run:

```powershell
$report = 'docs\ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md'
$sensitive = rg -n -i 'https?://|authorization|proxy-authorization|cookie|app.?id\s*[:=]|app.?secret|D:\\|C:\\Users\\|-----BEGIN|\.jks|\.keystore' -- $report
if ($LASTEXITCODE -eq 0) { $sensitive; throw 'Sensitive or local-only material found in report' }
if ($LASTEXITCODE -ne 1) { throw "Sensitive scan failed: $LASTEXITCODE" }
$ambiguous = rg -n '稍后补充|以后验证|未确定|占位' -- $report
if ($LASTEXITCODE -eq 0) { $ambiguous; throw 'Ambiguous report language found' }
if ($LASTEXITCODE -ne 1) { throw "Ambiguity scan failed: $LASTEXITCODE" }
```

Expected: 两项扫描均无命中。应用 ID 不需要写入报告，避免与敏感 AppId 术语混淆。

- [ ] **Step 5: 检查全仓差异且只暂存报告**

Run:

```powershell
git diff --check
git status --short --branch -uall
git diff --cached --name-only
git add -- docs/ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md
git diff --cached --check
git diff --cached --stat
git diff --cached --name-status
```

Expected: 暂存区只有 `A docs/ANDROID_RUNTIME_ACCEPTANCE_REPORT_API36.md`；三个 Windows 生成文件仍未暂存；原始 D 盘证据和 `android/local.properties` 不出现。

- [ ] **Step 6: 提交脱敏验收报告**

Run:

```powershell
git commit -m "docs(android): record API 36 runtime acceptance"
```

Expected: 本地提交只包含报告。若应用阻塞产生修复提交，它们必须已经按各自修复计划独立提交，不能揉进报告提交。

- [ ] **Step 7: 最终验证提交、空 index 与剩余工作区**

Run:

```powershell
git log --oneline -6
git show --stat --oneline --summary HEAD
git show --format= --name-status HEAD
git diff --cached --name-only
git status --short --branch -uall
git diff --check
```

Expected:

- HEAD 为 `docs(android): record API 36 runtime acceptance`。
- index 为空。
- 工作区只剩三个既存 Windows 生成文件换行差异。
- `git diff --check` 没有 whitespace error；LF/CRLF 提示单独记录。
- 没有 push、merge、版本变更、标签或 Release。

- [ ] **Step 8: 停止并向主人交付证据化结果**

Final report must include:

- AVD 名称、API、ABI 与硬件加速结果。
- APK 大小与 SHA-256。
- 两次启动时间与进程/异常结论。
- 五个页面路径和三项能力门控结论。
- 外部网络失败与应用失败的明确区分。
- 任何修复提交的哈希、文件范围和回归结果；无修复时明确写“未修改业务代码”。
- 验收报告提交哈希和剩余三个预期工作区差异。
- 明确停止，等待主人决定下一阶段；不得自动进入平台服务开发。
