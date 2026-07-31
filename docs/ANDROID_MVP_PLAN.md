# 薇拉 Android 播放优先 MVP 计划

更新日期：2026-07-30

## 1. 目标与边界

Android 首版采用同仓平台适配，不复制 Windows 应用或另建独立仓库。目录、播放源、
线路健康、弹幕、收藏、追番和历史模型继续共用；窗口、全屏、凭据、文件选择和安装发布
通过平台接口隔离。

首个公开测试版规划为 `1.1.0-beta.1+6`，稳定版规划为 `1.1.0+7`。Windows 1.0 发布
门槛优先，Android 开发不阻塞 `v1.0.0` 收口。

首版包含：

- 首页、发现/分类、搜索、详情。
- 收藏、追番、历史。
- 多线路、多清晰度、自动健康度选择与安全验收报告。
- 弹弹play匹配、真实弹幕、FakePlayer 调试与 seek 同步。
- 手机和平板响应式界面。
- Windows 数据的手动安全导入/导出。

首版不包含：

- Android 离线下载和后台下载。
- Android 插件编辑器或第三方插件安装。
- 云同步、账号系统、自动更新、Google Play 和 iOS。
- 全局明文 HTTP 放行。

## 2. 工具链与 Android Runner

- 安装 Android Studio、Android SDK 36、JDK 17，并通过 `flutter doctor -v`。
- 在现有 Flutter 工程生成 Android runner，不覆盖当前 Dart 源码。
- 应用 ID 与 namespace 固定为 `io.github.nina27486486.weila`。
- 固定 `compileSdk 36`、`targetSdk 36`、`minSdk 24`。
- 添加 `INTERNET` 与播放所需的最小权限；默认禁用 cleartext traffic。
- Android 自动备份关闭，避免安全存储的加密材料被跨设备恢复后无法解密。
- release keystore 与 `key.properties` 保存在仓库外，并加入忽略与泄漏扫描规则。

## 3. 平台接口

```dart
abstract interface class AppWindowController {
  Future<void> initialize();
}

abstract interface class FullscreenController {
  Future<void> enterVideoFullscreen();
  Future<void> exitVideoFullscreen();
}

abstract interface class DanmakuCredentialStoreFactory {
  DanmakuCredentialStore create();
}
```

- Windows 实现继续使用 `window_manager`、Windows Credential Manager 和现有下载服务。
- Android 的窗口初始化为空操作；视频全屏使用 `SystemChrome` 切换沉浸模式和横屏方向，
  退出播放器时恢复进入前方向与系统栏状态。
- Windows FFI 与 `win32` 只通过条件导入进入 Windows 编译单元，Android 不解析这些
  文件。
- Android 弹弹play凭据使用 `flutter_secure_storage` 默认 RSA-OAEP + AES-GCM；
  生产环境不回退到 Hive 明文。
- 启动流程按“存储 → 平台凭据 → 插件/目录 → UI”执行，凭据服务不可用不得阻止
  `runApp`，应进入可重试的降级状态。

## 4. 移动界面与播放器

- 小于 600 logical pixels 使用底部导航；600–839 使用紧凑平板布局；840 及以上使用
  NavigationRail 或宽屏内容栏。Windows 现有 960+ 布局保持不变。
- 手机浏览默认竖屏，进入视频全屏后横屏沉浸；系统返回键先关闭控制面板/抽屉，再退出
  全屏，最后返回详情。
- 单击视频显示或隐藏控制层；双击左/右区域后退或前进 10 秒；中央双击播放/暂停。
- 适配应用后台、锁屏、音频焦点、耳机断开和横竖屏重建，所有订阅和定时器按当前播放
  代次释放。
- 视频舞台保持纯黑；触控控件满足最小点击区域、系统字体放大和减少动画设置。
- Android 只接受 HTTPS API 和媒体线路；HTTP 线路显示安全原因并尝试其他线路，
  不使用 `usesCleartextTraffic=true` 全局绕过。

## 5. 便携数据格式

```dart
class WeilaPortableBackupV1 {
  int schemaVersion; // 固定为 1
  DateTime exportedAtUtc;
  String appVersion;
  List<Map<String, Object?>> favorites;
  List<Map<String, Object?>> history;
  List<Map<String, Object?>> following;
  Map<String, Object?> safeSettings;
}
```

- 只导出收藏、追番、历史和白名单设置。
- 禁止导出弹弹play凭据、代理、插件 Header/Cookie、下载、缓存、本机路径和完整媒体
  URL。
- 有 `contentId` 时以其为主键；旧记录回退到 `animeUrl`。重复导入必须幂等。
- 历史冲突保留最新观看时间和最大有效进度；收藏/追番保留较新的用户状态。
- 导入前完整校验 schema、字段类型、数量和文件大小；失败不写入任何 Hive box。
- 导入使用 `file_selector`；导出写临时 JSON 后通过 `share_plus` 调用系统分享面板。

## 6. 分阶段实施

1. **编译基线**：生成 runner，隔离 Windows import，让空白 Android 壳完成 debug 构建。
2. **平台服务**：实现窗口、全屏、凭据、文件与能力开关，并加入内存测试实现。
3. **移动导航**：完成首页、分类、搜索、详情和资料库的手机/平板布局。
4. **播放与弹幕**：接入 media_kit Android、触控控制、生命周期、线路切换和弹幕。
5. **数据便携**：实现安全备份、事务式导入和跨 Windows/Android 兼容测试。
6. **质量与发布**：增加 Android CI、模拟器矩阵、实体机验收和签名 APK 任务。

## 7. 测试与发布

- 单元测试复用现有目录、播放、弹幕、报告和 Hive 兼容测试；平台服务使用 fake。
- Widget 覆盖 360、600、840、1280 宽度、深浅主题、系统字体放大、旋转和减少动画。
- 模拟器覆盖 API 24、29、34、36；至少一台 arm64 实体手机覆盖锁屏恢复、后台返回、
  音频中断、安全存储和横竖屏。
- 普通 CI 运行 analyze、全量测试和 debug APK；发布任务只从 GitHub Secrets恢复
  keystore 并生成签名产物。
- GitHub Release提供 arm64-v8a 主 APK和 universal 兼容 APK，同时提供 SHA-256。
- 美国网络运行自动化、FakePlayer 和弹弹play API；中国大陆媒体源仍由主人执行真实
  播放矩阵。

Android MVP通过条件：

- 冷启动无白屏，目录和本地资料可用。
- 可完成解析、播放、暂停、seek、换线、清晰度切换和生命周期恢复。
- 换线续播误差不超过 3 秒，seek 不产生弹幕洪峰。
- 预期有弹幕的样本获取、解析、排队、发射、渲染均大于 0，且
  `errorStage = "none"`。
- 导入导出不包含凭据、Header、Cookie、完整媒体 URL 或本机路径。

参考：

- [Flutter Android 发布文档](https://docs.flutter.dev/deployment/android)
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [file_selector](https://pub.dev/packages/file_selector)
- [share_plus](https://pub.dev/packages/share_plus)
