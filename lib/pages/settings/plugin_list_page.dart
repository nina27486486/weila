import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../models/plugin.dart';
import '../../services/plugin/plugin_service.dart';

class PluginListPage extends StatefulWidget {
  const PluginListPage({super.key});

  @override
  State<PluginListPage> createState() => _PluginListPageState();
}

class _PluginListPageState extends State<PluginListPage> {
  final _pluginService = PluginService();
  List<Plugin> _plugins = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlugins();
  }

  void _loadPlugins() {
    setState(() {
      _plugins = _pluginService.plugins.toList();
      _loading = false;
    });
  }

  Future<void> _togglePlugin(Plugin plugin) async {
    await _pluginService.togglePlugin(plugin.api);
    _loadPlugins();
  }

  Future<void> _deletePlugin(Plugin plugin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('删除插件', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '确定要删除「${plugin.name}」吗？',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _pluginService.removePlugin(plugin.api);
      _loadPlugins();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除「${plugin.name}」'), backgroundColor: AppTheme.bgCard),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.pop(),
        ),
        title: const Text('插件管理', style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryBlue),
            tooltip: '添加插件',
            onPressed: () async {
              await Modular.to.pushNamed('/settings/plugin-add');
              _loadPlugins();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : _plugins.isEmpty
              ? _buildEmpty()
              : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.extension_off, size: 40, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),
          const Text(
            '还没有插件',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            '添加数据源插件后才能搜索和播放动漫',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await Modular.to.pushNamed('/settings/plugin-add');
              _loadPlugins();
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('添加插件'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _plugins.length,
      itemBuilder: (context, index) {
        final plugin = _plugins[index];
        return _PluginCard(
          plugin: plugin,
          onToggle: () => _togglePlugin(plugin),
          onDelete: () => _deletePlugin(plugin),
          onTap: () async {
            await Modular.to.pushNamed('/settings/plugin-detail?api=${plugin.api}');
            _loadPlugins();
          },
        );
      },
    );
  }
}

/// 插件卡片（带悬停动画）
class _PluginCard extends StatefulWidget {
  final Plugin plugin;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PluginCard({
    required this.plugin,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<_PluginCard> createState() => _PluginCardState();
}

class _PluginCardState extends State<_PluginCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final plugin = widget.plugin;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovering ? AppTheme.bgHover : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovering
                  ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                  : plugin.enabled
                      ? AppTheme.divider
                      : AppTheme.divider.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              // 插件图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: plugin.enabled
                      ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.extension,
                  color: plugin.enabled ? AppTheme.primaryBlue : AppTheme.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plugin.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: plugin.enabled ? AppTheme.textPrimary : AppTheme.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: plugin.enabled
                                ? AppTheme.scoreGreen.withValues(alpha: 0.15)
                                : AppTheme.tagBg,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            plugin.enabled ? '已启用' : '已禁用',
                            style: TextStyle(
                              color: plugin.enabled ? AppTheme.scoreGreen : AppTheme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plugin.baseUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v${plugin.version} · ${plugin.api}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 操作按钮
              Column(
                children: [
                  // 启用/禁用开关
                  SizedBox(
                    height: 28,
                    child: Switch(
                      value: plugin.enabled,
                      onChanged: (_) => widget.onToggle(),
                      activeColor: AppTheme.primaryBlue,
                      inactiveTrackColor: AppTheme.bgSurface,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 删除按钮
                  SizedBox(
                    height: 28,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppTheme.textMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: widget.onDelete,
                      tooltip: '删除',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
