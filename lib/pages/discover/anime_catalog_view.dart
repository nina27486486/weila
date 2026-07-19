import 'package:flutter/material.dart';

import '../../models/catalog/catalog_enums.dart';
import '../../models/catalog/catalog_values.dart';
import '../../theme/vira_colors.dart';
import '../../widgets/artwork_components.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/vira_state_view.dart';

const _catalogCardBodyHeight = 326.0;
const _catalogCardLift = 6.0;
const _catalogVisibleRowSpacing = 22.0;

@immutable
class CatalogFilterOption {
  const CatalogFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

@immutable
class CatalogFilterGroup {
  const CatalogFilterGroup({
    required this.id,
    required this.label,
    required this.options,
    required this.selectedIds,
    required this.onSelected,
    this.multiSelect = false,
  });

  final String id;
  final String label;
  final List<CatalogFilterOption> options;
  final Set<String> selectedIds;
  final ValueChanged<String> onSelected;
  final bool multiSelect;
}

@immutable
class CatalogFilterSummary {
  const CatalogFilterSummary({
    required this.id,
    required this.label,
    required this.onRemove,
  });

  final String id;
  final String label;
  final VoidCallback onRemove;
}

@immutable
class CatalogCardData {
  const CatalogCardData({
    required this.contentId,
    required this.name,
    this.coverUrl,
    this.score,
    this.statusLabel = '',
    this.genres = const [],
    this.legacyUrl,
    this.sourcePlugin,
  });

  final String contentId;
  final String name;
  final String? coverUrl;
  final double? score;
  final String statusLabel;
  final List<String> genres;
  final String? legacyUrl;
  final String? sourcePlugin;

  factory CatalogCardData.fromContent(CatalogContent content) {
    final playable = content.playableRefs.firstOrNull;
    return CatalogCardData(
      contentId: content.contentId,
      name: content.titles.chinese ?? content.titles.primary,
      coverUrl: content.coverUrl,
      score: _bestScore(content),
      statusLabel: _statusLabel(content.status),
      genres: content.genres.map(_genreLabel).toList(growable: false),
      legacyUrl: playable == null
          ? null
          : '${playable.providerId}:${playable.sourceItemId}',
      sourcePlugin: playable?.providerId,
    );
  }

  factory CatalogCardData.fromLegacyMap(Map<String, dynamic> item) {
    final rawGenres = item['genres'];
    return CatalogCardData(
      contentId: item['contentId']?.toString() ??
          item['url']?.toString() ??
          item['id']?.toString() ??
          '',
      name: item['name']?.toString() ?? '未命名作品',
      coverUrl: item['cover']?.toString(),
      score: _scoreOf(item['score']),
      statusLabel: item['status']?.toString() ?? '',
      genres: rawGenres is List
          ? rawGenres.map((entry) => entry.toString()).toList(growable: false)
          : const [],
      legacyUrl: item['url']?.toString(),
      sourcePlugin: item['sourcePlugin']?.toString(),
    );
  }
}

class AnimeCatalogView extends StatelessWidget {
  const AnimeCatalogView({
    super.key,
    required this.title,
    required this.description,
    required this.items,
    required this.onOpenAnime,
    required this.onRetry,
    this.filterGroups = const [],
    this.activeFilters = const [],
    this.onClearFilters,
    this.toolbar,
    this.progressLabel,
    this.warningMessage,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.scrollController,
  });

  final String title;
  final String description;
  final List<CatalogFilterGroup> filterGroups;
  final List<CatalogFilterSummary> activeFilters;
  final VoidCallback? onClearFilters;
  final Widget? toolbar;
  final String? progressLabel;
  final String? warningMessage;
  final List<CatalogCardData> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? errorMessage;
  final ValueChanged<CatalogCardData> onOpenAnime;
  final VoidCallback onRetry;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34),
            child: _CatalogIntroduction(
              title: title,
              description: description,
              itemCount: items.length,
              progressLabel: progressLabel,
              isRefreshing: isRefreshing,
            ),
          ),
        ),
        if (toolbar != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: toolbar,
            ),
          ),
        if (filterGroups.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _CatalogFilters(groups: filterGroups),
            ),
          ),
        if (activeFilters.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _CatalogFilterSummaries(
                summaries: activeFilters,
                onClear: onClearFilters,
              ),
            ),
          ),
        if (warningMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _CatalogWarning(message: warningMessage!),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 30, bottom: 16),
            child: _ResultHeading(itemCount: items.length),
          ),
        ),
        if (isLoading && items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.loading(
              title: '正在翻阅片库',
              message: '元数据、索引与播放能力正在汇合。',
            ),
          )
        else if (errorMessage != null && items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.error(
              title: '片库暂时没有回应',
              message: errorMessage!,
              onRetry: onRetry,
            ),
          )
        else if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.empty(
              title: '这一格还是空白',
              message: '换一个标签或筛选条件再看看。',
            ),
          )
        else
          SliverPadding(
            key: const ValueKey('catalog-results-grid'),
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 218,
                mainAxisExtent: _catalogCardBodyHeight + _catalogCardLift,
                crossAxisSpacing: 16,
                mainAxisSpacing: _catalogVisibleRowSpacing - _catalogCardLift,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _CatalogAnimeCard(
                  index: index,
                  item: item,
                  onTap: () => onOpenAnime(item),
                );
              },
            ),
          ),
        if (isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.sky,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CatalogIntroduction extends StatelessWidget {
  const _CatalogIntroduction({
    required this.title,
    required this.description,
    required this.itemCount,
    required this.progressLabel,
    required this.isRefreshing,
  });

  final String title;
  final String description;
  final int itemCount;
  final String? progressLabel;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 32, height: 1, color: colors.sakura),
                    const SizedBox(width: 10),
                    Text(
                      '发现下一段故事',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.sky,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 40,
                      ),
                ),
                const SizedBox(height: 9),
                Text(description,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          Container(
            width: 150,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: colors.paper,
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      itemCount.toString().padLeft(2, '0'),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: colors.sky,
                              ),
                    ),
                    if (isRefreshing) ...[
                      const Spacer(),
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: colors.sky,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  progressLabel ?? '当前结果',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogFilters extends StatelessWidget {
  const _CatalogFilters({required this.groups});

  final List<CatalogFilterGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < groups.length; index++) ...[
            if (index > 0) Divider(height: 1, color: context.colors.divider),
            _FilterLine(group: groups[index]),
          ],
        ],
      ),
    );
  }
}

class _FilterLine extends StatelessWidget {
  const _FilterLine({required this.group});

  final CatalogFilterGroup group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                group.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.colors.textMuted,
                    ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final option in group.options)
                  _FilterChoice(
                    key: ValueKey('catalog-filter-${group.id}-${option.id}'),
                    option: option,
                    selected: group.selectedIds.contains(option.id),
                    onTap: () => group.onSelected(option.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CatalogFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: TextButton(
        onPressed: onTap,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => selected || states.contains(WidgetState.hovered)
                ? colors.sky
                : colors.textSecondary,
          ),
          backgroundColor: WidgetStatePropertyAll(
            selected ? colors.skyLight : Colors.transparent,
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: selected ? colors.sky : Colors.transparent,
              width: 1,
            ),
          ),
        ),
        child: Text(option.label),
      ),
    );
  }
}

class _CatalogFilterSummaries extends StatelessWidget {
  const _CatalogFilterSummaries({
    required this.summaries,
    required this.onClear,
  });

  final List<CatalogFilterSummary> summaries;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, right: 10),
          child: Text('已选', style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final summary in summaries)
                Container(
                  key: ValueKey('catalog-summary-${summary.id}'),
                  height: 34,
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    color: context.colors.skyLight,
                    border: Border.all(
                        color: context.colors.sky.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(summary.label),
                      IconButton(
                        tooltip: '移除${summary.label}',
                        onPressed: summary.onRemove,
                        icon: const Icon(Icons.close, size: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        constraints: const BoxConstraints(minWidth: 30),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('清空条件')),
      ],
    );
  }
}

class _CatalogWarning extends StatelessWidget {
  const _CatalogWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.warning.withValues(alpha: 0.1),
          border:
              Border(left: BorderSide(color: context.colors.warning, width: 3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: context.colors.warning),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ResultHeading extends StatelessWidget {
  const _ResultHeading({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 28, color: context.colors.sky),
        const SizedBox(width: 10),
        Text('片单', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(width: 10),
        Text(
          '已加载 $itemCount 部',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _CatalogAnimeCard extends StatelessWidget {
  const _CatalogAnimeCard({
    required this.index,
    required this.item,
    required this.onTap,
  });

  final int index;
  final CatalogCardData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ArtworkCardSurface(
      id: 'catalog-$index',
      semanticLabel: '打开第${index + 1}部作品，${item.name}',
      onOpen: onTap,
      lift: _catalogCardLift,
      contentBuilder: (context, interaction) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  key: ValueKey('catalog-cover-clip-$index'),
                  clipBehavior: Clip.hardEdge,
                  child: AnimatedScale(
                    key: ValueKey('catalog-cover-scale-$index'),
                    duration: interaction.duration,
                    curve: Curves.easeOutCubic,
                    scale: interaction.coverScale,
                    child: CoverImage(url: item.coverUrl, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  left: 9,
                  top: 9,
                  child: ArtworkCardBadge(
                    key: ValueKey('catalog-rank-$index'),
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.sky,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ),
                if (item.score != null)
                  Positioned(
                    right: 9,
                    top: 9,
                    child: ArtworkCardBadge(
                      key: ValueKey('catalog-score-$index'),
                      dark: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 12, color: colors.warning),
                          const SizedBox(width: 2),
                          Text(
                            item.score!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  item.genres.isEmpty
                      ? item.statusLabel
                      : item.genres.take(2).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double? _scoreOf(Object? raw) =>
    raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');

double? _bestScore(CatalogContent content) {
  double? result;
  for (final rating in content.ratings.values) {
    final score = rating.score;
    if (score != null && (result == null || score > result)) result = score;
  }
  return result;
}

String _statusLabel(CatalogStatus status) => switch (status) {
      CatalogStatus.upcoming => '即将播出',
      CatalogStatus.airing => '连载中',
      CatalogStatus.completed => '已完结',
      CatalogStatus.hiatus => '暂停播出',
      CatalogStatus.cancelled => '已取消',
      CatalogStatus.unknown => '',
    };

String _genreLabel(String genre) =>
    const {
      'action': '动作',
      'adventure': '冒险',
      'comedy': '喜剧',
      'drama': '剧情',
      'fantasy': '奇幻',
      'sciFi': '科幻',
      'romance': '恋爱',
      'school': '校园',
      'sliceOfLife': '日常',
      'healing': '治愈',
      'mystery': '悬疑',
      'thriller': '惊悚',
      'horror': '恐怖',
      'sports': '运动',
      'music': '音乐',
      'historical': '历史',
      'military': '战争',
      'mecha': '机甲',
      'magicalGirl': '魔法少女',
      'isekai': '异世界',
      'family': '家庭',
      'supernatural': '超自然',
    }[genre] ??
    genre;
