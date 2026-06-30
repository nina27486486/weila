import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../models/plugin.dart';
import '../../services/plugin/plugin_service.dart';
import '../../stores/theme_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';
import '../../utils/error_handler.dart';
import '../../widgets/vira_page_chrome.dart';
import 'widgets/plugin_workspace_components.dart';

enum _SourceFilter { all, enabled, disabled }

class PluginListPage extends StatefulWidget {
  const PluginListPage({super.key});

  @override
  State<PluginListPage> createState() => _PluginListPageState();
}

class _PluginListPageState extends State<PluginListPage> {
  final _pluginService = PluginService();
  final _searchController = TextEditingController();

  List<Plugin> _plugins = [];
  _SourceFilter _filter = _SourceFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadPlugins() {
    if (!mounted) return;
    setState(() => _plugins = _pluginService.plugins.toList());
  }

  Future<void> _openAddPage() async {
    await Modular.to.pushNamed('/settings/plugin-add');
    _loadPlugins();
  }

  Future<void> _togglePlugin(Plugin plugin) async {
    await _pluginService.togglePlugin(plugin.api);
    _loadPlugins();
  }

  Future<void> _deletePlugin(Plugin plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除数据源？'),
        content: Text(
          '删除「${plugin.name}」后，需要重新导入才能恢复。',
        ),
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
    _loadPlugins();
    if (!mounted) return;
    ErrorHandler.showSuccess(context, '已删除「${plugin.name}」');
  }

  List<Plugin> get _filteredPlugins {
    return _plugins.where((plugin) {
      final matchesFilter = switch (_filter) {
        _SourceFilter.all => true,
        _SourceFilter.enabled => plugin.enabled,
        _SourceFilter.disabled => !plugin.enabled,
      };
      final normalized = _query.toLowerCase();
      final matchesQuery = normalized.isEmpty ||
          plugin.name.toLowerCase().contains(normalized) ||
          plugin.api.toLowerCase().contains(normalized) ||
          plugin.baseUrl.toLowerCase().contains(normalized);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _plugins.where((plugin) => plugin.enabled).length;
    final cmsCount =
        _plugins.where((plugin) => plugin.api.startsWith('cms_')).length;
    final filteredPlugins = _filteredPlugins;

    return ViraPageScaffold(
      activeDestination: null,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.navigate('/settings'),
      child: Column(
        children: [
          DataSourcePageHeader(
            title: '数据源工作台',
            subtitle: '管理检索元数据与视频播放线路',
            onBack: Modular.to.pop,
            actions: [
              FilledButton.icon(
                onPressed: _openAddPage,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加数据源'),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 40),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WorkspaceOverview(
                          totalCount: _plugins.length,
                          enabledCount: enabledCount,
                          cmsCount: cmsCount,
                        ),
                        const SizedBox(height: 18),
                        _buildToolbar(context),
                        const SizedBox(height: 18),
                        if (_plugins.isEmpty)
                          SizedBox(
                            height: 420,
                            child: DataSourceEmptyState(
                              icon: Icons.hub_outlined,
                              title: '还没有数据源',
                              subtitle: '添加数据源后，薇拉才能检索番剧信息与播放线路。',
                              actionLabel: '添加数据源',
                              onAction: _openAddPage,
                            ),
                          )
                        else if (filteredPlugins.isEmpty)
                          const SizedBox(
                            height: 320,
                            child: DataSourceEmptyState(
                              icon: Icons.filter_alt_off_outlined,
                              title: '没有匹配的数据源',
                              subtitle: '尝试清空搜索词或切换状态筛选。',
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final columns =
                                  constraints.maxWidth >= 850 ? 2 : 1;
                              final cardWidth = columns == 2
                                  ? (constraints.maxWidth - 14) / 2
                                  : constraints.maxWidth;
                              return Wrap(
                                spacing: 14,
                                runSpacing: 14,
                                children: filteredPlugins.map((plugin) {
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _PluginCard(
                                      plugin: plugin,
                                      onToggle: () => _togglePlugin(plugin),
                                      onDelete: () => _deletePlugin(plugin),
                                      onTap: () async {
                                        await Modular.to.pushNamed(
                                          '/settings/plugin-detail?api=${Uri.encodeComponent(plugin.api)}',
                                        );
                                        _loadPlugins();
                                      },
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = SizedBox(
            width: constraints.maxWidth >= 700 ? 330 : constraints.maxWidth,
            height: 42,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: '搜索名称、标识或地址',
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空搜索',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 17),
                      ),
              ),
            ),
          );
          final filters = Wrap(
            spacing: 7,
            children: [
              _filterChip('全部', _SourceFilter.all),
              _filterChip('已启用', _SourceFilter.enabled),
              _filterChip('已停用', _SourceFilter.disabled),
            ],
          );
          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [search, const SizedBox(height: 10), filters],
            );
          }
          return Row(
            children: [search, const Spacer(), filters],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, _SourceFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (_) => setState(() => _filter = filter),
      mouseCursor: SystemMouseCursors.click,
    );
  }
}

class _WorkspaceOverview extends StatelessWidget {
  const _WorkspaceOverview({
    required this.totalCount,
    required this.enabledCount,
    required this.cmsCount,
  });

  final int totalCount;
  final int enabledCount;
  final int cmsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: context.colors.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '数据源状态总览',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '元数据负责作品信息，播放源负责集数与视频线路。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
          final metrics = Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              DataSourceMetric(
                icon: Icons.hub_outlined,
                label: '全部数据源',
                value: '$totalCount 个',
              ),
              DataSourceMetric(
                icon: Icons.check_circle_outline_rounded,
                label: '当前启用',
                value: '$enabledCount 个',
                color: AppTheme.scoreGreen,
              ),
              DataSourceMetric(
                icon: Icons.playlist_play_rounded,
                label: '播放源',
                value: '$cmsCount 个',
                color: AppTheme.scoreOrange,
              ),
            ],
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 16), metrics],
            );
          }
          return Row(
            children: [
              Expanded(child: intro),
              const SizedBox(width: 20),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class _PluginCard extends StatefulWidget {
  const _PluginCard({
    required this.plugin,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  final Plugin plugin;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  State<_PluginCard> createState() => _PluginCardState();
}

class _PluginCardState extends State<_PluginCard> {
  bool _hovering = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final plugin = widget.plugin;
    final highlighted = _hovering || _focused;
    final host = Uri.tryParse(plugin.baseUrl)?.host;
    return Semantics(
      button: true,
      label: '查看${plugin.name}数据源',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: highlighted
                    ? context.colors.bgHover
                    : context.colors.bgCard,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: highlighted
                      ? AppTheme.primaryBlue.withValues(alpha: 0.46)
                      : context.colors.divider,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: highlighted ? 0.16 : 0.07),
                    blurRadius: highlighted ? 15 : 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: plugin.enabled
                              ? AppTheme.primaryBlue.withValues(alpha: 0.13)
                              : context.colors.tagBg,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          dataSourceTypeIcon(plugin.api),
                          color: plugin.enabled
                              ? AppTheme.primaryBlue
                              : context.colors.textMuted,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plugin.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: plugin.enabled
                                        ? context.colors.textPrimary
                                        : context.colors.textMuted,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              host?.isNotEmpty == true ? host! : plugin.baseUrl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      DataSourceStatusBadge(enabled: plugin.enabled),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      DataSourceTypeBadge(api: plugin.api),
                      const SizedBox(width: 7),
                      Text(
                        'v${plugin.version}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const Spacer(),
                      Text(
                        plugin.api,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: context.colors.divider),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        plugin.enabled ? '参与全局检索' : '不参与全局检索',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Tooltip(
                        message: plugin.enabled ? '停用数据源' : '启用数据源',
                        child: Switch(
                          value: plugin.enabled,
                          onChanged: (_) => widget.onToggle(),
                          activeThumbColor: AppTheme.primaryBlue,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '删除数据源',
                        onPressed: widget.onDelete,
                        color: context.colors.textMuted,
                        hoverColor: AppTheme.scoreRed.withValues(alpha: 0.10),
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 19),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: highlighted
                            ? AppTheme.primaryBlue
                            : context.colors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
