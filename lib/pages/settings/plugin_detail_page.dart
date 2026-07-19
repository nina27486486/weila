import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../models/plugin.dart';
import '../../services/http/http_client.dart';
import '../../services/plugin/plugin_service.dart';
import '../../stores/theme_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/vira_colors.dart';
import '../../utils/error_handler.dart';
import '../../widgets/vira_page_chrome.dart';
import 'widgets/plugin_workspace_components.dart';

class PluginDetailPage extends StatefulWidget {
  const PluginDetailPage({super.key, required this.pluginApi});

  final String pluginApi;

  @override
  State<PluginDetailPage> createState() => _PluginDetailPageState();
}

class _PluginDetailPageState extends State<PluginDetailPage> {
  final _pluginService = PluginService();
  Plugin? _plugin;
  bool _testing = false;
  _ConnectionResult? _connectionResult;

  @override
  void initState() {
    super.initState();
    _plugin = _findPlugin();
  }

  Plugin? _findPlugin() {
    try {
      return _pluginService.plugins.firstWhere(
        (plugin) => plugin.api == widget.pluginApi,
      );
    } catch (_) {
      return null;
    }
  }

  void _reloadPlugin() {
    if (!mounted) return;
    setState(() => _plugin = _findPlugin());
  }

  Future<void> _togglePlugin() async {
    final plugin = _plugin;
    if (plugin == null) return;
    await _pluginService.togglePlugin(plugin.api);
    _reloadPlugin();
  }

  Future<void> _testConnection() async {
    final plugin = _plugin;
    if (plugin == null || _testing) return;
    final uri = Uri.tryParse(plugin.baseUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      setState(() {
        _connectionResult = const _ConnectionResult(
          success: false,
          message: '基础地址格式无效',
          latencyMs: 0,
        );
      });
      return;
    }

    setState(() {
      _testing = true;
      _connectionResult = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final headers = <String, String>{
        if (plugin.userAgent.isNotEmpty) 'User-Agent': plugin.userAgent,
        if (plugin.referer?.isNotEmpty == true) 'Referer': plugin.referer!,
      };
      final response = await HttpClient().dio.get<Object?>(
            plugin.baseUrl,
            options: Options(
              responseType: ResponseType.plain,
              headers: headers,
              validateStatus: (status) => status != null && status < 500,
            ),
          );
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _connectionResult = _ConnectionResult(
          success: true,
          message: response.statusCode == null
              ? '基础地址可达'
              : '基础地址可达（HTTP ${response.statusCode}）',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      });
    } catch (_) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _connectionResult = _ConnectionResult(
          success: false,
          message: '无法连接基础地址，请检查网络或请求头',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _deletePlugin() async {
    final plugin = _plugin;
    if (plugin == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除数据源？'),
        content: Text('「${plugin.name}」的配置将从本机移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.scoreRed),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _pluginService.removePlugin(plugin.api);
    if (mounted) Modular.to.pop();
  }

  void _copyValue(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ErrorHandler.showSuccess(
      context,
      '已复制$label',
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plugin = _plugin;
    return ViraPageScaffold(
      activeDestination: null,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.navigate('/settings'),
      child: Column(
        children: [
          DataSourcePageHeader(
            title: plugin?.name ?? '数据源详情',
            subtitle: plugin == null
                ? '当前配置不存在或已被移除'
                : '${dataSourceTypeLabel(plugin.api)} · ${plugin.api}',
            onBack: Modular.to.pop,
          ),
          Expanded(
            child: plugin == null
                ? const DataSourceEmptyState(
                    icon: Icons.extension_off_outlined,
                    title: '找不到这个数据源',
                    subtitle: '它可能已经被删除，请返回工作台重新选择。',
                  )
                : _buildDetails(plugin),
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

  Widget _buildDetails(Plugin plugin) {
    final host = Uri.tryParse(plugin.baseUrl)?.host;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DetailOverview(
                  plugin: plugin,
                  testing: _testing,
                  connectionResult: _connectionResult,
                  onToggle: _togglePlugin,
                  onTest: _testConnection,
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 780;
                    final width = twoColumns
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: _configSection(
                            title: '基本信息',
                            description: '身份标识与站点入口',
                            icon: Icons.badge_outlined,
                            rows: [
                              _ConfigValue('API 标识', plugin.api),
                              _ConfigValue('版本', plugin.version),
                              _ConfigValue(
                                  '类型', dataSourceTypeLabel(plugin.api)),
                              _ConfigValue(
                                '域名',
                                host?.isNotEmpty == true ? host! : '无法识别',
                              ),
                              _ConfigValue('基础地址', plugin.baseUrl,
                                  copyable: true),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _configSection(
                            title: '网络请求',
                            description: '请求身份与来源头',
                            icon: Icons.network_check_rounded,
                            rows: [
                              _ConfigValue(
                                'User-Agent',
                                plugin.userAgent.isEmpty
                                    ? '使用默认值'
                                    : plugin.userAgent,
                                copyable: plugin.userAgent.isNotEmpty,
                              ),
                              _ConfigValue(
                                'Referer',
                                plugin.referer?.isNotEmpty == true
                                    ? plugin.referer!
                                    : '未设置',
                                copyable: plugin.referer?.isNotEmpty == true,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _configSection(
                            title: '搜索解析',
                            description: '关键词请求与结果字段',
                            icon: Icons.search_rounded,
                            rows: [
                              _ConfigValue('搜索地址', plugin.searchURL,
                                  copyable: true),
                              _ConfigValue('列表选择器', plugin.searchList,
                                  copyable: true),
                              _ConfigValue('名称选择器', plugin.searchName,
                                  copyable: true),
                              _ConfigValue('链接选择器', plugin.searchResult,
                                  copyable: true),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _configSection(
                            title: '章节解析',
                            description: '选集与播放线路字段',
                            icon: Icons.format_list_numbered_rounded,
                            rows: [
                              _ConfigValue(
                                '章节列表选择器',
                                plugin.chapterRoads,
                                copyable: true,
                              ),
                              _ConfigValue(
                                '视频源选择器',
                                plugin.chapterResult,
                                copyable: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                _DangerZone(plugin: plugin, onDelete: _deletePlugin),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _configSection({
    required String title,
    required String description,
    required IconData icon,
    required List<_ConfigValue> rows,
  }) {
    return DataSourceSection(
      title: title,
      description: description,
      icon: icon,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.bgSurface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: context.colors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              _ConfigRow(
                value: rows[index],
                onCopy: rows[index].copyable
                    ? () => _copyValue(rows[index].label, rows[index].value)
                    : null,
              ),
              if (index != rows.length - 1)
                Divider(height: 1, color: context.colors.divider),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailOverview extends StatelessWidget {
  const _DetailOverview({
    required this.plugin,
    required this.testing,
    required this.connectionResult,
    required this.onToggle,
    required this.onTest,
  });

  final Plugin plugin;
  final bool testing;
  final _ConnectionResult? connectionResult;
  final VoidCallback onToggle;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: plugin.enabled
                      ? AppTheme.primaryBlue.withValues(alpha: 0.13)
                      : context.colors.tagBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  dataSourceTypeIcon(plugin.api),
                  color: plugin.enabled
                      ? AppTheme.primaryBlue
                      : context.colors.textMuted,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plugin.name,
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        DataSourceStatusBadge(
                          enabled: plugin.enabled,
                          enabledLabel: '参与检索',
                          disabledLabel: '已停止',
                        ),
                        DataSourceTypeBadge(api: plugin.api),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plugin.enabled ? '已启用' : '已停用',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Switch(
                    value: plugin.enabled,
                    onChanged: (_) => onToggle(),
                    activeThumbColor: AppTheme.primaryBlue,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 17),
          Divider(height: 1, color: context.colors.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: connectionResult == null
                    ? Text(
                        '连接测试仅访问当前数据源的基础地址。',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : _ConnectionResultView(result: connectionResult!),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: testing ? null : onTest,
                icon: testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 17),
                label: Text(testing ? '正在连接' : '测试连接'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfigValue {
  const _ConfigValue(this.label, this.value, {this.copyable = false});

  final String label;
  final String value;
  final bool copyable;
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.value, this.onCopy});

  final _ConfigValue value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(value.label,
                style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: SelectableText(
              value.value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textPrimary,
                    fontFamily: 'Consolas',
                  ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              tooltip: '复制${value.label}',
              onPressed: onCopy,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.copy_rounded, size: 15),
            ),
        ],
      ),
    );
  }
}

class _ConnectionResult {
  const _ConnectionResult({
    required this.success,
    required this.message,
    required this.latencyMs,
  });

  final bool success;
  final String message;
  final int latencyMs;
}

class _ConnectionResultView extends StatelessWidget {
  const _ConnectionResultView({required this.result});

  final _ConnectionResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.success ? AppTheme.scoreGreen : AppTheme.scoreRed;
    return Row(
      children: [
        Icon(
          result.success
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            result.message,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
        if (result.latencyMs > 0)
          Text(
            '${result.latencyMs} ms',
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.plugin, required this.onDelete});

  final Plugin plugin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.scoreRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.scoreRed.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.delete_forever_outlined,
              color: AppTheme.scoreRed, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('删除数据源', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '删除「${plugin.name}」后无法撤销，需要重新导入配置。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.scoreRed,
              side:
                  BorderSide(color: AppTheme.scoreRed.withValues(alpha: 0.45)),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
            label: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
