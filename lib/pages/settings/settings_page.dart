import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../services/danmaku/danmaku_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.navigate('/'),
        ),
        title: const Text('设置', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: ListView(
        children: [
          _buildSection('插件管理', [
            _buildTile(
              icon: Icons.extension,
              title: '已安装插件',
              subtitle: '管理数据源插件',
              onTap: () => Modular.to.pushNamed('/settings/plugins'),
            ),
            _buildTile(
              icon: Icons.add_circle_outline,
              title: '添加插件',
              subtitle: '从URL或文件安装插件',
              onTap: () => Modular.to.pushNamed('/settings/plugin-add'),
            ),
          ]),
          _buildSection('播放设置', [
            _buildTile(
              icon: Icons.speed,
              title: '默认画质',
              subtitle: '自动',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.subtitles,
              title: '弹幕设置',
              subtitle: '弹弹play API Key 配置',
              onTap: () => _showDanmakuSettings(context),
            ),
          ]),
          _buildSection('外观', [
            _buildTile(
              icon: Icons.palette_outlined,
              title: '主题',
              subtitle: '深色模式',
              onTap: () {},
            ),
          ]),
          _buildSection('存储', [
            _buildTile(
              icon: Icons.cleaning_services_outlined,
              title: '清除缓存',
              subtitle: '清除图片和数据缓存',
              onTap: () {},
            ),
          ]),
          _buildSection('关于', [
            _buildTile(
              icon: Icons.info_outline,
              title: '关于薇拉',
              subtitle: 'v0.1.0 · 基于 Kazumi 架构',
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.textSecondary, size: 22),
      title: Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        ...children,
        const Divider(color: AppTheme.divider, height: 1),
      ],
    );
  }

  void _showDanmakuSettings(BuildContext context) {
    final appIdController = TextEditingController();
    final appSecretController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('弹幕设置', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '需要弹弹play开放平台的 API Key\n注册地址：dandanplay.com/dev',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: appIdController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'App Id',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                hintText: '输入 App Id',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryBlue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: appSecretController,
              style: const TextStyle(color: AppTheme.textPrimary),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'App Secret',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                hintText: '输入 App Secret',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primaryBlue),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final appId = appIdController.text.trim();
              final appSecret = appSecretController.text.trim();
              if (appId.isNotEmpty && appSecret.isNotEmpty) {
                DanmakuService().setCredentials(appId, appSecret);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('弹幕 API Key 已保存'), backgroundColor: AppTheme.primaryBlue),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
