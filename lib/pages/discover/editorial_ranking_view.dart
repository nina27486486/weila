import 'package:flutter/material.dart';

import '../../theme/vira_colors.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/editorial_section_header.dart';
import '../../widgets/vira_state_view.dart';

@immutable
class RankingStory {
  final Map<String, dynamic> item;
  final int rank;
  final double? score;
  final List<String> genres;
  final int? delta;

  const RankingStory({
    required this.item,
    required this.rank,
    required this.score,
    required this.genres,
    this.delta,
  });
}

class EditorialRankingView extends StatelessWidget {
  final List<RankingStory> stories;
  final String source;
  final String scoreFilter;
  final String statusFilter;
  final String? genreFilter;
  final List<String> availableGenres;
  final bool hasActiveFilters;
  final bool hasComparison;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onScoreChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String?> onGenreChanged;
  final VoidCallback onResetFilters;
  final ValueChanged<Map<String, dynamic>> onOpenAnime;
  final VoidCallback onRefresh;

  const EditorialRankingView({
    super.key,
    required this.stories,
    required this.source,
    required this.scoreFilter,
    required this.statusFilter,
    required this.onSourceChanged,
    required this.onScoreChanged,
    required this.onStatusChanged,
    required this.onGenreChanged,
    required this.onResetFilters,
    required this.onOpenAnime,
    required this.onRefresh,
    this.genreFilter,
    this.availableGenres = const [],
    this.hasActiveFilters = false,
    this.hasComparison = false,
    this.isLoading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && stories.isEmpty) {
      return const ViraStateView.loading(
        title: '正在整理本期榜单',
        message: '口碑、热度与名次正在汇合。',
      );
    }
    if (errorMessage != null && stories.isEmpty) {
      return ViraStateView.error(
        title: '榜单暂时离席',
        message: errorMessage!,
        onRetry: onRefresh,
      );
    }
    if (stories.isEmpty && !hasActiveFilters) {
      return ViraStateView.empty(
        title: '本期榜单仍是空白',
        message: '换一个榜源，或者稍后刷新看看。',
        actionLabel: '刷新榜单',
        onAction: onRefresh,
      );
    }

    final topStories =
        hasActiveFilters ? const <RankingStory>[] : stories.take(3).toList();
    final listStories =
        hasActiveFilters ? stories : stories.skip(3).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.only(top: 28, bottom: 54),
      children: [
        _RankingIntroduction(
          key: const ValueKey('ranking-editorial-intro'),
          storyCount: stories.length,
          source: source,
          hasComparison: hasComparison,
          onRefresh: onRefresh,
          refreshing: isLoading,
        ),
        const SizedBox(height: 22),
        _RankingFilters(
          source: source,
          scoreFilter: scoreFilter,
          statusFilter: statusFilter,
          genreFilter: genreFilter,
          availableGenres: availableGenres,
          hasActiveFilters: hasActiveFilters,
          onSourceChanged: onSourceChanged,
          onScoreChanged: onScoreChanged,
          onStatusChanged: onStatusChanged,
          onGenreChanged: onGenreChanged,
          onReset: onResetFilters,
        ),
        if (topStories.isNotEmpty) ...[
          const SizedBox(height: 38),
          const EditorialSectionHeader(
            chapter: '前三名',
            title: '本期领跑者',
            subtitle: '让封面和作品自己说话',
          ),
          const SizedBox(height: 16),
          _TopThreeLayout(
            key: const ValueKey('ranking-top-three'),
            stories: topStories,
            onOpen: onOpenAnime,
          ),
        ],
        const SizedBox(height: 42),
        EditorialSectionHeader(
          chapter: hasActiveFilters ? '筛选页' : '总榜页',
          title: hasActiveFilters ? '筛选结果' : '完整榜单',
          subtitle: '${listStories.length} 部作品',
        ),
        const SizedBox(height: 16),
        _RankingList(
          key: const ValueKey('ranking-list'),
          stories: listStories,
          hasActiveFilters: hasActiveFilters,
          onOpen: onOpenAnime,
          onReset: onResetFilters,
        ),
      ],
    );
  }
}

class _RankingIntroduction extends StatelessWidget {
  final int storyCount;
  final String source;
  final bool hasComparison;
  final VoidCallback onRefresh;
  final bool refreshing;

  const _RankingIntroduction({
    super.key,
    required this.storyCount,
    required this.source,
    required this.hasComparison,
    required this.onRefresh,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      height: 246,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: colors.paper,
                border: Border(
                  top: BorderSide(color: colors.divider),
                  bottom: BorderSide(color: colors.divider),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 460,
            child: ClipRect(
              child: Opacity(
                opacity: Theme.of(context).brightness == Brightness.dark
                    ? 0.72
                    : 0.9,
                child: Image.asset(
                  'assets/images/ranking_hero_anime.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.4, -0.45),
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 520,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    colors.paper,
                    colors.paper.withValues(alpha: 0.72),
                    colors.paper.withValues(alpha: 0.02),
                  ],
                  stops: const [0, 0.28, 0.72],
                ),
              ),
            ),
          ),
          Positioned(
            left: 28,
            top: 26,
            bottom: 24,
            width: 610,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 32, height: 1, color: colors.sakura),
                    const SizedBox(width: 10),
                    Text(
                      '薇拉每周选刊',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.sky,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '排行中心',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 42,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  hasComparison
                      ? '榜单已刷新，箭头记录与上一次相遇时的名次变化。'
                      : '不替你决定答案，只把此刻最有回声的作品排在眼前。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                Row(
                  children: [
                    _IntroFact(
                      value: source == 'jikan' ? 'MAL' : '站内',
                      label: '榜单来源',
                    ),
                    const SizedBox(width: 28),
                    _IntroFact(
                      value: storyCount.toString().padLeft(2, '0'),
                      label: '当前入选',
                    ),
                    const SizedBox(width: 28),
                    Tooltip(
                      message: '刷新并比较名次',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: TextButton.icon(
                          onPressed: refreshing ? null : onRefresh,
                          icon: refreshing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('刷新本期'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            top: 18,
            child: RotatedBox(
              quarterTurns: 1,
              child: Text(
                '本周特别刊 · 01',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 1.7,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroFact extends StatelessWidget {
  final String value;
  final String label;

  const _IntroFact({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.colors.textPrimary,
              ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _RankingFilters extends StatelessWidget {
  final String source;
  final String scoreFilter;
  final String statusFilter;
  final String? genreFilter;
  final List<String> availableGenres;
  final bool hasActiveFilters;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onScoreChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String?> onGenreChanged;
  final VoidCallback onReset;

  const _RankingFilters({
    required this.source,
    required this.scoreFilter,
    required this.statusFilter,
    required this.genreFilter,
    required this.availableGenres,
    required this.hasActiveFilters,
    required this.onSourceChanged,
    required this.onScoreChanged,
    required this.onStatusChanged,
    required this.onGenreChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _FilterSet(
            label: '榜源',
            value: source,
            options: const {'jikan': 'MAL 总榜', 'cms': '站内热榜'},
            onChanged: onSourceChanged,
          ),
          _FilterSet(
            label: '评分',
            value: scoreFilter,
            options: const {'all': '全部', '8.0': '8.0+', '8.5': '8.5+'},
            onChanged: onScoreChanged,
          ),
          _FilterSet(
            label: '状态',
            value: statusFilter,
            options: const {
              'all': '全部',
              'airing': '连载中',
              'finished': '已完结',
            },
            onChanged: onStatusChanged,
          ),
          _GenreSelect(
            value: genreFilter,
            genres: availableGenres,
            onChanged: onGenreChanged,
          ),
          if (hasActiveFilters)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('清除筛选'),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterSet extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const _FilterSet({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textMuted,
              ),
        ),
        const SizedBox(width: 6),
        for (final entry in options.entries)
          _FilterTextButton(
            label: entry.value,
            selected: entry.key == value,
            onTap: () => onChanged(entry.key),
          ),
      ],
    );
  }
}

class _FilterTextButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTextButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterTextButton> createState() => _FilterTextButtonState();
}

class _FilterTextButtonState extends State<_FilterTextButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: widget.selected
                  ? colors.skyLight
                  : _hovered
                      ? colors.bgHover
                      : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: widget.selected ? colors.sky : Colors.transparent,
                  width: 1.5,
                ),
              ),
            ),
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: widget.selected || _hovered
                        ? colors.sky
                        : colors.textSecondary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenreSelect extends StatelessWidget {
  final String? value;
  final List<String> genres;
  final ValueChanged<String?> onChanged;

  const _GenreSelect({
    required this.value,
    required this.genres,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: context.colors.bgSurface,
          border: Border.all(color: context.colors.divider),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: value,
            hint: const Text('全部类型'),
            borderRadius: BorderRadius.circular(6),
            dropdownColor: context.colors.paper,
            style: Theme.of(context).textTheme.labelSmall,
            icon: const Icon(Icons.expand_more_rounded, size: 16),
            onChanged: onChanged,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('全部类型'),
              ),
              for (final genre in genres)
                DropdownMenuItem<String?>(
                  value: genre,
                  child: Text(genre),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopThreeLayout extends StatelessWidget {
  final List<RankingStory> stories;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _TopThreeLayout({
    super.key,
    required this.stories,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960 || stories.length == 1) {
          return SizedBox(
            height: 320,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final story = stories[index];
                return SizedBox(
                  width: index == 0 ? 410 : 300,
                  child: _PodiumStoryCard(
                    story: story,
                    onTap: () => onOpen(story.item),
                  ),
                );
              },
            ),
          );
        }

        return SizedBox(
          height: 370,
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: _PodiumStoryCard(
                  story: stories.first,
                  onTap: () => onOpen(stories.first.item),
                ),
              ),
              if (stories.length > 1) ...[
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Expanded(
                        child: _PodiumStoryCard(
                          story: stories[1],
                          compact: true,
                          onTap: () => onOpen(stories[1].item),
                        ),
                      ),
                      if (stories.length > 2) ...[
                        const SizedBox(height: 14),
                        Expanded(
                          child: _PodiumStoryCard(
                            story: stories[2],
                            compact: true,
                            onTap: () => onOpen(stories[2].item),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PodiumStoryCard extends StatefulWidget {
  final RankingStory story;
  final VoidCallback onTap;
  final bool compact;

  const _PodiumStoryCard({
    required this.story,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_PodiumStoryCard> createState() => _PodiumStoryCardState();
}

class _PodiumStoryCardState extends State<_PodiumStoryCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = widget.story.item['name']?.toString() ?? '未命名作品';

    return Semantics(
      button: true,
      label: '第${widget.story.rank}名，$name',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.paper,
              border: Border.all(
                color: _hovered
                    ? colors.sky.withValues(alpha: 0.58)
                    : colors.divider,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: colors.textPrimary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 9),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverImage(
                  url: widget.story.item['cover']?.toString(),
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.82),
                      ],
                      stops: const [0.38, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: widget.compact ? 14 : 18,
                  top: widget.compact ? 12 : 16,
                  child: Container(
                    width: widget.compact ? 36 : 46,
                    height: widget.compact ? 36 : 46,
                    alignment: Alignment.center,
                    color: colors.paper.withValues(alpha: 0.94),
                    child: Text(
                      widget.story.rank.toString().padLeft(2, '0'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: widget.story.rank == 1
                                ? colors.warning
                                : colors.sky,
                          ),
                    ),
                  ),
                ),
                Positioned(
                  left: widget.compact ? 14 : 20,
                  right: widget.compact ? 14 : 20,
                  bottom: widget.compact ? 13 : 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.story.score != null)
                        Text(
                          '评分 ${widget.story.score!.toStringAsFixed(1)}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.sakuraLight,
                                  ),
                        ),
                      const SizedBox(height: 5),
                      Text(
                        name,
                        maxLines: widget.compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontSize: widget.compact ? 15 : 20,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final List<RankingStory> stories;
  final bool hasActiveFilters;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback onReset;

  const _RankingList({
    super.key,
    required this.stories,
    required this.hasActiveFilters,
    required this.onOpen,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return ViraStateView.empty(
        title: hasActiveFilters ? '没有符合条件的作品' : '完整榜单正在整理',
        message: hasActiveFilters ? '放宽评分、状态或类型条件再看看。' : '稍后刷新，新的作品会出现在这里。',
        actionLabel: hasActiveFilters ? '清除筛选' : null,
        onAction: hasActiveFilters ? onReset : null,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < stories.length; index++)
            _RankingRow(
              story: stories[index],
              showDivider: index != stories.length - 1,
              onTap: () => onOpen(stories[index].item),
            ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatefulWidget {
  final RankingStory story;
  final bool showDivider;
  final VoidCallback onTap;

  const _RankingRow({
    required this.story,
    required this.showDivider,
    required this.onTap,
  });

  @override
  State<_RankingRow> createState() => _RankingRowState();
}

class _RankingRowState extends State<_RankingRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = widget.story.item['name']?.toString() ?? '未命名作品';
    final status = widget.story.item['status']?.toString() ?? '';

    return Semantics(
      button: true,
      label: '第${widget.story.rank}名，$name',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 102,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: _hovered ? colors.bgHover : Colors.transparent,
              border: widget.showDivider
                  ? Border(bottom: BorderSide(color: colors.divider))
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    widget.story.rank.toString().padLeft(2, '0'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: widget.story.rank <= 3
                              ? colors.sky
                              : colors.textMuted,
                        ),
                  ),
                ),
                SizedBox(
                  width: 58,
                  height: 78,
                  child: CoverImage(
                    url: widget.story.item['cover']?.toString(),
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.story.genres.isEmpty
                            ? status
                            : widget.story.genres.take(3).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 74,
                  child: widget.story.score == null
                      ? const SizedBox.shrink()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: colors.warning,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.story.score!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ],
                        ),
                ),
                SizedBox(
                  width: 68,
                  child: _TrendLabel(delta: widget.story.delta),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: _hovered ? colors.sky : colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendLabel extends StatelessWidget {
  final int? delta;

  const _TrendLabel({this.delta});

  @override
  Widget build(BuildContext context) {
    if (delta == null) {
      return Text(
        '新',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colors.sakura,
            ),
      );
    }
    if (delta == 0) {
      return Text(
        '持平',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      );
    }
    final rising = delta! > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          rising ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 13,
          color: rising ? context.colors.success : context.colors.danger,
        ),
        Text(
          delta!.abs().toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: rising ? context.colors.success : context.colors.danger,
              ),
        ),
      ],
    );
  }
}
