import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../services/plugin/plugin_service.dart';
import '../../widgets/anime_card.dart';

/// 番剧/剧场版列表页
/// 接收参数: title, categoryIds, sourcePlugin
class AnimeListPage extends StatefulWidget {
  final String title;
  final Map<String, int> categoryIds;
  final String sourcePlugin;

  const AnimeListPage({
    super.key,
    required this.title,
    required this.categoryIds,
    this.sourcePlugin = 'cms_yinhua',
  });

  @override
  State<AnimeListPage> createState() => _AnimeListPageState();
}

class _AnimeListPageState extends State<AnimeListPage> {
  final PluginService _pluginService = PluginService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _selectedCategory;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    // 默认选中第一个分类
    if (widget.categoryIds.isNotEmpty) {
      _selectedCategory = widget.categoryIds.keys.first;
      _selectedCategoryId = widget.categoryIds.values.first;
    }
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    if (_selectedCategoryId == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
    });
    try {
      final result = await _pluginService.getCmsByCategory(
        pluginApi: _selectedCategory ?? widget.sourcePlugin,
        categoryId: _selectedCategoryId!,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(result['list'] ?? []);
        _totalPages = result['pages'] as int? ?? 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_selectedCategoryId == null) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final result = await _pluginService.getCmsByCategory(
        pluginApi: _selectedCategory ?? widget.sourcePlugin,
        categoryId: _selectedCategoryId!,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(List<Map<String, dynamic>>.from(result['list'] ?? []));
        _currentPage = nextPage;
        _totalPages = result['pages'] as int? ?? _totalPages;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onCategoryTap(String key, int id) {
    if (_selectedCategory == key) return;
    setState(() {
      _selectedCategory = key;
      _selectedCategoryId = id;
    });
    _loadData();
  }

  void _navigateToDetail(Map<String, dynamic> item) {
    final url = item['url']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    Modular.to.pushNamed('/detail?url=${Uri.encodeComponent(url)}&name=${Uri.encodeComponent(name)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Modular.to.navigate('/'),
        ),
      ),
      body: Column(
        children: [
          // 分类标签栏
          if (widget.categoryIds.length > 1) _buildCategoryTabs(),
          // 列表内容
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.categoryIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = widget.categoryIds.keys.elementAt(index);
          final id = widget.categoryIds[key]!;
          final selected = _selectedCategory == key;
          return GestureDetector(
            onTap: () => _onCategoryTap(key, id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryBlue : AppTheme.bgCard,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                key,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }
    if (_error != null) {
      return _buildErrorState();
    }
    if (_items.isEmpty) {
      return _buildEmptyState();
    }
    return _buildGrid();
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textMuted),
          SizedBox(height: 12),
          Text('暂无内容', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式列数
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 6;
        } else if (constraints.maxWidth > 900) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 400) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.55,
          ),
          itemCount: _items.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryBlue,
                    strokeWidth: 2,
                  ),
                ),
              );
            }
            final item = _items[index];
            return _buildItem(item);
          },
        );
      },
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? '';
    final cover = item['cover']?.toString();
    final score = item['score'] as double?;
    final status = item['status']?.toString() ?? '';
    final genres = (item['genres'] as List?)?.cast<String>() ?? [];

    return AnimeCard(
      title: name,
      coverUrl: cover,
      score: score,
      tags: genres,
      badge: status.isNotEmpty ? status : null,
      badgeColor: _getStatusColor(status),
      onTap: () => _navigateToDetail(item),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('完结')) return AppTheme.scoreGreen;
    if (status.contains('更新')) return AppTheme.airing;
    return AppTheme.tagHighlight;
  }
}
