import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../models/plugin.dart';
import '../../services/plugin/plugin_service.dart';
import '../../services/http/http_client.dart';
import '../../utils/constants.dart';

class PluginAddPage extends StatefulWidget {
  const PluginAddPage({super.key});

  @override
  State<PluginAddPage> createState() => _PluginAddPageState();
}

class _PluginAddPageState extends State<PluginAddPage> {
  int _tabIndex = 0; // 0=从URL安装, 1=手动配置
  bool _installing = false;

  // URL安装
  final _urlController = TextEditingController();

  // 手动配置
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _apiController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _searchUrlController = TextEditingController();
  final _searchListController = TextEditingController();
  final _searchNameController = TextEditingController();
  final _searchResultController = TextEditingController();
  final _chapterRoadsController = TextEditingController();
  final _chapterResultController = TextEditingController();
  final _uaController = TextEditingController(text: AppConstants.defaultUserAgent);
  final _refererController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _apiController.dispose();
    _baseUrlController.dispose();
    _searchUrlController.dispose();
    _searchListController.dispose();
    _searchNameController.dispose();
    _searchResultController.dispose();
    _chapterRoadsController.dispose();
    _chapterResultController.dispose();
    _uaController.dispose();
    _refererController.dispose();
    super.dispose();
  }

  Future<void> _installFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showMsg('请输入插件URL', isError: true);
      return;
    }

    setState(() => _installing = true);
    try {
      final http = HttpClient();
      final data = await http.getJson(url);
      
      if (data is Map<String, dynamic>) {
        final plugin = Plugin.fromJson(data);
        await PluginService().addPlugin(plugin);
        _showMsg('插件「${plugin.name}」安装成功');
        if (mounted) Modular.to.pop();
      } else if (data is List && data.isNotEmpty) {
        // 支持插件列表
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final plugin = Plugin.fromJson(item);
            await PluginService().addPlugin(plugin);
          }
        }
        _showMsg('已安装 ${data.length} 个插件');
        if (mounted) Modular.to.pop();
      }
    } catch (e) {
      _showMsg('安装失败: $e', isError: true);
    } finally {
      setState(() => _installing = false);
    }
  }

  Future<void> _saveManualPlugin() async {
    if (!_formKey.currentState!.validate()) return;

    final plugin = Plugin(
      api: _apiController.text.trim(),
      name: _nameController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      searchURL: _searchUrlController.text.trim(),
      searchList: _searchListController.text.trim(),
      searchName: _searchNameController.text.trim(),
      searchResult: _searchResultController.text.trim(),
      chapterRoads: _chapterRoadsController.text.trim(),
      chapterResult: _chapterResultController.text.trim(),
      userAgent: _uaController.text.trim(),
      referer: _refererController.text.trim().isNotEmpty ? _refererController.text.trim() : null,
      enabled: true,
    );

    await PluginService().addPlugin(plugin);
    _showMsg('插件「${plugin.name}」已添加');
    if (mounted) Modular.to.pop();
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : AppTheme.scoreGreen,
    ));
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
        title: const Text('添加插件', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: Column(
        children: [
          // 标签切换
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                _buildTab(0, Icons.link, '从URL安装'),
                const SizedBox(width: 12),
                _buildTab(1, Icons.edit, '手动配置'),
              ],
            ),
          ),
          // 内容
          Expanded(
            child: _tabIndex == 0 ? _buildUrlTab() : _buildManualTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, String label) {
    final isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryBlue.withValues(alpha: 0.15) : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppTheme.primaryBlue : AppTheme.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? AppTheme.primaryBlue : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.primaryBlue : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '输入插件JSON的URL地址',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          const Text(
            '支持单个插件JSON或插件数组',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _urlController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'https://example.com/plugin.json',
                hintStyle: TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.link, color: AppTheme.textMuted, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _installing ? null : _installFromUrl,
              icon: _installing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download, size: 18),
              label: Text(_installing ? '安装中...' : '安装'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 提示信息
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.scoreOrange),
                    SizedBox(width: 8),
                    Text('提示', style: TextStyle(color: AppTheme.scoreOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '插件JSON格式示例：\n'
                  '{\n'
                  '  "api": "my_source",\n'
                  '  "name": "我的源",\n'
                  '  "baseUrl": "https://example.com",\n'
                  '  "searchURL": "https://example.com/search/{keyword}",\n'
                  '  "searchList": ".video-item",\n'
                  '  "searchName": ".title",\n'
                  '  "searchResult": "a",\n'
                  '  "chapterRoads": ".episode-item",\n'
                  '  "chapterResult": ".source-item"\n'
                  '}',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'monospace', height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildFieldGroup('基本信息', [
            _buildField('插件名称', _nameController, '如：动漫之家', required: true),
            _buildField('API标识', _apiController, '如：dmzj（唯一标识）', required: true),
            _buildField('基础URL', _baseUrlController, '如：https://www.example.com', required: true),
          ]),
          const SizedBox(height: 20),
          _buildFieldGroup('搜索配置', [
            _buildField('搜索URL', _searchUrlController, '如：https://example.com/search/{keyword}', required: true),
            _buildField('搜索列表选择器', _searchListController, 'CSS选择器，如：.video-item', required: true),
            _buildField('名称选择器', _searchNameController, '如：.title', required: true),
            _buildField('链接选择器', _searchResultController, '如：a', required: true),
          ]),
          const SizedBox(height: 20),
          _buildFieldGroup('章节配置', [
            _buildField('章节列表选择器', _chapterRoadsController, '如：.episode-item', required: true),
            _buildField('视频源选择器', _chapterResultController, '如：.source-item', required: true),
          ]),
          const SizedBox(height: 20),
          _buildFieldGroup('高级设置', [
            _buildField('User-Agent', _uaController, '浏览器UA', required: false),
            _buildField('Referer', _refererController, '请求来源', required: false),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveManualPlugin,
              icon: const Icon(Icons.save, size: 18),
              label: const Text('保存插件'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFieldGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              if (required)
                const Text(' *', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextFormField(
              controller: controller,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: required
                  ? (v) => (v == null || v.trim().isEmpty) ? '此项必填' : null
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
