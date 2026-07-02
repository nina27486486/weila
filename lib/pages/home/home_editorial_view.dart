import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/artwork_palette_service.dart';
import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';
import '../../widgets/artwork_components.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/editorial_section_header.dart';
import '../../widgets/vira_state_view.dart';

@immutable
class HomeContinueStory {
  final String title;
  final String? coverUrl;
  final String progressLabel;
  final String updatedLabel;
  final String animeUrl;

  const HomeContinueStory({
    required this.title,
    required this.coverUrl,
    required this.progressLabel,
    required this.updatedLabel,
    required this.animeUrl,
  });
}

class HomeEditorialView extends StatelessWidget {
  final List<Map<String, dynamic>> latestItems;
  final List<Map<String, dynamic>> seasonalItems;
  final List<Map<String, dynamic>> trendingItems;
  final List<HomeContinueStory> continueStories;
  final bool isLoading;
  final bool isSeasonalLoading;
  final bool isTrendingLoading;
  final String? errorMessage;
  final ValueChanged<Map<String, dynamic>> onOpenAnime;
  final ValueChanged<HomeContinueStory> onOpenContinue;
  final VoidCallback onRetry;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenRanking;

  const HomeEditorialView({
    super.key,
    required this.latestItems,
    required this.seasonalItems,
    required this.trendingItems,
    required this.continueStories,
    required this.onOpenAnime,
    required this.onOpenContinue,
    required this.onRetry,
    this.isLoading = false,
    this.isSeasonalLoading = false,
    this.isTrendingLoading = false,
    this.errorMessage,
    this.onOpenHistory,
    this.onOpenCalendar,
    this.onOpenRanking,
  });

  bool get _hasAnime =>
      latestItems.isNotEmpty ||
      seasonalItems.isNotEmpty ||
      trendingItems.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasAnime && errorMessage != null && !isLoading) {
      return ViraStateView.error(
        title: '今天的放映单还没送达',
        message: errorMessage!,
        onRetry: onRetry,
      );
    }

    if (!_hasAnime && isLoading) {
      return const _HomeLoadingView();
    }

    final heroItems = (trendingItems.isNotEmpty
            ? trendingItems
            : latestItems.isNotEmpty
                ? latestItems
                : seasonalItems)
        .take(4)
        .toList(growable: false);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 18, bottom: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiaryStrip(
            key: const ValueKey('home-diary-strip'),
            followingCount: continueStories.length,
          ),
          const SizedBox(height: 16),
          _EditorialHero(
            key: const ValueKey('home-editorial-hero'),
            items: heroItems,
            onOpen: onOpenAnime,
          ),
          const SizedBox(height: 48),
          _ContinueSection(
            key: const ValueKey('home-continue'),
            stories: continueStories,
            onOpen: onOpenContinue,
            onOpenAll: onOpenHistory,
          ),
          const SizedBox(height: 50),
          _TodaySection(
            key: const ValueKey('home-today'),
            items: latestItems,
            onOpen: onOpenAnime,
            onOpenAll: onOpenCalendar,
          ),
          const SizedBox(height: 50),
          _SeasonSection(
            key: const ValueKey('home-seasonal'),
            items: seasonalItems,
            isLoading: isSeasonalLoading,
            onOpen: onOpenAnime,
          ),
          const SizedBox(height: 50),
          _RankingSection(
            key: const ValueKey('home-ranking'),
            items: trendingItems,
            isLoading: isTrendingLoading,
            onOpen: onOpenAnime,
            onOpenAll: onOpenRanking,
          ),
        ],
      ),
    );
  }
}

class _DiaryStrip extends StatelessWidget {
  final int followingCount;

  const _DiaryStrip({super.key, required this.followingCount});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final now = DateTime.now();
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider),
          bottom: BorderSide(color: colors.divider),
        ),
      ),
      child: Row(
        children: [
          Container(width: 28, height: 1, color: colors.sakura),
          const SizedBox(width: 10),
          Text(
            '${now.month}月${now.day}日 · ${weekdays[now.weekday - 1]}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4,
                ),
          ),
          const Spacer(),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: colors.sky,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            followingCount == 0
                ? '今晚，挑一部喜欢的动画吧'
                : '今晚有 $followingCount 部故事等你继续',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

class _EditorialHero extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _EditorialHero({
    super.key,
    required this.items,
    required this.onOpen,
  });

  @override
  State<_EditorialHero> createState() => _EditorialHeroState();
}

class _EditorialHeroState extends State<_EditorialHero>
    with WidgetsBindingObserver {
  static const _autoPlayInterval = Duration(seconds: 6);

  Timer? _autoPlayTimer;
  int _selectedIndex = 0;
  bool _tickerEnabled = true;
  bool _disableAnimations = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  Map<String, dynamic>? get _selectedItem =>
      widget.items.isEmpty ? null : widget.items[_selectedIndex];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncAutoPlay();
  }

  @override
  void didUpdateWidget(covariant _EditorialHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousItem = oldWidget.items.isEmpty
        ? null
        : oldWidget.items[_selectedIndex.clamp(0, oldWidget.items.length - 1)];
    final previousId = _itemIdentity(previousItem);
    final matchingIndex = widget.items.indexWhere(
      (item) => _itemIdentity(item) == previousId,
    );
    _selectedIndex = matchingIndex >= 0 ? matchingIndex : 0;
    _syncAutoPlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncAutoPlay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _syncAutoPlay() {
    _autoPlayTimer?.cancel();
    if (!mounted ||
        widget.items.length <= 1 ||
        !_tickerEnabled ||
        _disableAnimations ||
        _lifecycle != AppLifecycleState.resumed) {
      return;
    }
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (_) {
      if (!mounted || widget.items.length <= 1) return;
      _selectItem((_selectedIndex + 1) % widget.items.length, restart: false);
    });
  }

  void _selectItem(int index, {bool restart = true}) {
    if (index < 0 || index >= widget.items.length || index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
    if (restart) _syncAutoPlay();
  }

  void _openSelected() {
    final item = _selectedItem;
    if (item != null) widget.onOpen(item);
  }

  String _itemIdentity(Map<String, dynamic>? item) {
    if (item == null) return '';
    return (item['url'] ?? item['id'] ?? item['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final item = _selectedItem;
    final itemCount = widget.items.length;

    Widget buildHero(ArtworkPalette palette) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 1040;
          final image = _HeroImage(
            item: item,
            selectedIndex: _selectedIndex,
            itemCount: itemCount,
            onOpen: item == null ? null : _openSelected,
          );
          final copy = _HeroCopy(
            item: item,
            selectedIndex: _selectedIndex,
            itemCount: itemCount,
            onSelect: _selectItem,
            onOpen: item == null ? null : _openSelected,
          );
          final content = horizontal
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 13, child: image),
                    const SizedBox(width: 22),
                    Expanded(flex: 7, child: copy),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: image),
                    Expanded(child: copy),
                  ],
                );

          return SizedBox(
            key: const ValueKey('home-ambient-hero'),
            height: horizontal ? 390 : 660,
            child: AmbientArtworkBackdrop(
              palette: palette,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AnimatedSwitcher(
                  duration:
                      _disableAnimations ? Duration.zero : AppAnimations.normal,
                  switchInCurve: AppAnimations.easeOut,
                  switchOutCurve: AppAnimations.easeIn,
                  child: KeyedSubtree(
                    key: ValueKey(_itemIdentity(item)),
                    child: content,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    final coverUrl = item?['cover']?.toString();
    final provider = CoverImage.providerFor(coverUrl);
    if (provider == null) return buildHero(ArtworkPalette.fallback);
    return ArtworkPaletteBuilder(
      cacheKey: coverUrl!,
      provider: provider,
      builder: (_, palette) => buildHero(palette),
    );
  }
}

class _HeroImage extends StatefulWidget {
  final Map<String, dynamic>? item;
  final int selectedIndex;
  final int itemCount;
  final VoidCallback? onOpen;

  const _HeroImage({
    required this.item,
    required this.selectedIndex,
    required this.itemCount,
    this.onOpen,
  });

  @override
  State<_HeroImage> createState() => _HeroImageState();
}

class _HeroImageState extends State<_HeroImage> {
  Offset _tilt = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0008)
          ..rotateX(-_tilt.dy * 0.035)
          ..rotateY(_tilt.dx * 0.035);
        return MouseRegion(
          onHover: (event) {
            if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
            if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;
            setState(() {
              _tilt = Offset(
                (event.localPosition.dx / constraints.maxWidth - 0.5) * 2,
                (event.localPosition.dy / constraints.maxHeight - 0.5) * 2,
              );
            });
          },
          onExit: (_) => setState(() => _tilt = Offset.zero),
          child: AnimatedContainer(
            duration: AppAnimations.normal,
            curve: AppAnimations.easeOut,
            transform: transform,
            transformAlignment: Alignment.center,
            child: _HoverSurface(
              onTap: widget.onOpen,
              lift: 2,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CoverImage(
                    url: widget.item?['cover']?.toString(),
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.04),
                          Colors.black.withValues(alpha: 0.58),
                        ],
                        stops: const [0.48, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 18,
                    left: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      color: colors.paper.withValues(alpha: 0.92),
                      child: Text(
                        '本周主映',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.sky,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Row(
                      children: [
                        Text(
                          '镜头 ${_twoDigits(widget.selectedIndex + 1)} / '
                          '${_twoDigits(widget.itemCount)}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    letterSpacing: 1.1,
                                  ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.open_in_full_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final Map<String, dynamic>? item;
  final int selectedIndex;
  final int itemCount;
  final ValueChanged<int> onSelect;
  final VoidCallback? onOpen;

  const _HeroCopy({
    required this.item,
    required this.selectedIndex,
    required this.itemCount,
    required this.onSelect,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = _nameOf(item);
    final status = _statusOf(item);
    final genres = _genresOf(item);

    return Container(
      padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
      decoration: BoxDecoration(
        color: colors.paper,
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今日放映 · 奇幻冒险',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.sky,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 22),
          Text(
            item == null ? '今天，挑一段喜欢的故事。' : '今天，继续\n$title。',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 34,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            status.isEmpty ? '让画面替忙碌的一天留下一点余白。' : status,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (genres.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              genres.take(3).join(' · '),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                  ),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('立即播放'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onOpen,
                child: const Text('查看详情'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var index = 0; index < itemCount; index++) ...[
                Tooltip(
                  message: '切换到第 ${index + 1} 部主映',
                  child: InkWell(
                    key: ValueKey('home-hero-selector-$index'),
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => onSelect(index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Text(
                        _twoDigits(index + 1),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: index == selectedIndex
                                  ? colors.textPrimary
                                  : colors.textMuted,
                              fontWeight: index == selectedIndex
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                  ),
                ),
                if (index != itemCount - 1) const SizedBox(width: 10),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 42,
                    height: 1,
                    color: colors.sky,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContinueSection extends StatelessWidget {
  final List<HomeContinueStory> stories;
  final ValueChanged<HomeContinueStory> onOpen;
  final VoidCallback? onOpenAll;

  const _ContinueSection({
    super.key,
    required this.stories,
    required this.onOpen,
    this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialSectionHeader(
          chapter: '镜头 02',
          title: '接着上次的故事',
          subtitle: '不催促，只替你记住停下的位置',
          actionLabel: '全部记录',
          onAction: onOpenAll,
        ),
        const SizedBox(height: 18),
        if (stories.isEmpty)
          const _QuietEmpty(
            icon: Icons.history_toggle_off_rounded,
            message: '还没有续看记录，开始一段新故事吧。',
          )
        else
          LayeredArtworkStack(
            items: [
              for (final story in stories)
                ArtworkStackItem(
                  id: story.animeUrl,
                  title: story.title,
                  subtitle: '${story.progressLabel} · ${story.updatedLabel}',
                  imageUrl: story.coverUrl,
                  progress: 0.58,
                ),
            ],
            onOpen: (item) {
              final index =
                  stories.indexWhere((story) => story.animeUrl == item.id);
              if (index >= 0) onOpen(stories[index]);
            },
          ),
      ],
    );
  }
}

class _TodaySection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback? onOpenAll;

  const _TodaySection({
    super.key,
    required this.items,
    required this.onOpen,
    this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    final visible = items.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialSectionHeader(
          chapter: '今日编排',
          title: '今日放送',
          subtitle: '按更新时间排好，想看时直接抵达',
          actionLabel: '查看日历',
          onAction: onOpenAll,
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty)
          const _QuietEmpty(
            icon: Icons.calendar_today_outlined,
            message: '今天暂时没有新的放送安排。',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1040 || visible.length == 1) {
                return SizedBox(
                  height: 260,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return SizedBox(
                        width: 286,
                        child: _AiringCard(
                          item: item,
                          cardId: 'today-$index',
                          cardIndex: index,
                          featured: index == 0,
                          onOpen: () => onOpen(item),
                        ),
                      );
                    },
                  ),
                );
              }

              return SizedBox(
                height: 330,
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: _AiringCard(
                        item: visible.first,
                        cardId: 'today-0',
                        cardIndex: 0,
                        featured: true,
                        onOpen: () => onOpen(visible.first),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 9,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: visible.length - 1,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.35,
                        ),
                        itemBuilder: (context, index) {
                          final item = visible[index + 1];
                          return _AiringCard(
                            item: item,
                            cardId: 'today-${index + 1}',
                            cardIndex: index + 1,
                            onOpen: () => onOpen(item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _AiringCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String cardId;
  final int cardIndex;
  final bool featured;
  final VoidCallback onOpen;

  const _AiringCard({
    required this.item,
    required this.cardId,
    required this.cardIndex,
    required this.onOpen,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = _scoreOf(item);

    return ArtworkCardSurface(
      id: cardId,
      semanticLabel: '今日放送第${cardIndex + 1}项：${_nameOf(item)}',
      onOpen: onOpen,
      contentBuilder: (context, interaction) {
        final cover = AnimatedScale(
          key: ValueKey('today-cover-scale-$cardIndex'),
          duration: interaction.duration,
          curve: Curves.easeOutCubic,
          scale: interaction.coverScale,
          child: CoverImage(
            url: item['cover']?.toString(),
            fit: BoxFit.cover,
          ),
        );

        if (featured) {
          return Stack(
            fit: StackFit.expand,
            children: [
              cover,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.76),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusOf(item),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.skyLight,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _nameOf(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(
              width: 104,
              height: double.infinity,
              child: cover,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusOf(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.sky,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _nameOf(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    if (score != null)
                      Text(
                        '评分 ${score.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SeasonSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _SeasonSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final railItems = [
      for (var index = 0; index < items.length; index++)
        PosterRailItem(
          id: '${index}_${items[index]['url'] ?? ''}',
          title: _nameOf(items[index]),
          imageUrl: items[index]['cover']?.toString(),
          meta: [
            ..._genresOf(items[index]).take(2),
            if (_scoreOf(items[index]) case final score?)
              score.toStringAsFixed(1),
          ].join(' · '),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EditorialSectionHeader(
          chapter: '季度选刊',
          title: '本季选片',
          subtitle: '不是填满页面，而是留下真正值得注意的作品',
        ),
        const SizedBox(height: 18),
        if (railItems.isEmpty)
          _QuietEmpty(
            icon: Icons.local_movies_outlined,
            message: isLoading ? '正在更新本季片单…' : '本季片单暂时没有数据。',
            busy: isLoading,
          )
        else
          PosterRail(
            items: railItems,
            onOpen: (item) {
              final index = railItems.indexOf(item);
              if (index >= 0) onOpen(items[index]);
            },
          ),
      ],
    );
  }
}

class _RankingSection extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final VoidCallback? onOpenAll;

  const _RankingSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.onOpen,
    this.onOpenAll,
  });

  @override
  Widget build(BuildContext context) {
    final visible = items.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorialSectionHeader(
          chapter: '读者风向',
          title: '本周上升榜',
          subtitle: '看看哪些故事正在被更多人发现',
          actionLabel: '完整榜单',
          onAction: onOpenAll,
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty)
          _QuietEmpty(
            icon: Icons.trending_up_rounded,
            message: isLoading ? '正在更新本周榜单…' : '本周榜单暂时没有数据。',
            busy: isLoading,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: context.colors.paper,
              border: Border(
                top: BorderSide(color: context.colors.divider),
                bottom: BorderSide(color: context.colors.divider),
              ),
            ),
            child: Row(
              children: [
                for (var index = 0; index < visible.length; index++)
                  Expanded(
                    child: _RankingEntry(
                      rank: index + 1,
                      item: visible[index],
                      onOpen: () => onOpen(visible[index]),
                      showDivider: index != visible.length - 1,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RankingEntry extends StatefulWidget {
  final int rank;
  final Map<String, dynamic> item;
  final VoidCallback onOpen;
  final bool showDivider;

  const _RankingEntry({
    required this.rank,
    required this.item,
    required this.onOpen,
    required this.showDivider,
  });

  @override
  State<_RankingEntry> createState() => _RankingEntryState();
}

class _RankingEntryState extends State<_RankingEntry> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final score = _scoreOf(widget.item);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered ? colors.bgHover : Colors.transparent,
            border: widget.showDivider
                ? Border(right: BorderSide(color: colors.divider))
                : null,
          ),
          child: Row(
            children: [
              Text(
                '${widget.rank}'.padLeft(2, '0'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: widget.rank <= 3 ? colors.sky : colors.textMuted,
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameOf(widget.item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      score == null
                          ? _statusOf(widget.item)
                          : '评分 ${score.toStringAsFixed(1)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.north_east_rounded,
                size: 15,
                color: _hovered ? colors.sky : colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double lift;

  const _HoverSurface({
    required this.child,
    this.onTap,
    this.lift = 3,
  });

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: widget.onTap != null,
      child: MouseRegion(
        cursor:
            widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _hovered ? -widget.lift : 0,
              0,
            ),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.paper,
              border: Border.all(
                color: _hovered
                    ? colors.sky.withValues(alpha: 0.55)
                    : colors.divider,
              ),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: colors.textPrimary.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _QuietEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool busy;

  const _QuietEmpty({
    required this.icon,
    required this.message,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: context.colors.sky,
              ),
            )
          else
            Icon(icon, size: 19, color: context.colors.textMuted),
          const SizedBox(width: 9),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 18, bottom: 64),
      child: Column(
        children: [
          _Skeleton(height: 34, color: context.colors.paper),
          const SizedBox(height: 16),
          const _Skeleton(height: 390),
          const SizedBox(height: 48),
          const _Skeleton(height: 48, widthFactor: 0.38),
          const SizedBox(height: 18),
          const _Skeleton(height: 186),
          const SizedBox(height: 50),
          const _Skeleton(height: 330),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  final double widthFactor;
  final Color? color;

  const _Skeleton({
    required this.height,
    this.widthFactor = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color ?? context.colors.bgSurface,
          border: Border.all(color: context.colors.divider),
        ),
      ),
    );
  }
}

String _nameOf(Map<String, dynamic>? item) {
  final value = item?['name']?.toString().trim() ?? '';
  return value.isEmpty ? '未命名作品' : value;
}

String _statusOf(Map<String, dynamic>? item) {
  return item?['status']?.toString().trim() ?? '';
}

List<String> _genresOf(Map<String, dynamic>? item) {
  final value = item?['genres'];
  if (value is! List) return const [];
  return value
      .map((entry) => entry.toString())
      .where((e) => e.isNotEmpty)
      .toList();
}

double? _scoreOf(Map<String, dynamic>? item) {
  final value = item?['score'];
  return value is num ? value.toDouble() : double.tryParse('$value');
}
