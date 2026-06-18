import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../services/plugin/plugin_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/cover_image.dart';

class CategoryBrowsePage extends StatefulWidget {
  const CategoryBrowsePage({super.key});

  @override
  State<CategoryBrowsePage> createState() => _CategoryBrowsePageState();
}

class _CategoryBrowsePageState extends State<CategoryBrowsePage> {
  final PluginService _pluginService = PluginService();
  final ScrollController _scrollController = ScrollController();

  // 当前选中的数据源
  String _currentPlugin = 'cms_yinhua';

  // 筛选条件
  int? _selectedCategoryId;
  String? _selectedGenre;

  // 数据
  List<Map<String, dynamic>> _items = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // 可用分类
  List<Map<String, dynamic>> _categories = [];

  // 常见类型标签
  static const List<String> _genreOptions = [
    '热血', '冒险', '奇幻', '搞笑', '校园',
    '恋爱', '科幻', '战斗', '悬疑', '日常',
    '治愈', '运动', '偶像', '机战', '历史',
  ];

  @override
  void initState() {
    super.initState();
    _categories = PluginService.cmsCategories[_currentPlugin] ?? [];
    if (_categories.isNotEmpty) {
      _selectedCategoryId = _categories.first['id'] as int;
    }
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    if (_selectedCategoryId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _items = [];
      _currentPage = 1;
    });

    try {
      final result = await _pluginService.getCmsByCategory(
        pluginApi: _currentPlugin,
        categoryId: _selectedCategoryId!,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(result['list'] ?? []);
          _totalPages = result['pages'] as int? ?? 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败，请检查网络';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _selectedCategoryId == null) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _pluginService.getCmsByCategory(
        pluginApi: _currentPlugin,
        categoryId: _selectedCategoryId!,
        page: _currentPage + 1,
      );
      if (mounted) {
        setState(() {
          _items.addAll(List<Map<String, dynamic>>.from(result['list'] ?? []));
          _currentPage++;
          _totalPages = result['pages'] as int? ?? _totalPages;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onPluginChanged(String plugin) {
    setState(() {
      _currentPlugin = plugin;
      _categories = PluginService.cmsCategories[plugin] ?? [];
      _selectedCategoryId = _categories.isNotEmpty ? _categories.first['id'] as int : null;
      _selectedGenre = null;
    });
    _loadData();
  }

  void _onCategoryChanged(int catId) {
    setState(() {
      _selectedCategoryId = catId;
      _selectedGenre = null;
    });
    _loadData();
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedGenre == null) return _items;
    return _items.where((item) {
      final genres = item['genres'] as List<String>? ?? [];
      return genres.any((g) => g.contains(_selectedGenre!));
    }).toList();
  }

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
        title: const Text('分类浏览', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
      ),
      body: Column(
        children: [
          // 数据源切换
          _buildSourceSelector(),
          // 分类 tabs
          _buildCategoryTabs(),
          // 类型筛选 chips
          _buildGenreChips(),
          // 结果列表
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSourceChip('樱花动漫', 'cms_yinhua'),
          const SizedBox(width: 8),
          _buildSourceChip('非凡资源', 'cms_ffzy'),
        ],
      ),
    );
  }

  Widget _buildSourceChip(String label, String pluginApi) {
    final isSelected = _currentPlugin == pluginApi;
    return GestureDetector(
      onTap: () => _onPluginChanged(pluginApi),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.bgCard,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((cat) {
          final catId = cat['id'] as int;
          final isSelected = _selectedCategoryId == catId;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _onCategoryChanged(catId),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  cat['name'] as String,
                  style: TextStyle(
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGenreChips() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "全部" chip
          _buildGenreChip(null),
          ..._genreOptions.map((g) => _buildGenreChip(g)),
        ],
      ),
    );
  }

  Widget _buildGenreChip(String? genre) {
    final isSelected = _selectedGenre == genre;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _selectedGenre = genre),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.2) : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            ),
          ),
          child: Text(
            genre ?? '全部',
            style: TextStyle(
              color: isSelected ? AppTheme.primaryBlue : AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }

    final items = _filteredItems;
    if (items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: AppTheme.textMuted, size: 48),
            SizedBox(height: 12),
            Text('暂无内容', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2));
        }
        return _buildAnimeCard(items[index]);
      },
    );
  }

  Widget _buildAnimeCard(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? '';
    final cover = item['cover'] as String?;
    final score = item['score'] as double?;
    final status = item['status'] as String? ?? '';
    final url = item['url'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        if (url.isNotEmpty) {
          Modular.to.pushNamed('/detail?url=${Uri.encodeComponent(url)}&name=${Uri.encodeComponent(name)}');
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              AspectRatio(
                aspectRatio: 3 / 4,
                child: CoverImage(url: cover, fit: BoxFit.cover),
              ),
              // 信息
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (score != null && score > 0) ...[
                          Icon(Icons.star, size: 12, color: Colors.amber.shade600),
                          const SizedBox(width: 2),
                          Text(
                            score.toStringAsFixed(1),
                            style: TextStyle(color: Colors.amber.shade600, fontSize: 11),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ),
                      ],
                    ),
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
