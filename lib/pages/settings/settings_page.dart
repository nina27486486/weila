import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/danmaku/danmaku_service.dart';
import '../../services/plugin/plugin_service.dart';
import '../../services/storage/storage_service.dart';
import '../../stores/theme_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/error_handler.dart';
import '../../widgets/vira_page_chrome.dart';
import 'widgets/settings_components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _danmakuAppIdKey = 'dandanplay_app_id';
  static const _danmakuAppSecretKey = 'dandanplay_app_secret';

  final _scrollController = ScrollController();
  final _sectionKeys = List.generate(5, (_) => GlobalKey());

  int _selectedSection = 0;
  int _cacheBytes = 0;
  bool _scanningCache = true;
  bool _clearingCache = false;
  String _version = AppConstants.appVersion;

  List<SettingsNavDestination> get _destinations => const [
        SettingsNavDestination(
          icon: Icons.palette_outlined,
          selectedIcon: Icons.palette_rounded,
          label: '外观',
        ),
        SettingsNavDestination(
          icon: Icons.play_circle_outline_rounded,
          selectedIcon: Icons.play_circle_fill_rounded,
          label: '播放与弹幕',
        ),
        SettingsNavDestination(
          icon: Icons.extension_outlined,
          selectedIcon: Icons.extension_rounded,
          label: '数据源',
        ),
        SettingsNavDestination(
          icon: Icons.storage_outlined,
          selectedIcon: Icons.storage_rounded,
          label: '存储',
        ),
        SettingsNavDestination(
          icon: Icons.info_outline_rounded,
          selectedIcon: Icons.info_rounded,
          label: '关于',
        ),
      ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadCacheSize());
    unawaited(_loadPackageInfo());
    _restoreDanmakuCredentials();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _restoreDanmakuCredentials() {
    final storage = StorageService();
    final appId = storage.getSetting<String>(_danmakuAppIdKey) ?? '';
    final appSecret = storage.getSetting<String>(_danmakuAppSecretKey) ?? '';
    if (appId.isNotEmpty && appSecret.isNotEmpty) {
      DanmakuService().setCredentials(appId, appSecret);
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {}
  }

  Future<void> _loadCacheSize() async {
    if (mounted) setState(() => _scanningCache = true);
    await Future<void>.delayed(Duration.zero);
    final memoryBytes = PaintingBinding.instance.imageCache.currentSizeBytes;
    if (!mounted) return;
    setState(() {
      _cacheBytes = memoryBytes;
      _scanningCache = false;
    });
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清理临时缓存？'),
        content: const Text(
          '将清理封面图片与弹幕内存缓存，不会影响收藏、观看历史和已下载内容。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认清理'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearingCache = true);
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      DanmakuService().clearCache();
      await DefaultCacheManager().emptyCache();

      if (!mounted) return;
      setState(() {
        _cacheBytes = 0;
        _clearingCache = false;
      });
      ErrorHandler.showSuccess(context, '临时缓存已清理');
    } catch (_) {
      if (!mounted) return;
      setState(() => _clearingCache = false);
      ErrorHandler.showError(context, '部分缓存未能清理，请稍后重试');
    }
  }

  Future<void> _scrollToSection(int index) async {
    setState(() => _selectedSection = index);
    final sectionContext = _sectionKeys[index].currentContext;
    if (sectionContext == null) return;
    await Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _showDanmakuSettings() async {
    final storage = StorageService();
    final appIdController = TextEditingController(
      text: storage.getSetting<String>(_danmakuAppIdKey) ?? '',
    );
    final appSecretController = TextEditingController(
      text: storage.getSetting<String>(_danmakuAppSecretKey) ?? '',
    );
    var obscureSecret = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('弹幕服务凭证'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连接弹弹play开放平台后，可为匹配到的剧集加载在线弹幕。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '申请地址：dandanplay.com/dev',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryBlue,
                      ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: appIdController,
                  decoration: const InputDecoration(
                    labelText: '应用 ID',
                    hintText: '输入弹弹play应用 ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: appSecretController,
                  obscureText: obscureSecret,
                  decoration: InputDecoration(
                    labelText: '应用密钥',
                    hintText: '输入弹弹play应用密钥',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      tooltip: obscureSecret ? '显示密钥' : '隐藏密钥',
                      onPressed: () => setDialogState(
                        () => obscureSecret = !obscureSecret,
                      ),
                      icon: Icon(
                        obscureSecret
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final appId = appIdController.text.trim();
                final appSecret = appSecretController.text.trim();
                if (appId.isEmpty || appSecret.isEmpty) {
                  ErrorHandler.showError(context, '请完整填写应用 ID 与密钥');
                  return;
                }
                await Future.wait([
                  storage.setSetting(_danmakuAppIdKey, appId),
                  storage.setSetting(_danmakuAppSecretKey, appSecret),
                ]);
                DanmakuService().setCredentials(appId, appSecret);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) {
                  setState(() {});
                  ErrorHandler.showSuccess(this.context, '弹幕服务凭证已保存');
                }
              },
              child: const Text('保存凭证'),
            ),
          ],
        ),
      ),
    );

    appIdController.dispose();
    appSecretController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plugins = PluginService().plugins;
    final enabledPlugins = plugins.where((plugin) => plugin.enabled).length;
    final themeStore = Modular.get<ThemeStore>();

    return ViraPageScaffold(
      activeDestination: null,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: themeStore.toggleTheme,
      onProfile: () {},
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: SettingsChapterIndex(
              destinations: _destinations,
              selectedIndex: _selectedSection,
              onSelected: _scrollToSection,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _buildContent(
                themeStore: themeStore,
                pluginCount: plugins.length,
                enabledPluginCount: enabledPlugins,
                compact: constraints.maxWidth < 900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDestination(ViraDestination destination) {
    final route = switch (destination) {
      ViraDestination.home => '/',
      ViraDestination.discover => '/category',
      ViraDestination.following => '/track',
      ViraDestination.library => '/collect',
      ViraDestination.downloads => '/download',
    };
    Modular.to.navigate(route);
  }

  Widget _buildContent({
    required ThemeStore themeStore,
    required int pluginCount,
    required int enabledPluginCount,
    required bool compact,
  }) {
    final horizontalPadding = compact ? 20.0 : 34.0;
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          26,
          horizontalPadding + 8,
          42,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsHero(
                    themeLabel: themeStore.isDarkMode ? '深色模式' : '浅色模式',
                    enabledPluginCount: enabledPluginCount,
                    pluginCount: pluginCount,
                    cacheLabel:
                        _scanningCache ? '正在扫描' : _formatBytes(_cacheBytes),
                  ),
                  const SizedBox(height: 24),
                  KeyedSubtree(
                    key: _sectionKeys[0],
                    child: SettingsSectionCard(
                      indexLabel: '01',
                      title: '外观',
                      description: '选择更适合当前环境的阅读亮度，切换会立即生效。',
                      child: Observer(
                        builder: (_) => LayoutBuilder(
                          builder: (context, constraints) {
                            final useRow = constraints.maxWidth >= 620;
                            Widget preview(bool dark) => ThemePreviewCard(
                                  label: dark ? '深色模式' : '浅色模式',
                                  description: dark ? '低亮度影院环境' : '明亮环境与日间使用',
                                  dark: dark,
                                  selected: dark
                                      ? themeStore.isDarkMode
                                      : !themeStore.isDarkMode,
                                  onTap: () {
                                    if (themeStore.isDarkMode != dark) {
                                      themeStore.toggleTheme();
                                    }
                                  },
                                );
                            if (useRow) {
                              return Row(
                                children: [
                                  Expanded(child: preview(true)),
                                  const SizedBox(width: 14),
                                  Expanded(child: preview(false)),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                SizedBox(height: 190, child: preview(true)),
                                const SizedBox(height: 12),
                                SizedBox(height: 190, child: preview(false)),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  KeyedSubtree(
                    key: _sectionKeys[1],
                    child: SettingsSectionCard(
                      indexLabel: '02',
                      title: '播放与弹幕',
                      description: '管理在线弹幕连接；播放器快捷键可在播放页面随时查看。',
                      child: SettingsActionList(
                        children: [
                          SettingsActionRow(
                            icon: Icons.subtitles_outlined,
                            title: '弹幕服务',
                            subtitle: DanmakuService().hasCredentials
                                ? '弹弹play凭证已配置'
                                : '配置弹弹play开放平台凭证',
                            statusLabel:
                                DanmakuService().hasCredentials ? '已连接' : '未配置',
                            statusTone: DanmakuService().hasCredentials
                                ? SettingsStatusTone.success
                                : SettingsStatusTone.neutral,
                            onTap: _showDanmakuSettings,
                          ),
                          SettingsActionRow(
                            icon: Icons.keyboard_outlined,
                            title: '播放器快捷键',
                            subtitle: '播放时按“/”打开快捷键面板',
                            trailingText: '共 8 项',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  KeyedSubtree(
                    key: _sectionKeys[2],
                    child: SettingsSectionCard(
                      indexLabel: '03',
                      title: '数据源',
                      description: '管理用于检索元数据、中文信息和播放线路的插件。',
                      child: Column(
                        children: [
                          PluginStatusOverview(
                            enabledCount: enabledPluginCount,
                            totalCount: pluginCount,
                          ),
                          const SizedBox(height: 12),
                          SettingsActionList(
                            children: [
                              SettingsActionRow(
                                icon: Icons.tune_rounded,
                                title: '管理数据源',
                                subtitle: '启用、停用或检查已安装插件',
                                onTap: () => Modular.to.pushNamed(
                                  '/settings/plugins',
                                ),
                              ),
                              SettingsActionRow(
                                icon: Icons.add_link_rounded,
                                title: '添加数据源',
                                subtitle: '从网络地址或本地文件导入插件',
                                onTap: () => Modular.to.pushNamed(
                                  '/settings/plugin-add',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  KeyedSubtree(
                    key: _sectionKeys[3],
                    child: SettingsSectionCard(
                      indexLabel: '04',
                      title: '存储',
                      description: '临时缓存用于加快封面与弹幕加载，可安全地定期清理。',
                      child: StorageOverview(
                        bytes: _cacheBytes,
                        loading: _scanningCache,
                        clearing: _clearingCache,
                        onRefresh: _loadCacheSize,
                        onClear: _clearCache,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  KeyedSubtree(
                    key: _sectionKeys[4],
                    child: SettingsSectionCard(
                      indexLabel: '05',
                      title: '关于',
                      description: '薇拉是一款面向 Windows 桌面的动漫聚合播放器。',
                      child: SettingsActionList(
                        children: [
                          SettingsActionRow(
                            icon: Icons.movie_filter_outlined,
                            title: '薇拉',
                            subtitle: 'Flutter Desktop · media_kit · MobX',
                            trailingText: 'v$_version',
                          ),
                          const SettingsActionRow(
                            icon: Icons.code_rounded,
                            title: '项目架构',
                            subtitle: '基于 Kazumi 架构持续演进',
                            trailingText: '开源组件',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(2)} GB';
}
