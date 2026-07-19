import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../models/catalog/catalog_enums.dart';
import '../../models/catalog/catalog_values.dart';
import '../../services/catalog/catalog_repository.dart';
import '../../services/catalog/catalog_settings.dart';
import '../../services/catalog/providers/anilist_catalog_provider.dart';
import '../../services/catalog/providers/catalog_provider_gateway.dart';
import '../../services/catalog/providers/cms_catalog_provider.dart';
import '../../services/catalog/providers/jikan_catalog_provider.dart';
import '../../services/plugin/plugin_service.dart';
import '../../services/storage/storage_service.dart';
import '../../stores/theme_store.dart';
import '../../theme/vira_colors.dart';
import '../../widgets/vira_page_chrome.dart';
import 'anime_catalog_view.dart';
import 'catalog_controller.dart';

class CategoryBrowsePage extends StatefulWidget {
  const CategoryBrowsePage({
    super.key,
    this.repository,
    this.providerOptions,
    this.includeAdult,
  });

  final CatalogRepository? repository;
  final List<CatalogFilterOption>? providerOptions;
  final bool? includeAdult;

  @override
  State<CategoryBrowsePage> createState() => _CategoryBrowsePageState();
}

class _CategoryBrowsePageState extends State<CategoryBrowsePage> {
  final _scrollController = ScrollController();
  late final CatalogController _controller;
  late final List<CatalogFilterOption> _providerOptions;
  bool _moreExpanded = false;

  @override
  void initState() {
    super.initState();
    final repository = widget.repository ?? _createRepository();
    _providerOptions = widget.providerOptions ?? _defaultProviderOptions();
    final includeAdult = widget.includeAdult ??
        (widget.repository == null
            ? StorageService().getSetting<bool>(
                  CatalogSettings.includeAdultKey,
                  defaultValue: false,
                ) ??
                false
            : false);
    _controller = CatalogController(
      repository: repository,
      includeAdult: includeAdult,
    );
    _scrollController.addListener(_onScroll);
    unawaited(_controller.initialize());
  }

  CatalogRepository _createRepository() {
    final pluginService = PluginService();
    final playableProviders = PluginService.enabledCatalogPlugins(
      pluginService.plugins,
    ).map((plugin) => CmsCatalogProvider(plugin: plugin)).toList();
    final gateway = CatalogProviderGateway(
      anilist: AniListCatalogProvider(),
      jikan: JikanCatalogProvider(),
      playableProviders: playableProviders,
    );
    return StorageService().createCatalogRepository(loadPage: gateway.load);
  }

  List<CatalogFilterOption> _defaultProviderOptions() {
    return PluginService.enabledCatalogPlugins(PluginService().plugins)
        .map(
          (plugin) => CatalogFilterOption(
            id: plugin.api,
            label: plugin.name,
          ),
        )
        .toList(growable: false);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 240 &&
        !_controller.isLoadingMore &&
        _controller.hasMore) {
      unawaited(_controller.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ViraPageScaffold(
      activeDestination: ViraDestination.discover,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final query = _controller.query;
          return AnimeCatalogView(
            title: '动画目录',
            description: query.mode == CatalogMode.discovery
                ? '先从完整元数据发现作品，再按需要查找可播放来源。'
                : '仅展示已解析出剧集与线路结构的作品，索引会随浏览渐进扩展。',
            toolbar: _CatalogToolbar(
              mode: query.mode,
              moreExpanded: _moreExpanded,
              onModeSelected: (mode) => unawaited(_controller.setMode(mode)),
              onMoreToggle: () {
                setState(() => _moreExpanded = !_moreExpanded);
              },
            ),
            filterGroups: _filterGroups(query),
            activeFilters: _filterSummaries(query),
            onClearFilters: () => unawaited(_controller.clearAllFilters()),
            items: _controller.items
                .map(CatalogCardData.fromContent)
                .toList(growable: false),
            progressLabel:
                _controller.coverage.complete ? '当前索引已覆盖' : '索引继续扩展中',
            warningMessage: _controller.updateWarning,
            isLoading: _controller.isLoading,
            isRefreshing: _controller.isRefreshing,
            isLoadingMore: _controller.isLoadingMore,
            errorMessage: _controller.errorMessage,
            onOpenAnime: _openDetail,
            onRetry: () => unawaited(_controller.refresh()),
            scrollController: _scrollController,
          );
        },
      ),
    );
  }

  List<CatalogFilterGroup> _filterGroups(CatalogQuery query) {
    final groups = <CatalogFilterGroup>[
      CatalogFilterGroup(
        id: 'genres',
        label: '题材',
        multiSelect: true,
        options: const [
          CatalogFilterOption(id: 'all', label: '全部'),
          ..._genreOptions,
        ],
        selectedIds: query.genres.isEmpty ? const {'all'} : query.genres,
        onSelected: (id) {
          unawaited(
            id == 'all'
                ? _controller.setGenres(const {})
                : _controller.toggleGenre(id),
          );
        },
      ),
      CatalogFilterGroup(
        id: 'year',
        label: '年份',
        options: [
          const CatalogFilterOption(id: 'all', label: '全部'),
          for (var year = DateTime.now().year;
              year >= DateTime.now().year - 15;
              year--)
            CatalogFilterOption(id: '$year', label: '$year'),
        ],
        selectedIds: {query.year?.toString() ?? 'all'},
        onSelected: (id) =>
            unawaited(_controller.setYear(id == 'all' ? null : int.parse(id))),
      ),
      CatalogFilterGroup(
        id: 'format',
        label: '形态',
        options: const [
          CatalogFilterOption(id: 'all', label: '全部'),
          CatalogFilterOption(id: 'tv', label: 'TV'),
          CatalogFilterOption(id: 'movie', label: '剧场版'),
          CatalogFilterOption(id: 'ova', label: 'OVA'),
          CatalogFilterOption(id: 'ona', label: 'ONA'),
          CatalogFilterOption(id: 'special', label: '特别篇'),
          CatalogFilterOption(id: 'music', label: '音乐'),
        ],
        selectedIds: {query.format?.name ?? 'all'},
        onSelected: (id) => unawaited(
          _controller.setFormat(
            id == 'all' ? null : CatalogFormat.fromName(id),
          ),
        ),
      ),
      CatalogFilterGroup(
        id: 'status',
        label: '状态',
        options: const [
          CatalogFilterOption(id: 'all', label: '全部'),
          CatalogFilterOption(id: 'airing', label: '连载中'),
          CatalogFilterOption(id: 'completed', label: '已完结'),
          CatalogFilterOption(id: 'upcoming', label: '未放送'),
          CatalogFilterOption(id: 'hiatus', label: '暂停'),
          CatalogFilterOption(id: 'cancelled', label: '已取消'),
        ],
        selectedIds: {query.status?.name ?? 'all'},
        onSelected: (id) => unawaited(
          _controller.setStatus(
            id == 'all' ? null : CatalogStatus.fromName(id),
          ),
        ),
      ),
    ];
    if (!_moreExpanded) return groups;
    groups.addAll([
      CatalogFilterGroup(
        id: 'season',
        label: '季度',
        options: const [
          CatalogFilterOption(id: 'all', label: '全部'),
          CatalogFilterOption(id: 'winter', label: '冬'),
          CatalogFilterOption(id: 'spring', label: '春'),
          CatalogFilterOption(id: 'summer', label: '夏'),
          CatalogFilterOption(id: 'fall', label: '秋'),
        ],
        selectedIds: {query.season?.name ?? 'all'},
        onSelected: (id) => unawaited(
          _controller.setSeason(
            id == 'all' ? null : CatalogSeason.fromName(id),
          ),
        ),
      ),
      CatalogFilterGroup(
        id: 'region',
        label: '地区',
        options: const [
          CatalogFilterOption(id: 'all', label: '全部'),
          CatalogFilterOption(id: 'japan', label: '日本'),
          CatalogFilterOption(id: 'china', label: '中国'),
          CatalogFilterOption(id: 'korea', label: '韩国'),
          CatalogFilterOption(id: 'western', label: '欧美'),
          CatalogFilterOption(id: 'other', label: '其他'),
        ],
        selectedIds: {query.region?.name ?? 'all'},
        onSelected: (id) => unawaited(
          _controller.setRegion(
            id == 'all' ? null : CatalogRegion.fromName(id),
          ),
        ),
      ),
      CatalogFilterGroup(
        id: 'score',
        label: '评分',
        options: const [
          CatalogFilterOption(id: 'all', label: '全部'),
          CatalogFilterOption(id: '7', label: '7.0+'),
          CatalogFilterOption(id: '8', label: '8.0+'),
          CatalogFilterOption(id: '9', label: '9.0+'),
        ],
        selectedIds: {
          query.minimumScore == null
              ? 'all'
              : query.minimumScore!.toStringAsFixed(0),
        },
        onSelected: (id) => unawaited(
          _controller.setMinimumScore(
            id == 'all' ? null : double.parse(id),
          ),
        ),
      ),
      CatalogFilterGroup(
        id: 'sort',
        label: '排序',
        options: const [
          CatalogFilterOption(id: 'relevance', label: '综合'),
          CatalogFilterOption(id: 'popularity', label: '人气'),
          CatalogFilterOption(id: 'rating', label: '评分'),
          CatalogFilterOption(id: 'updatedAt', label: '最近更新'),
          CatalogFilterOption(id: 'releaseDate', label: '放送时间'),
          CatalogFilterOption(id: 'title', label: '标题'),
        ],
        selectedIds: {query.sort.name},
        onSelected: (id) =>
            unawaited(_controller.setSort(CatalogSort.fromName(id))),
      ),
    ]);
    if (query.mode == CatalogMode.playable) {
      groups.addAll([
        CatalogFilterGroup(
          id: 'provider',
          label: '片源',
          options: [
            const CatalogFilterOption(id: 'all', label: '全部'),
            ..._providerOptions,
          ],
          selectedIds: {query.providerId ?? 'all'},
          onSelected: (id) => unawaited(
            _controller.setProvider(id == 'all' ? null : id),
          ),
        ),
        CatalogFilterGroup(
          id: 'updated',
          label: '更新时间',
          options: const [
            CatalogFilterOption(id: 'all', label: '全部'),
            CatalogFilterOption(id: '1d', label: '24 小时内'),
            CatalogFilterOption(id: '7d', label: '7 天内'),
            CatalogFilterOption(id: '30d', label: '30 天内'),
          ],
          selectedIds: {_durationId(query.updatedWithin)},
          onSelected: (id) => unawaited(
            _controller.setUpdatedWithin(
              switch (id) {
                '1d' => const Duration(days: 1),
                '7d' => const Duration(days: 7),
                '30d' => const Duration(days: 30),
                _ => null,
              },
            ),
          ),
        ),
      ]);
    }
    return groups;
  }

  List<CatalogFilterSummary> _filterSummaries(CatalogQuery query) {
    final summaries = <CatalogFilterSummary>[
      for (final genre in query.genres)
        CatalogFilterSummary(
          id: 'genre-$genre',
          label: _labelFor(_genreOptions, genre),
          onRemove: () => unawaited(_controller.toggleGenre(genre)),
        ),
      if (query.year != null)
        CatalogFilterSummary(
          id: 'year',
          label: '${query.year} 年',
          onRemove: () => unawaited(_controller.setYear(null)),
        ),
      if (query.format != null)
        CatalogFilterSummary(
          id: 'format',
          label: '形态 ${query.format!.name.toUpperCase()}',
          onRemove: () => unawaited(_controller.setFormat(null)),
        ),
      if (query.status != null)
        CatalogFilterSummary(
          id: 'status',
          label: '状态 ${query.status!.name}',
          onRemove: () => unawaited(_controller.setStatus(null)),
        ),
      if (query.season != null)
        CatalogFilterSummary(
          id: 'season',
          label: '季度 ${query.season!.name}',
          onRemove: () => unawaited(_controller.setSeason(null)),
        ),
      if (query.region != null)
        CatalogFilterSummary(
          id: 'region',
          label: '地区 ${query.region!.name}',
          onRemove: () => unawaited(_controller.setRegion(null)),
        ),
      if (query.minimumScore != null)
        CatalogFilterSummary(
          id: 'score',
          label: '${query.minimumScore!.toStringAsFixed(1)} 分以上',
          onRemove: () => unawaited(_controller.setMinimumScore(null)),
        ),
      if (query.sort != CatalogSort.relevance)
        CatalogFilterSummary(
          id: 'sort',
          label: '排序 ${query.sort.name}',
          onRemove: () => unawaited(_controller.setSort(CatalogSort.relevance)),
        ),
      if (query.providerId != null)
        CatalogFilterSummary(
          id: 'provider',
          label: '片源 ${_labelFor(_providerOptions, query.providerId!)}',
          onRemove: () => unawaited(_controller.setProvider(null)),
        ),
      if (query.updatedWithin != null)
        CatalogFilterSummary(
          id: 'updated',
          label: '更新 ${_durationLabel(query.updatedWithin!)}',
          onRemove: () => unawaited(_controller.setUpdatedWithin(null)),
        ),
    ];
    return summaries;
  }

  void _openDestination(ViraDestination destination) {
    final route = switch (destination) {
      ViraDestination.home => '/',
      ViraDestination.discover => '/category',
      ViraDestination.following => '/track',
      ViraDestination.library => '/collect',
      ViraDestination.downloads => '/download',
    };
    if (destination != ViraDestination.discover) Modular.to.navigate(route);
  }

  void _openDetail(CatalogCardData item) {
    final params = <String, String>{
      if (item.contentId.isNotEmpty) 'contentId': item.contentId,
      if (item.legacyUrl?.isNotEmpty == true) 'url': item.legacyUrl!,
      'name': item.name,
    };
    final query = params.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    Modular.to.pushNamed('/detail?$query');
  }
}

class _CatalogToolbar extends StatelessWidget {
  const _CatalogToolbar({
    required this.mode,
    required this.moreExpanded,
    required this.onModeSelected,
    required this.onMoreToggle,
  });

  final CatalogMode mode;
  final bool moreExpanded;
  final ValueChanged<CatalogMode> onModeSelected;
  final VoidCallback onMoreToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border.all(color: context.colors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              children: [
                _ModeChoice(
                  semanticKey: const ValueKey('catalog-mode-discovery'),
                  label: '发现动画',
                  selected: mode == CatalogMode.discovery,
                  onTap: () => onModeSelected(CatalogMode.discovery),
                ),
                _ModeChoice(
                  semanticKey: const ValueKey('catalog-mode-playable'),
                  label: '可播放片库',
                  selected: mode == CatalogMode.playable,
                  onTap: () => onModeSelected(CatalogMode.playable),
                ),
              ],
            ),
          ),
          TextButton.icon(
            key: const ValueKey('catalog-more-filters'),
            onPressed: onMoreToggle,
            icon: Icon(
              moreExpanded ? Icons.expand_less : Icons.tune,
              size: 18,
            ),
            label: Text(moreExpanded ? '收起筛选' : '更多筛选'),
          ),
        ],
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.semanticKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key semanticKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticKey,
      button: true,
      selected: selected,
      label: label,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor:
              selected ? context.colors.sky : context.colors.textSecondary,
          backgroundColor:
              selected ? context.colors.skyLight : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: BorderSide(
            color: selected ? context.colors.sky : Colors.transparent,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

const _genreOptions = [
  CatalogFilterOption(id: 'action', label: '动作'),
  CatalogFilterOption(id: 'adventure', label: '冒险'),
  CatalogFilterOption(id: 'comedy', label: '喜剧'),
  CatalogFilterOption(id: 'drama', label: '剧情'),
  CatalogFilterOption(id: 'fantasy', label: '奇幻'),
  CatalogFilterOption(id: 'sciFi', label: '科幻'),
  CatalogFilterOption(id: 'romance', label: '恋爱'),
  CatalogFilterOption(id: 'school', label: '校园'),
  CatalogFilterOption(id: 'sliceOfLife', label: '日常'),
  CatalogFilterOption(id: 'healing', label: '治愈'),
  CatalogFilterOption(id: 'mystery', label: '悬疑'),
  CatalogFilterOption(id: 'thriller', label: '惊悚'),
  CatalogFilterOption(id: 'horror', label: '恐怖'),
  CatalogFilterOption(id: 'sports', label: '运动'),
  CatalogFilterOption(id: 'music', label: '音乐'),
  CatalogFilterOption(id: 'historical', label: '历史'),
  CatalogFilterOption(id: 'military', label: '战争'),
  CatalogFilterOption(id: 'mecha', label: '机甲'),
  CatalogFilterOption(id: 'magicalGirl', label: '魔法少女'),
  CatalogFilterOption(id: 'isekai', label: '异世界'),
  CatalogFilterOption(id: 'family', label: '家庭'),
  CatalogFilterOption(id: 'supernatural', label: '超自然'),
];

String _labelFor(List<CatalogFilterOption> options, String id) {
  for (final option in options) {
    if (option.id == id) return option.label;
  }
  return id;
}

String _durationId(Duration? duration) => switch (duration?.inDays) {
      1 => '1d',
      7 => '7d',
      30 => '30d',
      _ => 'all',
    };

String _durationLabel(Duration duration) => switch (duration.inDays) {
      1 => '24 小时内',
      7 => '7 天内',
      30 => '30 天内',
      _ => '${duration.inDays} 天内',
    };
