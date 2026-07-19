import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../services/plugin/plugin_service.dart';
import '../../stores/theme_store.dart';
import '../../widgets/vira_page_chrome.dart';
import 'anime_catalog_view.dart';

class CategoryBrowsePage extends StatefulWidget {
  const CategoryBrowsePage({super.key});

  @override
  State<CategoryBrowsePage> createState() => _CategoryBrowsePageState();
}

class _CategoryBrowsePageState extends State<CategoryBrowsePage> {
  static const _sources = [
    CatalogFilterOption(id: 'cms_yinhua', label: '樱花动漫'),
    CatalogFilterOption(id: 'cms_ffzy', label: '非凡资源'),
  ];
  static const _genres = [
    '热血',
    '冒险',
    '奇幻',
    '搞笑',
    '校园',
    '恋爱',
    '科幻',
    '战斗',
    '悬疑',
    '日常',
    '治愈',
    '运动',
    '偶像',
    '机战',
    '历史',
  ];

  final _pluginService = PluginService();
  final _scrollController = ScrollController();

  String _currentPlugin = 'cms_yinhua';
  int? _selectedCategoryId;
  String _selectedGenre = '全部';
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _categories = [];
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncCategories();
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _syncCategories() {
    _categories = PluginService.cmsCategories[_currentPlugin] ?? [];
    _selectedCategoryId =
        _categories.isEmpty ? null : _categories.first['id'] as int;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 240 &&
        !_isLoadingMore &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _items = [];
      _currentPage = 1;
    });

    try {
      final result = await _pluginService.getCmsByCategory(
        pluginApi: _currentPlugin,
        categoryId: categoryId,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(result['list'] ?? []);
        _totalPages = result['pages'] as int? ?? 1;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载失败，请检查网络后再试。';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final categoryId = _selectedCategoryId;
    if (_isLoadingMore || categoryId == null) return;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _pluginService.getCmsByCategory(
        pluginApi: _currentPlugin,
        categoryId: categoryId,
        page: _currentPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(List<Map<String, dynamic>>.from(result['list'] ?? []));
        _currentPage++;
        _totalPages = result['pages'] as int? ?? _totalPages;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _changeSource(String plugin) {
    if (_currentPlugin == plugin) return;
    setState(() {
      _currentPlugin = plugin;
      _selectedGenre = '全部';
      _syncCategories();
    });
    _loadData();
  }

  void _changeCategory(String categoryId) {
    final parsed = int.tryParse(categoryId);
    if (parsed == null || parsed == _selectedCategoryId) return;
    setState(() {
      _selectedCategoryId = parsed;
      _selectedGenre = '全部';
    });
    _loadData();
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedGenre == '全部') return _items;
    return _items.where((item) {
      final rawGenres = item['genres'];
      if (rawGenres is! List) return false;
      return rawGenres
          .any((genre) => genre.toString().contains(_selectedGenre));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions = _categories
        .map(
          (category) => CatalogFilterOption(
            id: (category['id'] as int).toString(),
            label: category['name']?.toString() ?? '未命名栏目',
          ),
        )
        .toList(growable: false);
    final genreOptions = [
      const CatalogFilterOption(id: '全部', label: '全部'),
      for (final genre in _genres) CatalogFilterOption(id: genre, label: genre),
    ];

    return ViraPageScaffold(
      activeDestination: ViraDestination.discover,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: AnimeCatalogView(
        title: '分类浏览',
        description: '从类型、片源和放送栏目里，寻找下一段真正想看的故事。',
        sourceOptions: _sources,
        selectedSourceId: _currentPlugin,
        onSourceSelected: _changeSource,
        categoryOptions: categoryOptions,
        selectedCategoryId: _selectedCategoryId?.toString(),
        onCategorySelected: _changeCategory,
        genreOptions: genreOptions,
        selectedGenreId: _selectedGenre,
        onGenreSelected: (value) => setState(() => _selectedGenre = value),
        items: _filteredItems,
        isLoading: _isLoading,
        isLoadingMore: _isLoadingMore,
        errorMessage: _error,
        onOpenAnime: _openDetail,
        onRetry: _loadData,
        scrollController: _scrollController,
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
    if (destination != ViraDestination.discover) {
      Modular.to.navigate(route);
    }
  }

  void _openDetail(Map<String, dynamic> item) {
    final url = item['url']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    if (url.isEmpty) return;
    Modular.to.pushNamed(
      '/detail?url=${Uri.encodeComponent(url)}'
      '&name=${Uri.encodeComponent(name)}',
    );
  }
}
