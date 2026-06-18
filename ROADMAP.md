# 薇拉(weila) 开发路线图

> 基于 Qoder 竞品分析报告 + 项目现状 + qoder 路线图
> 制定时间：2026年6月18日

---

## 当前完成度：~75%

```
✅ 已完成：
  - 插件系统（HTML/JSON/CMS/GraphQL 四模式）
  - 多源搜索（跨源并行+超时+动漫过滤）
  - 视频播放器（media_kit 自定义控件+键盘快捷键）
  - 本地存储（历史/收藏/追番/设置 Hive CE）
  - 发现区（番剧/剧场版/日历/排行榜/分类浏览）
  - 下载系统（M3U8分段下载+合并mp4+离线播放）
  - 封面URL修复+CDN防盗链

❌ 未实现：
  - 图片缓存（每次启动重新下载封面）
  - 播放器真全屏（只隐藏侧边栏）
  - 搜索防抖（每次回车全量搜索）
  - 弹幕系统（核心差距）
  - 主题切换（硬编码暗色）
  - DI 未启用（Store 直接实例化）
  - 启动画面
```

---

## 第1周：技术债清零（快速提升体验）

### 目标：3个P0改动，1-2小时可完成

| 任务 | 改动文件 | 工作量 | 说明 |
|------|----------|--------|------|
| **图片缓存** | `widgets/cover_image.dart`, `pubspec.yaml` | 30min | 替换 Image.network 为 CachedNetworkImage，自动三级缓存（内存+磁盘+网络） |
| **播放器真全屏** | `pages/player/player_page.dart` | 15min | 调用 windowManager.setFullScreen(true)，加 F11 快捷键 |
| **搜索防抖** | `pages/search/search_page.dart` | 15min | Timer 500ms debounce，输入停止后才触发搜索 |

### 具体改动：

**图片缓存：**
```yaml
# pubspec.yaml
cached_network_image: ^3.4.1
```
```dart
# widgets/cover_image.dart
CachedNetworkImage(
  imageUrl: fixedUrl,
  httpHeaders: headers,
  memCacheWidth: 300,
  maxWidthDiskCache: 600,
  errorWidget: (_, __, ___) => _placeholder(),
)
```

**真全屏：**
```dart
# player_page.dart - _toggleFullscreen()
Future<void> _toggleFullscreen() async {
  if (_isFullscreen) {
    await windowManager.setFullScreen(false);
  } else {
    await windowManager.setFullScreen(true);
  }
  setState(() => _isFullscreen = !_isFullscreen);
}
// F11 快捷键在 _handleKeyEvent 中添加
```

**搜索防抖：**
```dart
# search_page.dart
Timer? _debounceTimer;
void _onSearchChanged(String query) {
  _debounceTimer?.cancel();
  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
    _store.search(query);
  });
}
```

---

## 第2周：弹幕系统（核心差异化）

### 目标：播放器可显示实时弹幕

| 任务 | 改动文件 | 工作量 | 说明 |
|------|----------|--------|------|
| **弹幕数据模型** | `models/danmaku.dart`, `models/danmaku.g.dart` | 30min | text, time, color, type 字段 |
| **弹弹play API** | `services/danmaku/danmaku_service.dart` | 2h | 搜索番剧+获取弹幕+缓存 |
| **弹幕渲染组件** | `widgets/danmaku_overlay.dart` | 2h | Canvas 绘制滚动弹幕，支持透明度/速度设置 |
| **播放器集成** | `pages/player/player_page.dart` | 1h | 叠加弹幕层+开关按钮+设置面板 |

### 弹弹play API 接入：

```dart
// services/danmaku/danmaku_service.dart
class DanmakuService {
  static const _baseUrl = 'https://api.dandanplay.net';

  // 搜索番剧获取 episodeId
  Future<List<DanmakuComment>> getDanmaku(String animeName, int episode) async {
    // 1. 搜索匹配
    final search = await _dio.get('$_baseUrl/api/v2/search/episodes',
      queryParameters: {'anime': animeName});
    // 2. 找到对应集数的 episodeId
    // 3. 获取弹幕列表
    final comments = await _dio.get('$_baseUrl/api/v2/comment/$episodeId',
      queryParameters: {'withRelated': true});
    // 4. 解析弹幕（弹弹play 使用特殊格式 p="time,mode,size,color"）
    return _parseComments(comments.data['comments']);
  }
}
```

### 弹幕渲染：

```dart
// widgets/danmaku_overlay.dart
class DanmakuOverlay extends StatefulWidget {
  // 使用 CustomPainter + Canvas 绘制
  // 滚动弹幕：从右向左匀速移动
  // 顶部/底部弹幕：固定位置
  // 碰撞检测：避免弹幕重叠
}
```

### 播放器集成：

```dart
# player_page.dart - Video 区域改为 Stack
Stack([
  Video(controller: _controller, controls: NoVideoControls),
  if (_showDanmaku) DanmakuOverlay(controller: _danmakuController),
  // ... 其他覆盖层
])
```

### 风险：
- 弹弹play API 可能需要代理访问
- 弹幕匹配依赖番剧名称，可能不准确
- 需要缓存弹幕数据避免重复请求

---

## 第3周：主题系统 + 错误处理

### 目标：支持亮/暗主题切换，错误处理统一

| 任务 | 改动文件 | 工作量 | 说明 |
|------|----------|--------|------|
| **主题定义** | `theme/app_theme.dart` | 1h | 新增 AppTheme.light + ThemeExtension |
| **主题Store** | `stores/theme_store.dart`, `.g.dart` | 30min | isDarkMode observable + 持久化 |
| **全局应用** | `app_widget.dart` | 30min | Observer 包裹 MaterialApp |
| **错误处理** | `utils/error_handler.dart` | 1h | 统一 showError/showSuccess/showLoading |
| **设置页** | `pages/settings/settings_page.dart` | 30min | 添加主题切换开关 |

### 主题系统：

```dart
// theme/app_theme.dart
class AppTheme {
  static ThemeData get dark => ThemeData(/* 现有暗色 */);
  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.grey[50],
    // ... 亮色定义
  );
}

// stores/theme_store.dart
abstract class _ThemeStore with Store {
  @observable bool isDarkMode = true;
  @action void toggleTheme() {
    isDarkMode = !isDarkMode;
    StorageService().setSetting('dark_mode', isDarkMode);
  }
}
```

### 错误处理统一：

```dart
// utils/error_handler.dart
class ErrorHandler {
  static void showError(BuildContext context, String message, {VoidCallback? onRetry}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('重试')),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
```

---

## 第4周：架构优化

### 目标：DI 启用 + 大文件拆分 + 日志增强

| 任务 | 改动文件 | 工作量 | 说明 |
|------|----------|--------|------|
| **DI 启用** | `app_module.dart` | 1h | binds() 注册所有 Service/Store |
| **拆分 plugin_service** | `services/plugin/` | 2h | → plugin_search.dart + plugin_detail.dart + plugin_cms.dart |
| **拆分 player_page** | `pages/player/` | 2h | → player_controls.dart + episode_sidebar.dart + player_page.dart |
| **日志增强** | `utils/logger.dart` | 1h | 时间戳+级别+文件输出+Release可开启 |

### DI 注册：

```dart
// app_module.dart
@override
void binds(i) {
  i.addSingleton<PluginService>(() => PluginService());
  i.addSingleton<DownloadService>(() => DownloadService());
  i.addSingleton<StorageService>(() => StorageService());
  i.addLazySingleton<HistoryCollectStore>(() => HistoryCollectStore());
  i.addLazySingleton<AnimeStore>(() => AnimeStore());
  i.addLazySingleton<HomeStore>(() => HomeStore());
  i.addLazySingleton<ThemeStore>(() => ThemeStore());
}
```

### 日志增强：

```dart
// utils/logger.dart
class Log {
  static bool enableFileLog = false;
  static File? _logFile;

  static void d(String tag, String message) {
    if (kDebugMode) print('[$tag] $message');
    _writeToFile('DEBUG', tag, message);
  }

  static void _writeToFile(String level, String tag, String msg) {
    if (!enableFileLog) return;
    _logFile?.writeAsStringSync(
      '${DateTime.now()} [$level][$tag] $msg\n',
      mode: FileMode.append,
    );
  }
}
```

---

## 第5周：体验打磨 + 发布准备

### 目标：骨架屏 + 启动画面 + 性能优化 + 打包

| 任务 | 改动文件 | 工作量 | 说明 |
|------|----------|--------|------|
| **启动画面** | `main.dart`, `pubspec.yaml` | 30min | flutter_native_splash |
| **骨架屏** | `widgets/skeleton.dart` | 1h | 首页/搜索/详情加载骨架 |
| **搜索历史** | `pages/search/search_page.dart` | 30min | Hive 存最近10条，下拉显示 |
| **Release 打包** | `看番Release/` | 1h | flutter build windows --release |
| **性能测试** | - | 1h | 冷启动时间、内存占用、播放流畅度 |

---

## 依赖关系图

```
Week 1 (技术债)
  ├── 图片缓存 ← 独立，无依赖
  ├── 真全屏 ← 独立，无依赖
  └── 搜索防抖 ← 独立，无依赖

Week 2 (弹幕)
  └── 弹幕系统 ← 依赖 Week 1 完成（图片缓存释放网络带宽）

Week 3 (主题+错误)
  ├── 主题切换 ← 独立
  └── 错误处理 ← 独立，但建议先做（后续模块统一用）

Week 4 (架构)
  ├── DI 启用 ← 建议先做（影响后续拆分）
  ├── 文件拆分 ← 依赖 DI
  └── 日志增强 ← 独立

Week 5 (打磨)
  ├── 骨架屏 ← 依赖图片缓存
  ├── 启动画面 ← 独立
  └── Release 打包 ← 依赖所有功能完成
```

---

## 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 弹弹play API 被墙 | 中 | 高 | 备选：自建弹幕源或本地弹幕文件 |
| cached_network_image 中文路径问题 | 低 | 中 | 测试确认，必要时手写缓存 |
| DI 改造影响现有功能 | 中 | 高 | 渐进式：先注册新模块，旧模块保持直接实例化 |
| Release 编译中文路径 | 高 | 中 | 复用 Debug 经验，flutter clean 后编译 |
| window_manager 全屏在某些系统异常 | 低 | 低 | try-catch + 回退到现有行为 |

---

## 与 qoder 的分工

| 角色 | 职责 | 工具 |
|------|------|------|
| **qoder (Qwen3.7-max)** | 代码分析、方案设计、代码审查、复杂逻辑实现 | qodercli CLI |
| **薇拉 (MIMO)** | 协调、执行、编译验证、UI 实现、与主人沟通 | Hermes Agent |
| **主人** | 需求确认、测试验证、最终决策 | - |

### 协作模式：
1. 薇拉收到任务 → 调用 qoder 分析方案
2. qoder 返回方案 → 薇拉执行编码
3. 编译通过 → 主人测试验证
4. 发现问题 → qoder 审查代码 → 薇拉修复

---

## 预期成果

5周后的薇拉：
- ✅ 图片秒加载（缓存）
- ✅ 真全屏播放（F11）
- ✅ 实时弹幕（弹弹play）
- ✅ 亮/暗主题切换
- ✅ 统一错误处理
- ✅ 清晰的架构（DI + 拆分）
- ✅ 可发布的 Release 版本

**完成度目标：95%+**

---

*薇拉制定于 2026年6月18日*
