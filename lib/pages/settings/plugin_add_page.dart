import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../models/plugin.dart';
import '../../services/http/http_client.dart';
import '../../services/plugin/plugin_service.dart';
import '../../stores/theme_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';
import '../../utils/constants.dart';
import '../../utils/error_handler.dart';
import '../../widgets/vira_page_chrome.dart';
import 'widgets/plugin_workspace_components.dart';

class PluginAddPage extends StatefulWidget {
  const PluginAddPage({super.key});

  @override
  State<PluginAddPage> createState() => _PluginAddPageState();
}

class _PluginAddPageState extends State<PluginAddPage> {
  final _pluginService = PluginService();
  final _urlController = TextEditingController();
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
  final _uaController = TextEditingController(
    text: AppConstants.defaultUserAgent,
  );
  final _refererController = TextEditingController();

  int _tabIndex = 0;
  bool _submitting = false;

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

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  bool _apiExists(String api) {
    return _pluginService.plugins.any(
      (plugin) => plugin.api.toLowerCase() == api.toLowerCase(),
    );
  }

  String? _validateImportedPlugin(Plugin plugin) {
    if (plugin.name.trim().isEmpty) return '插件名称为空';
    if (plugin.api.trim().isEmpty) return 'API 标识为空';
    if (!_isHttpUrl(plugin.baseUrl)) return '基础地址无效';
    return null;
  }

  Future<void> _installFromUrl() async {
    final url = _urlController.text.trim();
    if (!_isHttpUrl(url)) {
      _showMessage('请输入有效的 HTTP 或 HTTPS 地址', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final data = await HttpClient().getJson(url);
      final imported = <Plugin>[];
      if (data is Map<String, dynamic>) {
        imported.add(Plugin.fromJson(data));
      } else if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            imported.add(Plugin.fromJson(item));
          }
        }
      }

      if (imported.isEmpty) {
        _showMessage('地址中没有可识别的数据源配置', isError: true);
        return;
      }

      var added = 0;
      var skipped = 0;
      for (final plugin in imported) {
        final validationError = _validateImportedPlugin(plugin);
        if (validationError != null || _apiExists(plugin.api)) {
          skipped++;
          continue;
        }
        await _pluginService.addPlugin(plugin);
        added++;
      }

      if (added == 0) {
        _showMessage(
          skipped > 0 ? '数据源已存在或配置不完整' : '没有新增数据源',
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      Modular.to.pop();
    } catch (error) {
      _showMessage('导入失败，请检查地址和配置格式', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveManualPlugin() async {
    if (!_formKey.currentState!.validate()) return;
    final api = _apiController.text.trim();
    if (_apiExists(api)) {
      _showMessage('API 标识“$api”已存在', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final plugin = Plugin(
        api: api,
        name: _nameController.text.trim(),
        baseUrl: _baseUrlController.text.trim(),
        searchURL: _searchUrlController.text.trim(),
        searchList: _searchListController.text.trim(),
        searchName: _searchNameController.text.trim(),
        searchResult: _searchResultController.text.trim(),
        chapterRoads: _chapterRoadsController.text.trim(),
        chapterResult: _chapterResultController.text.trim(),
        userAgent: _uaController.text.trim(),
        referer: _refererController.text.trim().isEmpty
            ? null
            : _refererController.text.trim(),
        enabled: true,
      );
      await _pluginService.addPlugin(plugin);
      if (mounted) Modular.to.pop();
    } catch (_) {
      _showMessage('保存失败，请稍后重试', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      ErrorHandler.showError(context, message);
    } else {
      ErrorHandler.showSuccess(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: null,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.navigate('/settings'),
      child: Column(
        children: [
          DataSourcePageHeader(
            title: '添加数据源',
            subtitle: '从配置地址导入，或手动建立解析规则',
            onBack: Modular.to.pop,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MethodSelector(
                          selectedIndex: _tabIndex,
                          onSelected: (index) {
                            if (_submitting) return;
                            setState(() => _tabIndex = index);
                          },
                        ),
                        const SizedBox(height: 18),
                        AnimatedSwitcher(
                          duration: AppAnimations.normal,
                          switchInCurve: AppAnimations.easeOut,
                          switchOutCurve: AppAnimations.easeIn,
                          child: _tabIndex == 0
                              ? _buildUrlImport()
                              : _buildManualForm(),
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

  Widget _buildUrlImport() {
    return DataSourceSection(
      key: const ValueKey('url-import'),
      icon: Icons.add_link_rounded,
      title: '通过配置地址导入',
      description: '支持单个 JSON 对象或由多个对象组成的 JSON 数组。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            enabled: !_submitting,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_submitting) _installFromUrl();
            },
            decoration: const InputDecoration(
              labelText: '配置地址',
              hintText: 'https://example.com/plugin.json',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppTheme.scoreOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.scoreOrange.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.scoreOrange,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '只导入你信任的配置地址。数据源可以向其声明的网站发起网络请求。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _installFromUrl,
              icon: _submitting
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(_submitting ? '正在导入' : '验证并导入'),
            ),
          ),
          const SizedBox(height: 18),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            title: Text(
              '查看配置格式说明',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.divider),
                ),
                child: SelectableText(
                  '{\n'
                  '  "api": "my_source",\n'
                  '  "name": "我的数据源",\n'
                  '  "baseUrl": "https://example.com",\n'
                  '  "searchURL": "https://example.com/search/{keyword}"\n'
                  '}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'Consolas',
                        height: 1.55,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualForm() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('manual-form'),
        children: [
          _fieldSection(
            icon: Icons.badge_outlined,
            title: '基本信息',
            description: '定义数据源名称、唯一标识和站点根地址。',
            fields: [
              _FieldSpec('数据源名称', _nameController, '例如：动画资料库'),
              _FieldSpec(
                'API 标识',
                _apiController,
                '例如：my_source',
                validator: (value) {
                  final input = value?.trim() ?? '';
                  if (input.isEmpty) return '此项必填';
                  if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(input)) {
                    return '仅支持字母、数字、下划线和连字符';
                  }
                  return null;
                },
              ),
              _FieldSpec(
                '基础地址',
                _baseUrlController,
                'https://www.example.com',
                validator: _urlValidator,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _fieldSection(
            icon: Icons.search_rounded,
            title: '搜索配置',
            description: '定义搜索入口以及结果列表中的字段选择器。',
            fields: [
              _FieldSpec(
                '搜索地址',
                _searchUrlController,
                'https://example.com/search/{keyword}',
                validator: _urlValidator,
                fullWidth: true,
              ),
              _FieldSpec('列表选择器', _searchListController, '.video-item'),
              _FieldSpec('名称选择器', _searchNameController, '.title'),
              _FieldSpec('链接选择器', _searchResultController, 'a'),
            ],
          ),
          const SizedBox(height: 16),
          _fieldSection(
            icon: Icons.format_list_numbered_rounded,
            title: '章节配置',
            description: '定义选集列表与播放线路的解析位置。',
            fields: [
              _FieldSpec('章节列表选择器', _chapterRoadsController, '.episode-item'),
              _FieldSpec('视频源选择器', _chapterResultController, '.source-item'),
            ],
          ),
          const SizedBox(height: 16),
          _fieldSection(
            icon: Icons.network_check_rounded,
            title: '高级网络设置',
            description: '仅在目标站点需要指定请求头时修改。',
            fields: [
              _FieldSpec(
                'User-Agent',
                _uaController,
                '浏览器请求标识',
                required: false,
                fullWidth: true,
                maxLines: 2,
              ),
              _FieldSpec(
                'Referer',
                _refererController,
                'https://www.example.com/',
                required: false,
                fullWidth: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _saveManualPlugin,
              icon: _submitting
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_submitting ? '正在保存' : '保存数据源'),
            ),
          ),
        ],
      ),
    );
  }

  String? _urlValidator(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return '此项必填';
    if (!_isHttpUrl(input.replaceAll('{keyword}', 'test'))) {
      return '请输入有效的 HTTP 或 HTTPS 地址';
    }
    return null;
  }

  Widget _fieldSection({
    required IconData icon,
    required String title,
    required String description,
    required List<_FieldSpec> fields,
  }) {
    return DataSourceSection(
      icon: icon,
      title: title,
      description: description,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 650;
          final halfWidth = (constraints.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: fields.map((field) {
              final width = field.fullWidth || !twoColumns
                  ? constraints.maxWidth
                  : halfWidth;
              return SizedBox(
                width: width,
                child: TextFormField(
                  controller: field.controller,
                  enabled: !_submitting,
                  maxLines: field.maxLines,
                  decoration: InputDecoration(
                    labelText:
                        field.required ? '${field.label} *' : field.label,
                    hintText: field.hint,
                  ),
                  validator: field.validator ??
                      (field.required
                          ? (value) => value == null || value.trim().isEmpty
                              ? '此项必填'
                              : null
                          : null),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _FieldSpec {
  const _FieldSpec(
    this.label,
    this.controller,
    this.hint, {
    this.required = true,
    this.fullWidth = false,
    this.maxLines = 1,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool required;
  final bool fullWidth;
  final int maxLines;
  final FormFieldValidator<String>? validator;
}

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _MethodTab(
              icon: Icons.add_link_rounded,
              title: '配置地址导入',
              subtitle: '适合已有 JSON 配置',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _MethodTab(
              icon: Icons.tune_rounded,
              title: '手动建立规则',
              subtitle: '逐项填写解析选择器',
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTab extends StatefulWidget {
  const _MethodTab({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MethodTab> createState() => _MethodTabState();
}

class _MethodTabState extends State<_MethodTab> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.13)
                : (_hovering ? context.colors.bgHover : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.38)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.selected
                    ? AppTheme.primaryBlue
                    : context.colors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
