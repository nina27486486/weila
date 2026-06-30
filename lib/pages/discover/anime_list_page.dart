import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../services/plugin/plugin_service.dart';
import '../../stores/theme_store.dart';
import '../../widgets/vira_page_chrome.dart';
import 'anime_catalog_view.dart';

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
  final _pluginService = PluginService();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _selectedSource;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.categoryIds.isNotEmpty) {
      _selectedSource = widget.categoryIds.keys.first;
      _selectedCategoryId = widget.categoryIds.values.first;
    }
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 240 &&
        !_loadingMore &&
        _currentPage < _totalPages) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final result = await _pluginService.getCmsByCategory(
        pluginApi: _selectedSource ?? widget.sourcePlugin,
        categoryId: categoryId,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(result['list'] ?? []);
        _totalPages = result['pages'] as int? ?? 1;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '片单加载失败，请检查网络后再试。';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final categoryId = _selectedCategoryId;
    if (_loadingMore || categoryId == null) return;
    setState(() => _loadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final result = await _pluginService.getCmsByCategory(
        pluginApi: _selectedSource ?? widget.sourcePlugin,
        categoryId: categoryId,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(List<Map<String, dynamic>>.from(result['list'] ?? []));
        _currentPage = nextPage;
        _totalPages = result['pages'] as int? ?? _totalPages;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _changeSource(String source) {
    if (_selectedSource == source) return;
    setState(() {
      _selectedSource = source;
      _selectedCategoryId = widget.categoryIds[source];
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final sourceOptions = widget.categoryIds.keys
        .map(
          (source) => CatalogFilterOption(
            id: source,
            label: _sourceLabel(source),
          ),
        )
        .toList(growable: false);

    return ViraPageScaffold(
      activeDestination: ViraDestination.discover,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: AnimeCatalogView(
        title: widget.title,
        description: widget.title == '剧场版'
            ? '一场完整放映的时间，把注意力留给银幕与故事。'
            : '按片源整理正在连载与已经完结的长篇动画。',
        sourceOptions: sourceOptions,
        selectedSourceId: _selectedSource,
        onSourceSelected: _changeSource,
        items: _items,
        isLoading: _loading,
        isLoadingMore: _loadingMore,
        errorMessage: _error,
        onOpenAnime: _openDetail,
        onRetry: _loadData,
        scrollController: _scrollController,
      ),
    );
  }

  String _sourceLabel(String source) {
    return switch (source) {
      'cms_yinhua' => '樱花动漫',
      'cms_ffzy' => '非凡资源',
      _ => source,
    };
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
