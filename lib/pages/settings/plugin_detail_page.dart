import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../models/plugin.dart';
import '../../services/plugin/plugin_service.dart';

class PluginDetailPage extends StatefulWidget {
  final String pluginApi;

  const PluginDetailPage({super.key, required this.pluginApi});

  @override
  State<PluginDetailPage> createState() => _PluginDetailPageState();
}

class _PluginDetailPageState extends State<PluginDetailPage> {
  final _pluginService = PluginService();
  Plugin? _plugin;

  @override
  void initState() {
    super.initState();
    _loadPlugin();
  }

  void _loadPlugin() {
    try {
      _plugin = _pluginService.plugins.firstWhere((p) => p.api == widget.pluginApi);
    } catch (_) {
      _plugin = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_plugin == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgDark,
        appBar: AppBar(
          backgroundColor: AppTheme.bgDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Modular.to.pop(),
          ),
          title: const Text('插件详情', style: TextStyle(color: AppTheme.textPrimary)),
        ),
        body: const Center(
          child: Text('插件未找到', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final plugin = _plugin!;
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.pop(),
        ),
        title: Text(plugin.name, style: const TextStyle(color: AppTheme.textPrimary)),
        actions: [
          // 启用/禁用
          Switch(
            value: plugin.enabled,
            onChanged: (_) async {
              await _pluginService.togglePlugin(plugin.api);
              _loadPlugin();
            },
            activeColor: AppTheme.primaryBlue,
            inactiveTrackColor: AppTheme.bgSurface,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 头部信息
          _buildHeader(plugin),
          const SizedBox(height: 24),
          
          // 基本信息
          _buildSection('基本信息', [
            _buildInfoRow('API标识', plugin.api),
            _buildInfoRow('版本', plugin.version),
            _buildInfoRow('基础URL', plugin.baseUrl),
            _buildInfoRow('状态', plugin.enabled ? '已启用' : '已禁用'),
          ]),
          
          // 搜索配置
          _buildSection('搜索配置', [
            _buildInfoRow('搜索URL', plugin.searchURL),
            _buildInfoRow('列表选择器', plugin.searchList),
            _buildInfoRow('名称选择器', plugin.searchName),
            _buildInfoRow('链接选择器', plugin.searchResult),
          ]),
          
          // 章节配置
          _buildSection('章节配置', [
            _buildInfoRow('章节列表选择器', plugin.chapterRoads),
            _buildInfoRow('视频源选择器', plugin.chapterResult),
          ]),
          
          // 网络配置
          _buildSection('网络配置', [
            _buildInfoRow('User-Agent', plugin.userAgent.isNotEmpty ? plugin.userAgent : '默认'),
            _buildInfoRow('Referer', plugin.referer ?? '未设置'),
          ]),
          
          const SizedBox(height: 24),
          
          // 测试按钮
          _buildTestButton(plugin),
          
          const SizedBox(height: 16),
          
          // 删除按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _deletePlugin(plugin),
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              label: const Text('删除插件', style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Plugin plugin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: plugin.enabled
                  ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                  : AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.extension,
              color: plugin.enabled ? AppTheme.primaryBlue : AppTheme.textMuted,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plugin.name,
                  style: TextStyle(
                    color: plugin.enabled ? AppTheme.textPrimary : AppTheme.textMuted,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v${plugin.version} · ${plugin.api}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: plugin.enabled
                  ? AppTheme.scoreGreen.withValues(alpha: 0.15)
                  : AppTheme.tagBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              plugin.enabled ? '运行中' : '已停止',
              style: TextStyle(
                color: plugin.enabled ? AppTheme.scoreGreen : AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: children),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(Plugin plugin) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('正在测试插件连接...'),
              backgroundColor: AppTheme.bgCard,
              duration: Duration(seconds: 2),
            ),
          );
          try {
            final results = await _pluginService.searchAll('测试');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(results.isEmpty ? '插件连接成功，但未返回结果' : '测试成功，找到 ${results.length} 个结果'),
                backgroundColor: results.isEmpty ? AppTheme.scoreOrange : AppTheme.scoreGreen,
              ));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('测试失败: $e'),
                backgroundColor: Colors.redAccent,
              ));
            }
          }
        },
        icon: const Icon(Icons.play_circle_outline, size: 18, color: AppTheme.primaryBlue),
        label: const Text('测试插件', style: TextStyle(color: AppTheme.primaryBlue)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.primaryBlue),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Future<void> _deletePlugin(Plugin plugin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        title: const Text('删除插件', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('确定要删除「${plugin.name}」吗？', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _pluginService.removePlugin(plugin.api);
      if (mounted) Modular.to.pop();
    }
  }
}
