import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../models/anime.dart';
import '../../services/plugin/plugin_service.dart';
import '../../services/storage/storage_service.dart';
import '../../stores/anime_store.dart';
import '../../stores/theme_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/vira_page_chrome.dart';
import 'search_editorial_masthead.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _historyKey = 'search_history';
  static const _suggestions = ['葬送的芙莉莲', '孤独摇滚', '迷宫饭', '药屋少女的呢喃'];

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final _store = AnimeStore();
  final List<String> _searchHistory = [];

  Timer? _debounce;
  String _selectedSource = '全部';
  String _query = '';
  bool _searchFocused = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _focusNode.addListener(_handleFocusChanged);

    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      _controller.text = initialQuery;
      _query = initialQuery;
      _hasSearched = true;
      _rememberKeyword(initialQuery);
      _store.search(initialQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    final saved = StorageService().getSetting<List<dynamic>>(
      _historyKey,
      defaultValue: const [],
    );
    _searchHistory
      ..clear()
      ..addAll((saved ?? const []).whereType<String>().take(8));
  }

  void _handleFocusChanged() {
    if (mounted) setState(() => _searchFocused = _focusNode.hasFocus);
  }

  void _focusSearch() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: AppAnimations.normal,
        curve: AppAnimations.easeOut,
      );
    }
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  void _doSearch() {
    _debounce?.cancel();
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) {
      _focusSearch();
      return;
    }

    _rememberKeyword(keyword);
    setState(() {
      _query = keyword;
      _hasSearched = true;
      _selectedSource = '全部';
    });
    _store.search(keyword);
    _focusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final keyword = value.trim();
    setState(() => _query = keyword);

    if (keyword.isEmpty) {
      _store.clearSearch();
      setState(() {
        _hasSearched = false;
        _selectedSource = '全部';
      });
      return;
    }

    _store.invalidatePendingSearch();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || keyword != _controller.text.trim()) return;
      setState(() {
        _hasSearched = true;
        _selectedSource = '全部';
      });
      _store.search(keyword);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _controller.clear();
    _store.clearSearch();
    setState(() {
      _query = '';
      _hasSearched = false;
      _selectedSource = '全部';
    });
    _focusSearch();
  }

  void _rememberKeyword(String keyword) {
    if (keyword.isEmpty) return;
    setState(() {
      _searchHistory.remove(keyword);
      _searchHistory.insert(0, keyword);
      if (_searchHistory.length > 8) _searchHistory.removeLast();
    });
    unawaited(
        StorageService().setSetting(_historyKey, _searchHistory.toList()));
  }

  void _removeHistory(String keyword) {
    setState(() => _searchHistory.remove(keyword));
    unawaited(
        StorageService().setSetting(_historyKey, _searchHistory.toList()));
  }

  void _clearHistory() {
    setState(_searchHistory.clear);
    unawaited(StorageService().setSetting(_historyKey, const <String>[]));
  }

  void _searchKeyword(String keyword) {
    _controller.text = keyword;
    _controller.selection = TextSelection.collapsed(offset: keyword.length);
    setState(() => _query = keyword);
    _doSearch();
  }

  List<Anime> _filteredResults(List<Anime> results) {
    if (_selectedSource == '全部') return results;
    return results
        .where((anime) => anime.sourcePlugin == _selectedSource)
        .toList();
  }

  List<String> _sourceFilters(List<Anime> results) {
    final sources = results
        .map((anime) => anime.sourcePlugin)
        .where((source) => source.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['全部', ...sources];
  }

  Map<String, int> _sourceCounts(List<Anime> results, List<String> filters) {
    return {
      for (final source in filters)
        source: source == '全部'
            ? results.length
            : results.where((anime) => anime.sourcePlugin == source).length,
    };
  }

  void _openDetail(Anime anime) {
    Modular.to.pushNamed(
      '/detail?url=${Uri.encodeComponent(anime.url)}&name=${Uri.encodeComponent(anime.name)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.escape): _clearSearch,
      },
      child: Focus(
        autofocus: true,
        child: ViraPageScaffold(
          activeDestination: ViraDestination.discover,
          onDestinationSelected: _openDestination,
          onSearch: _focusSearch,
          onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
          onProfile: () => Modular.to.pushNamed('/settings'),
          child: Observer(
            builder: (_) {
              final results = _store.searchResults.toList();
              final filters = _sourceFilters(results);
              final selectedSource =
                  filters.contains(_selectedSource) ? _selectedSource : '全部';
              final filteredResults = selectedSource == _selectedSource
                  ? _filteredResults(results)
                  : results;
              final hasRealError = _store.errorMessage != null &&
                  _store.errorMessage != '没有找到相关结果';

              return CustomScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: _SearchMasthead(
                      controller: _controller,
                      focusNode: _focusNode,
                      focused: _searchFocused,
                      query: _query,
                      isLoading: _store.isLoading,
                      enabledPluginCount:
                          PluginService().getEnabledPlugins().length,
                      history: _searchHistory,
                      suggestions: _suggestions,
                      onSearch: _doSearch,
                      onChanged: _onSearchChanged,
                      onClearSearch: _clearSearch,
                      onKeywordTap: _searchKeyword,
                      onHistoryRemove: _removeHistory,
                      onHistoryClear: _clearHistory,
                    ),
                  ),
                  if (results.isNotEmpty && !_store.isLoading)
                    SliverToBoxAdapter(
                      child: _ResultToolbar(
                        query: _store.lastKeyword,
                        resultCount: filteredResults.length,
                        totalCount: results.length,
                        filters: filters,
                        selected: selectedSource,
                        counts: _sourceCounts(results, filters),
                        onSelected: (source) {
                          setState(() => _selectedSource = source);
                        },
                      ),
                    ),
                  if (_store.isLoading)
                    const _SearchSkeletonSliver()
                  else if (hasRealError && results.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SearchStatePanel(
                        icon: Icons.cloud_off_outlined,
                        eyebrow: '连接未完成',
                        title: '这次搜索没有顺利抵达',
                        subtitle: '请检查插件状态或网络连接，然后再试一次。',
                        actionLabel: '重新搜索',
                        onAction: _doSearch,
                      ),
                    )
                  else if (!_hasSearched && results.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SearchStatePanel(
                        icon: Icons.explore_outlined,
                        eyebrow: '发现下一部作品',
                        title: '从一个名字开始',
                        subtitle: '支持中文名、原名、别名与关键词，按 Enter 立即搜索。',
                      ),
                    )
                  else if (results.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SearchStatePanel(
                        icon: Icons.search_off_rounded,
                        eyebrow: '没有匹配结果',
                        title: '换一种说法试试看',
                        subtitle: '可以尝试作品别名、缩短关键词，或确认已启用对应数据源。',
                        actionLabel: '修改关键词',
                        onAction: _focusSearch,
                      ),
                    )
                  else if (filteredResults.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _SearchStatePanel(
                        icon: Icons.filter_alt_off_outlined,
                        eyebrow: '当前来源为空',
                        title: '这个来源暂时没有结果',
                        subtitle: '切换到“全部来源”查看其他数据源返回的作品。',
                      ),
                    )
                  else
                    _SearchResultGrid(
                      results: filteredResults,
                      onTap: _openDetail,
                    ),
                ],
              );
            },
          ),
        ),
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
}

class _SearchMasthead extends StatelessWidget {
  const _SearchMasthead({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.query,
    required this.isLoading,
    required this.enabledPluginCount,
    required this.history,
    required this.suggestions,
    required this.onSearch,
    required this.onChanged,
    required this.onClearSearch,
    required this.onKeywordTap,
    required this.onHistoryRemove,
    required this.onHistoryClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final String query;
  final bool isLoading;
  final int enabledPluginCount;
  final List<String> history;
  final List<String> suggestions;
  final VoidCallback onSearch;
  final ValueChanged<String> onChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onKeywordTap;
  final ValueChanged<String> onHistoryRemove;
  final VoidCallback onHistoryClear;

  @override
  Widget build(BuildContext context) {
    return SearchEditorialMasthead(
      controller: controller,
      focusNode: focusNode,
      focused: focused,
      query: query,
      isLoading: isLoading,
      enabledPluginCount: enabledPluginCount,
      history: history,
      suggestions: suggestions,
      onSearch: onSearch,
      onChanged: onChanged,
      onClearSearch: onClearSearch,
      onKeywordTap: onKeywordTap,
      onHistoryRemove: onHistoryRemove,
      onHistoryClear: onHistoryClear,
    );
  }
}

class _ResultToolbar extends StatelessWidget {
  const _ResultToolbar({
    required this.query,
    required this.resultCount,
    required this.totalCount,
    required this.filters,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  final String query;
  final int resultCount;
  final int totalCount;
  final List<String> filters;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“$query”的搜索结果',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resultCount == totalCount
                          ? '共找到 $totalCount 部作品'
                          : '当前显示 $resultCount 部，共 $totalCount 部作品',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                '按数据源筛选',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((source) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SourceFilter(
                    label: source == '全部' ? '全部来源' : _sourceLabel(source),
                    count: counts[source] ?? 0,
                    selected: source == selected,
                    onTap: () => onSelected(source),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultGrid extends StatelessWidget {
  const _SearchResultGrid({required this.results, required this.onTap});

  final List<Anime> results;
  final ValueChanged<Anime> onTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 36),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final maxExtent = constraints.crossAxisExtent < 760 ? 205.0 : 238.0;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: maxExtent,
              mainAxisExtent: 342,
              crossAxisSpacing: 18,
              mainAxisSpacing: 22,
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final anime = results[index];
              return FadeSlideIn(
                delay: Duration(
                  milliseconds: (index.clamp(0, 8)) * 35,
                ),
                child: _SearchResultCard(
                  anime: anime,
                  index: index,
                  onTap: () => onTap(anime),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchResultCard extends StatefulWidget {
  const _SearchResultCard({
    required this.anime,
    required this.index,
    required this.onTap,
  });

  final Anime anime;
  final int index;
  final VoidCallback onTap;

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _hovering = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovering || _focused;
    final anime = widget.anime;
    return Semantics(
      button: true,
      label: '查看${anime.name}',
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
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: AppAnimations.fast,
              curve: AppAnimations.easeOut,
              decoration: BoxDecoration(
                color: context.colors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: highlighted
                      ? AppTheme.primaryBlue.withValues(alpha: 0.58)
                      : context.colors.divider,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: highlighted ? 0.28 : 0.14,
                    ),
                    blurRadius: highlighted ? 18 : 10,
                    offset: Offset(0, highlighted ? 9 : 5),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedScale(
                          scale: highlighted ? 1.025 : 1,
                          duration: AppAnimations.normal,
                          curve: AppAnimations.easeOut,
                          child: CoverImage(
                            url: anime.cover,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const _ResultCoverScrim(),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: _SourceBadge(
                            label: _sourceLabel(anime.sourcePlugin),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _IndexBadge(index: widget.index + 1),
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: AnimatedOpacity(
                            duration: AppAnimations.fast,
                            opacity: highlighted ? 1 : 0,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: AppAnimations.fast,
                          style:
                              Theme.of(context).textTheme.titleSmall!.copyWith(
                                    color: highlighted
                                        ? AppTheme.accentBlue
                                        : context.colors.textPrimary,
                                  ),
                          child: Text(
                            anime.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: 13,
                              color: context.colors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _sourceLabel(anime.sourcePlugin),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
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
        ),
      ),
    );
  }
}

class _SearchSkeletonSliver extends StatefulWidget {
  const _SearchSkeletonSliver();

  @override
  State<_SearchSkeletonSliver> createState() => _SearchSkeletonSliverState();
}

class _SearchSkeletonSliverState extends State<_SearchSkeletonSliver>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      lowerBound: 0.25,
      upperBound: 0.72,
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion == _reduceMotion) return;
    _reduceMotion = reduceMotion;
    if (_reduceMotion) {
      _controller.stop();
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 36),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final maxExtent = constraints.crossAxisExtent < 760 ? 205.0 : 238.0;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final value = _reduceMotion ? 0.48 : _controller.value;
              return SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  mainAxisExtent: 342,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 22,
                ),
                itemCount: 8,
                itemBuilder: (_, __) => _SearchResultSkeleton(value: value),
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchResultSkeleton extends StatelessWidget {
  const _SearchResultSkeleton({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final fill = Color.lerp(
      context.colors.bgSurface,
      context.colors.bgHover,
      value,
    )!;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: ColoredBox(color: fill)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonLine(widthFactor: 0.78, color: fill),
                const SizedBox(height: 8),
                _SkeletonLine(widthFactor: 0.5, color: fill, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.widthFactor,
    required this.color,
    this.height = 13,
  });

  final double widthFactor;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _SearchStatePanel extends StatelessWidget {
  const _SearchStatePanel({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: context.colors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.divider),
                ),
                child: Icon(icon, color: AppTheme.primaryBlue, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                eyebrow,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.primaryBlue,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceFilter extends StatefulWidget {
  const _SourceFilter({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SourceFilter> createState() => _SourceFilterState();
}

class _SourceFilterState extends State<_SourceFilter> {
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
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.14)
                : (_hovering ? context.colors.bgHover : context.colors.bgCard),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.selected || _hovering
                  ? AppTheme.primaryBlue.withValues(alpha: 0.42)
                  : context.colors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: widget.selected
                          ? AppTheme.accentBlue
                          : context.colors.textSecondary,
                    ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: context.colors.tagBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.count.toString(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Text(
      index.toString().padLeft(2, '0'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
      ),
    );
  }
}

class _ResultCoverScrim extends StatelessWidget {
  const _ResultCoverScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.38),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
    );
  }
}

String _sourceLabel(String source) {
  if (source.startsWith('cms_')) {
    final name = source.replaceFirst('cms_', '').trim();
    return name.isEmpty ? 'CMS' : 'CMS · $name';
  }
  switch (source.toLowerCase()) {
    case 'jikan':
      return 'MAL';
    case 'bangumi':
      return 'Bangumi';
    case 'anilist':
      return 'AniList';
    default:
      return source.isEmpty ? '未知来源' : source;
  }
}
