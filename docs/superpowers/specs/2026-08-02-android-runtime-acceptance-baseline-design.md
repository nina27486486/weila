# 薇拉 Android 运行验收基线设计

- 日期：2026-08-02
- 分支：`codex/android-mvp`
- 编译基线：`bdb72d5`
- 验收目标：API 36、Google APIs、x86_64 Android 模拟器

## 背景与现状

薇拉 Android MVP 已建立可编译基线：Android Runner、移动端入口、平台能力隔离与依赖闭包测试已经进入分支，并已通过静态分析、全量测试、Android Debug APK 构建和 Windows Release 回归。现阶段只证明代码能够面向 Android 编译，尚未建立真实 Android 运行、交互和目录网络链路的验收证据。

本机移动端工具链父目录已从 `D:\移动端开发` 更名为 `D:\Vera Mobile Application Development`。Android Studio、Android SDK 与 JDK 17 的实体文件仍在新目录中，但 Flutter 配置和 Android 本地 SDK 配置仍引用旧目录。Android Emulator、API 36 Google APIs x86_64 系统镜像和 AVD 尚未安装或创建，当前也没有已连接的 Android 设备。

本设计在编译基线之上建立可重复的运行验收环境，并把“能编译”推进到“能在固定 API 36 模拟器上冷启动、导航并完成目录网络链路”。

## 目标与成功标准

本阶段目标如下：

1. 将 Flutter 使用的 Android Studio、Android SDK 与 JDK 17 路径更新到新的 D 盘目录。
2. 安装 Android Emulator 和 API 36 Google APIs x86_64 系统镜像。
3. 创建固定、可复用且数据完全位于 D 盘的验收 AVD。
4. 从 `lib/main_android.dart` 构建、安装并启动薇拉 Android Debug 应用。
5. 验收首页、发现或分类、搜索、详情和设置页面的关键路径。
6. 验证目录网络链路能够返回有效内容，或在真实空结果下显示明确且安全的空状态。
7. 采集可审计的启动、崩溃、ANR、Flutter 异常、界面和网络链路证据。
8. 若发现本阶段阻塞，采用测试驱动方式做最小范围修复，并完成 Android 与 Windows 回归。

全部满足以下条件时，本阶段通过：

- API 36 AVD 能在规定时限内完成冷启动并被 ADB 识别。
- 应用首次安装后的冷启动和 `force-stop` 后的第二次冷启动均成功。
- 启动期间没有应用进程异常退出、ANR、未处理的 Flutter 异常或永久白屏。
- 首页能够完成首屏呈现，关键导航入口可以到达。
- 搜索能够返回结果，或在服务端真实无结果时显示明确空状态。
- 详情页能显示标题、封面和基础元数据。
- Android 不支持的桌面能力按设计被门控，不出现可误触入口。
- 原始验收证据仅保存在本机；进入仓库的报告经过脱敏。

## 非目标

本阶段不包含：

- 视频播放、清晰度切换、全屏与横竖屏播放验收。
- 弹幕匹配、弹幕渲染或真实凭据配置验收。
- 离线下载、缓存写入或文件管理验收。
- 将 Windows Credential Manager 方案直接迁移到 Android。
- 代理凭据、Cookie、Header、AppId、AppSecret 或签名材料配置。
- Android Release 签名、商店包、版本升级、标签或发布。
- 推送、合并或改动 Windows 1.0 发布历史。
- 为通过验收而启用全局明文流量、关闭 TLS 校验或加入不受约束的网络绕过。

## 环境与路径设计

统一工具链根目录为：

```text
D:\Vera Mobile Application Development
```

固定路径如下：

```text
Android Studio: D:\Vera Mobile Application Development\Android Studio
Android SDK:    D:\Vera Mobile Application Development\Android\Sdk
JDK 17:         D:\Vera Mobile Application Development\JDK17
AVD 数据:       D:\Vera Mobile Application Development\Android\Avd
```

Flutter 的 `android-studio-dir`、`android-sdk` 和 `jdk-dir` 更新到上述实体路径；项目忽略文件 `android/local.properties` 的 `sdk.dir` 同步到新 SDK 路径。系统级 `JAVA_HOME` 不在本阶段修改，以避免影响其他项目。

在用户级环境变量中设置 `ANDROID_AVD_HOME` 指向固定的 D 盘 AVD 数据目录，使 Android Studio、Flutter、`avdmanager` 和 `emulator` 读取同一份 AVD。无需建立临时盘符映射或目录联接；新根目录全为 ASCII 字符，可直接用于 Gradle、Flutter 和 Android 命令行工具。

上述路径配置属于本机环境，不进入 Git。仓库中既存的三个 Windows Flutter 生成文件换行差异继续保留且不暂存。

## AVD 配置与供应

安装以下 SDK 组件：

```text
emulator
system-images;android-36;google_apis;x86_64
```

验收 AVD 固定命名为：

```text
Weila_API_36_Google_APIs
```

AVD 使用本机 `avdmanager` 可用列表中的 Pixel 手机硬件配置，优先选择稳定的常规手机规格，不使用折叠屏、平板或电视配置。系统镜像为 API 36 Google APIs x86_64，并使用本机已启用的硬件虚拟化加速。

正式验收时以可见窗口启动模拟器，便于人工确认界面、导航和错误状态。首次正式验收使用冷启动且不加载旧快照，排除陈旧内存状态对结果的干扰；后续重复验收可以保留 AVD 用户数据，但必须明确记录启动方式。

模拟器启动设置有明确超时。超时后收集 `emulator` 进程状态、ADB 设备状态、启动属性与相关日志，然后停止本轮，不无限等待或反复破坏性重建 AVD。

## 混合式执行架构

本阶段采用“命令行确定性供应 + 可见模拟器交互 + ADB 证据采集”的混合方式：

- 命令行负责 SDK 组件安装、许可证检查、AVD 创建、冷启动、开机等待、APK 构建、安装、启动和日志采集。
- 可见模拟器负责真实观察首屏、页面切换、加载态、空状态与错误提示。
- ADB 负责进程状态、Activity 启动、`logcat`、界面层级和截图等可重复证据。

环境供应步骤保持幂等：已安装的 SDK 组件不重复下载；已存在且配置匹配的 AVD 复用；配置不匹配时先输出差异并只处理该验收 AVD，不操作其他 AVD。

## 运行验收流程

### 1. 模拟器冷启动

1. 启动 `Weila_API_36_Google_APIs`，禁用旧快照加载。
2. 等待设备进入 ADB `device` 状态。
3. 等待 `sys.boot_completed=1`。
4. 解锁屏幕并确认 Launcher 可交互。

### 2. 构建、安装与启动

1. 从 `lib/main_android.dart` 构建 Android Debug APK。
2. 将 APK 安装到专用验收 AVD。
3. 清理本轮相关 `logcat` 缓冲或建立清晰的采集起点。
4. 启动包 `io.github.nina27486486.weila`。
5. 记录 Activity 首次显示、Flutter 首帧、应用进程状态和异常信号。

### 3. 页面与目录网络链路

按顺序验收以下路径：

| 路径 | 操作 | 通过条件 | 主要证据 |
| --- | --- | --- | --- |
| 首页 | 冷启动进入应用 | 首屏可见，不永久停留在骨架屏或白屏 | 截图、启动日志、进程状态 |
| 发现或分类 | 从首页进入内容浏览 | 页面可达，加载完成或出现明确安全状态 | 截图、界面层级、相关日志 |
| 搜索 | 搜索一个稳定的动画标题 | 返回结果，或服务端真实无结果时显示明确空状态 | 截图、界面层级、脱敏日志 |
| 详情 | 打开一个搜索或目录结果 | 标题、封面和基础元数据可见 | 截图、界面层级、脱敏日志 |
| 设置 | 打开设置页面 | 页面可达，Android 能力门控显示正确 | 截图、界面层级 |

目录网络链路不能永久停留在加载态，不能抛出未处理异常。若外部服务返回空数据，必须区分“真实空结果”与“请求失败后伪装为空”；错误应以当前产品可接受的安全状态呈现，并在诊断证据中保留原因分类。

### 4. Android 能力门控

本阶段确认：

- 不显示离线下载入口。
- 不显示桌面插件编辑入口。
- 弹幕凭据功能明确显示为 Android 暂不可用，且不存在可误触的保存、读取或清除动作。

这些门控只验证现有隔离行为，不在本阶段实现 Android 原生全屏、安全凭据或下载服务。

### 5. 重启稳定性

首次安装冷启动通过后：

1. 使用 `force-stop` 停止应用。
2. 再次启动同一应用。
3. 复查进程、ANR、Flutter 异常和首屏呈现。

两次启动均通过，才认定运行基线稳定。

## 证据、安全与脱敏

本地原始证据包括：

- 首页、发现或分类、搜索结果、详情和设置截图。
- 验收时段的 `logcat`。
- 必要的 UI hierarchy XML。
- ADB 设备、启动属性、应用进程和 Activity 状态。
- APK 路径、大小和 SHA-256。

原始证据仅保存在本机验收目录，不直接提交。仓库中的验收报告只记录必要结论、命令、时间、设备规格、结果和经过脱敏的错误摘要。

写入报告前检查并移除：完整媒体 URL、请求 Header、Cookie、代理地址与凭据、AppId、AppSecret、签名材料、本机用户名以及无关的本机绝对路径。截图若出现账号信息、搜索历史或其他个人数据，先打码或改用无敏感信息的重拍证据。

## 故障分类与修复边界

### 环境故障

包括 Emulator 安装、虚拟化加速、系统镜像、AVD 启动和 ADB 连接问题。此类问题只调整本机工具链与验收 AVD，不修改业务代码，也不影响其他 AVD。

### 应用阻塞

包括冷启动崩溃、永久白屏、关键导航不可达、目录或搜索无法使用、详情无法显示关键内容。本阶段允许修复这些阻塞，但必须：

1. 先用失败测试或可重复的最小诊断证据锁定问题。
2. 只修改拥有该行为的最小模块。
3. 不顺带扩展播放、弹幕、下载或凭据能力。
4. 为修复增加聚焦测试，并运行完整回归。

### 外部网络故障

区分 DNS、TLS、超时、服务端错误、响应结构变化和真实空结果。网络故障不以全局允许明文流量、关闭证书验证、硬编码代理凭据或提交敏感请求材料来规避。若外部服务持续不可用，应保留诊断证据并报告外部阻塞，不伪造成功结果。

## 测试与回归门槛

若验收只涉及本机环境配置，不产生业务代码改动，则运行环境诊断、Android Debug APK 构建和两次运行验收即可；仓库保持不变。

若修复了业务代码，则依次执行：

1. 与缺陷对应的失败测试和聚焦测试。
2. `flutter analyze`。
3. 全量 Flutter 测试及覆盖率检查。
4. 从 `lib/main_android.dart` 构建 Android Debug APK。
5. 在固定 AVD 上重跑完整运行验收。
6. 使用项目既有脚本完成 Windows Release 构建回归。
7. 对变更进行独立代码审查，处理阻塞性意见。

任何未执行或受外部条件限制的验证必须单独列为未验证风险，不能与已通过结果混写。

## 交付物与 Git 边界

本阶段交付：

- 固定在 D 盘的 API 36 Google APIs x86_64 验收 AVD。
- 本机原始截图、日志和界面层级证据。
- 一份经过脱敏的 Android 运行验收报告。
- 如发生本阶段阻塞修复，按功能边界创建独立本地提交。

本阶段不推送、不合并、不升版、不打标签、不创建 Release。机器级 Flutter、SDK、JDK、AVD 和环境变量配置不提交。三个既存 Windows Flutter 生成文件换行差异不得暂存。

## 后续阶段

运行验收基线通过并由主人确认后，下一阶段再设计和实现 Android 平台服务，包括真实全屏与方向控制、安全凭据存储，以及后续播放链路所需的平台能力。本设计不授权提前实现这些能力。
