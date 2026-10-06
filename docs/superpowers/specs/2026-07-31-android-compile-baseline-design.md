# 薇拉 Android 编译基线设计

日期：2026-07-31
分支：`codex/android-mvp`
基线：`25721d0`（Windows `v1.0.0`）

## 1. 目标

首个 Android 子项目只建立可重复验证的编译基线：安装固定工具链、生成 Android
runner、隔离 Windows 专属能力，并让最小 Android debug APK 完成构建。现有目录、播放、
弹幕、诊断和本地数据模型继续共用，不复制 Flutter 仓库或 Dart 业务代码。

完成条件：

- Android Studio、Android SDK 36、JDK 17 安装在 `D:\移动端开发` 下。
- `flutter doctor -v` 能识别 Android 工具链，Android licenses 已接受。
- runner 使用 `io.github.nina27486486.weila`、`compileSdk 36`、`targetSdk 36`、
  `minSdk 24`。
- Android debug APK 能从专用入口点构建。
- Android 编译路径不导入 `window_manager`、`win32` 或 Windows Credential Manager
  实现。
- Windows 默认入口、全量静态检查、测试和 Release 构建不回归。

## 2. 非目标

本阶段不实现移动导航、响应式页面、触控播放器、Android 安全凭据、数据导入导出、
Android 下载、签名 APK、CI 设备矩阵或 Google Play。版本保持 Windows
`1.0.0+5`，不提前改为 `1.1.0-beta.1+6`。

## 3. 工具链布局

所有新增工具安装到主人指定目录，避免覆盖现有 `D:\develop\JDK`：

- Android Studio：`D:\移动端开发\Android Studio`
- Android SDK：`D:\移动端开发\Android\Sdk`
- JDK 17：`D:\移动端开发\JDK17`

Flutter 使用自身配置项分别指向 Android Studio、SDK 和 JDK 17。保留系统当前
`JAVA_HOME`，不把其他 Java 项目强制切换到 JDK 17。SDK 至少安装 Android 36
platform、对应 build-tools、platform-tools 和 command-line tools。模拟器与 AVD 不属于
本阶段阻断项，可在移动界面或设备验收阶段补充。

下载地址、安装包版本和校验方式在执行时仅从 Flutter、Android 与 JDK 发行方的官方来源
核对。任何下载或校验失败都停止安装，不使用第三方镜像安装器或未知脚本。

## 4. 隔离策略

Android 工作位于项目本地 linked worktree：

- 路径：`.worktrees/android-mvp`
- 分支：`codex/android-mvp`
- 起点：`25721d0`

Windows `master` 与已发布产物不在本工作树中修改。Android runner 只在该分支生成。
生成前记录 Git 状态，生成后逐项审查，若命令覆盖既有 Dart 文件或无关配置则立即停止。

## 5. 入口点与平台边界

采用“共享启动协调器 + 平台入口点”结构，避免用运行时 `Platform.isWindows` 掩盖
编译期依赖：

- `lib/main.dart` 继续作为 Windows 默认入口，保持现有 Windows 开发与发布命令兼容。
- 新增 `lib/main_android.dart` 作为 Android 构建入口。
- 共享初始化被提取到平台无关的启动协调器；平台入口只负责组装平台实现与能力开关。
- Android 构建和后续 CI 始终显式使用 `-t lib/main_android.dart`。

这种方式比让一个入口同时导入所有平台实现更安全：Android AOT 编译从依赖图上不会触达
Windows FFI 文件，Windows 用户也无需改变默认 `flutter run -d windows` 习惯。

### 5.1 窗口初始化

定义 `AppWindowController`：

- Windows 实现封装现有 `window_manager` 初始化、窗口尺寸、居中、显示与聚焦。
- Android 实现为空操作。
- 共享启动协调器只依赖接口，不导入 `window_manager`。

### 5.2 视频全屏

定义 `FullscreenController`，替换播放器页面和视图对 `windowManager.setFullScreen` 的直接
调用：

- Windows 实现保持当前桌面全屏行为。
- Android 基线实现先安全返回；真正的 `SystemChrome` 横屏沉浸逻辑留到平台服务阶段。
- 播放器继续保持纯黑视频舞台，展示组件只接收接口或回调。

### 5.3 弹幕凭据

`DanmakuCredentialManager` 不再在共享文件中直接构造
`WindowsDanmakuCredentialStore`，改为注入 `DanmakuCredentialStore` 或工厂：

- Windows 入口注入现有 Credential Manager 实现。
- Android 编译基线注入“暂不可用”的安全实现；它返回可重试降级状态，不读取 Hive
  明文，也不阻止 `runApp`。
- `flutter_secure_storage` 的真实 Android 实现留到平台服务阶段，通过 TDD 引入。

### 5.4 下载与插件能力

Android 入口不初始化 Windows 下载服务，并通过平台能力开关隐藏或禁用 Android MVP
明确不支持的下载和插件编辑能力。目录与插件读取逻辑只有在确认不依赖 Windows 专属
代码时才进入共享启动路径。

## 6. Android runner 安全配置

使用当前 Flutter SDK 为既有工程新增 Android 平台文件，不覆盖 `lib/`、测试或 Windows
runner。生成后固定：

- `applicationId` / `namespace`：`io.github.nina27486486.weila`
- `compileSdk`：36
- `targetSdk`：36
- `minSdk`：24
- Java/Kotlin JVM target：17
- 仅添加 `INTERNET` 等当前编译基线所需的最小权限
- 禁止 cleartext traffic，不设置全局 `usesCleartextTraffic=true`
- 关闭 Android 自动备份与数据提取规则
- release keystore、`key.properties` 与签名材料保持仓库外，并由忽略规则保护

本阶段只构建 debug APK，不创建 release 签名配置。

## 7. 启动流程与错误处理

Android 启动顺序保持为：Flutter binding 与 media_kit → 平台窗口空操作 → Hive → 平台
凭据降级实现 → 共享目录/插件能力 → UI。

错误处理原则：

- 平台凭据不可用不得阻止启动，只产生不含底层异常和凭据的安全状态。
- Android 不支持的下载或插件编辑入口必须显式禁用，不能在点击后才崩溃。
- HTTP 媒体线路不能通过全局明文放行绕过；本阶段只保证配置正确，不主动探测大陆线路。
- runner 生成或构建若修改无关文件、泄漏本机路径或产生签名材料，立即停止并报告。

## 8. 测试策略

遵循 TDD。先写失败测试，再做最小实现：

1. 平台接口 fake/no-op 的单元测试。
2. 启动协调器顺序、失败降级和“不初始化下载”的测试。
3. 源码边界测试，禁止 Android 入口依赖 `window_manager`、`win32`、Windows
   Credential Manager 或 Windows 下载初始化。
4. 现有 Windows 凭据、播放器全屏和启动行为回归测试。

最终验证命令：

```powershell
git diff --check
flutter analyze
flutter test
flutter build apk --debug -t lib/main_android.dart
powershell -NoProfile -ExecutionPolicy Bypass -File tool/build_windows_release.ps1
```

APK 构建成功只证明编译基线，不等于冷启动、播放、旋转或实体机验收通过。

## 9. 交付边界

本阶段预计形成小而可审查的本地提交：工具链配置证据不包含本机密钥；runner、平台接口、
启动隔离和测试分别保持清晰边界。未经主人再次确认，不推送、不合并、不升版、不打标签、
不创建 Android Release。
