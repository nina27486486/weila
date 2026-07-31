part of '../detail_page.dart';

extension _DetailPageView on _DetailPageState {
  Future<void> _playFromCms(int episodeIndex) async {
    try {
      // 加载 CMS 集数
      final cmsAnime = Anime(
        name: _animeName,
        url: _cmsAnimeUrl!,
        sourcePlugin: _cmsAnimeUrl!.split(':').first,
      );
      final episodes = await _pluginService.getEpisodes(cmsAnime);

      if (episodes.isEmpty) {
        if (mounted) {
          ErrorHandler.showInfo(context, '未找到集数信息');
        }
        return;
      }

      // 找到对应集数（或第一集）
      final epIndex = episodeIndex < episodes.length ? episodeIndex : 0;
      final ep = episodes[epIndex];
      final playbackEpisode = await _pluginService.resolvePlaybackEpisode(
        anime: cmsAnime,
        episode: ep,
      );
      final resolved =
          const PlaybackSelection.auto().resolve(playbackEpisode.sources);
      if (resolved == null) {
        if (mounted) {
          ErrorHandler.showInfo(context, '当前集数没有可用播放线路');
        }
        return;
      }

      if (mounted) {
        final detail = _store.currentDetail;
        final animeName = detail?['name']?.toString().trim();
        final coverUrl = detail?['cover']?.toString() ?? _anime.cover ?? '';
        Modular.to.pushNamed(
          '/player?url=${Uri.encodeComponent(resolved.variant.url)}'
          '&title=${Uri.encodeComponent(ep.name)}'
          '&animeUrl=${Uri.encodeComponent(_libraryAnimeUrl)}'
          '&animeName=${Uri.encodeComponent(
            animeName?.isNotEmpty == true ? animeName! : _animeName,
          )}'
          '&cover=${Uri.encodeComponent(coverUrl)}'
          '&ep=$epIndex'
          '&source=${Uri.encodeComponent(_cmsAnimeUrl!.split(':').first)}'
          '${widget.contentId?.isNotEmpty == true ? '&contentId=${Uri.encodeComponent(widget.contentId!)}' : ''}',
        );
      }
    } catch (e) {
      Log.d(
        'Detail',
        safePlaybackLogMessage(
          PlaybackLogOperation.detailResolveFailed,
          classifyPlaybackFailure(e.toString()),
        ),
      );
      if (mounted) {
        ErrorHandler.showError(context, '播放失败，请稍后重试或更换片源');
      }
    }
  }

  Widget _buildDetailView() {
    return ViraPageScaffold(
      activeDestination: null,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: Observer(
        builder: (_) {
          final detail = _store.currentDetail;
          final coverUrl =
              detail?['cover'] ?? _anime.cover ?? _catalogContent?.coverUrl;
          final name = detail?['name'] ?? _animeName;
          final nameJa =
              detail?['name_ja'] ?? _catalogContent?.titles.original ?? '';
          final summary = _cleanDisplayText(
            detail?['summary'] ?? _catalogContent?.synopsis,
          );
          final rating = detail?['rating'] ?? _bestCatalogScore();
          final ratingCount = detail?['rating_count'];
          final rank = detail?['rank'];
          final tags = (detail?['tags'] as List?)?.cast<String>() ??
              _catalogContent?.genres.toList(growable: false) ??
              [];
          final date =
              detail?['date'] ?? _catalogContent?.year?.toString() ?? '';
          final platform =
              detail?['platform'] ?? _catalogContent?.format.name ?? '';
          final totalEps = detail?['total_episodes'];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeroPanel(
                        coverUrl: coverUrl?.toString(),
                        name: name.toString(),
                        nameJa: nameJa.toString(),
                        summary: summary.toString(),
                        rating: rating is num ? rating.toDouble() : null,
                        ratingCount: ratingCount,
                        rank: rank,
                        tags: tags,
                        date: date.toString(),
                        platform: platform.toString(),
                        totalEps: totalEps,
                        status: detail?['status']?.toString(),
                      ),
                      if (summary.toString().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _buildSummaryCard(summary.toString()),
                      ],
                      const SizedBox(height: 26),
                      _buildEpisodeToolbar(),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              _buildEpisodeSliver(),
              SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
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

  Widget _buildHeroPanel({
    required String? coverUrl,
    required String name,
    required String nameJa,
    required String summary,
    required double? rating,
    required dynamic ratingCount,
    required dynamic rank,
    required List<String> tags,
    required String date,
    required String platform,
    required dynamic totalEps,
    required String? status,
  }) {
    final totalEpisodeCount = totalEps is int
        ? totalEps
        : int.tryParse(totalEps?.toString() ?? '') ?? 0;

    Widget buildPanel(ArtworkPalette palette) {
      return Container(
        key: const ValueKey('detail-ambient-hero'),
        height: 410,
        decoration: BoxDecoration(
          color: context.colors.bgCard,
          border: Border(
            top: BorderSide(color: context.colors.divider),
            bottom: BorderSide(color: context.colors.divider),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AmbientArtworkBackdrop(
              palette: palette,
              child: const SizedBox.expand(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.82),
                    context.colors.bgCard.withValues(alpha: 0.58),
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  stops: const [0, 0.58, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Hero(
                    tag: 'anime-cover-$_libraryAnimeUrl',
                    child: ArtworkParallax(
                      child: _DetailPoster(coverUrl: coverUrl),
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (date.isNotEmpty)
                              _InfoPill(
                                  icon: Icons.calendar_today_outlined,
                                  text: date),
                            if (platform.isNotEmpty)
                              _InfoPill(
                                  icon: Icons.tv_outlined, text: platform),
                            if (totalEpisodeCount > 0)
                              _InfoPill(
                                  icon: Icons.video_library_outlined,
                                  text: '$totalEpisodeCount集'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.08,
                            shadows: [
                              Shadow(blurRadius: 12, color: Colors.black87)
                            ],
                          ),
                        ),
                        if (nameJa.isNotEmpty && nameJa != name) ...[
                          const SizedBox(height: 8),
                          Text(
                            nameJa,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ],
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (rating != null) _buildScoreBadge(rating),
                            if (ratingCount != null)
                              _InfoPill(
                                  icon: Icons.people_alt_outlined,
                                  text: '${ratingCount.toString()}人评分'),
                            if (rank != null)
                              _InfoPill(
                                  icon: Icons.emoji_events_outlined,
                                  text: '排名 $rank',
                                  highlighted: true),
                            _buildSourceIndicator(),
                          ],
                        ),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: tags
                                .take(5)
                                .map((tag) => _DetailTag(text: tag))
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            _HeroActionButton(
                              icon: Icons.play_arrow_rounded,
                              label: _store.currentEpisodes.isEmpty
                                  ? '等待片源'
                                  : '立即播放',
                              onTap: _store.currentEpisodes.isEmpty
                                  ? null
                                  : () => _onEpisodeTap(0),
                            ),
                            const SizedBox(width: 10),
                            _HeroIconButton(
                              icon: _tracked
                                  ? Icons.calendar_month
                                  : Icons.calendar_month_outlined,
                              active: _tracked,
                              tooltip: _tracked ? '已追番' : '追番',
                              onTap: () => _toggleTrack(
                                name: name,
                                coverUrl: coverUrl,
                                status: status,
                                totalEpisodes: totalEpisodeCount,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _HeroIconButton(
                              icon: _collected
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              active: _collected,
                              tooltip: _collected ? '已收藏' : '收藏',
                              onTap: () => _toggleCollect(
                                name: name,
                                coverUrl: coverUrl,
                                summary: summary,
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
          ],
        ),
      );
    }

    final provider = CoverImage.providerFor(coverUrl);
    if (provider == null) return buildPanel(ArtworkPalette.fallback);
    return ArtworkPaletteBuilder(
      cacheKey: coverUrl!,
      provider: provider,
      builder: (_, palette) => buildPanel(palette),
    );
  }

  Widget _buildSummaryCard(String summary) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _updateDetailState(() => _descExpanded = !_descExpanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.bgCard,
            border: Border(
              top: BorderSide(color: context.colors.divider),
              bottom: BorderSide(color: context.colors.divider),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.notes_rounded,
                      color: AppTheme.primaryBlue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '作品简介',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                summary,
                maxLines: _descExpanded ? null : 4,
                overflow: _descExpanded ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
              if (summary.length > 120)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _descExpanded ? '收起简介' : '展开全部',
                    style: const TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeToolbar() {
    return Row(
      children: [
        Text(
          '选集',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_store.currentEpisodes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${_store.currentEpisodes.length}集',
              style: TextStyle(color: context.colors.textMuted, fontSize: 12),
            ),
          ),
        const Spacer(),
        _ViewToggleButton(
          icon: Icons.grid_view_rounded,
          selected: _episodeGridView,
          tooltip: '网格视图',
          onTap: () => _updateDetailState(() => _episodeGridView = true),
        ),
        const SizedBox(width: 6),
        _ViewToggleButton(
          icon: Icons.view_agenda_outlined,
          selected: !_episodeGridView,
          tooltip: '列表视图',
          onTap: () => _updateDetailState(() => _episodeGridView = false),
        ),
      ],
    );
  }

  Widget _buildEpisodeSliver() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: Observer(
        builder: (_) {
          if (_store.isLoadingEpisodes) {
            return SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, __) => const _EpisodeSkeleton(),
                childCount: 10,
              ),
            );
          }

          if (_store.currentEpisodes.isEmpty) {
            return SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(42),
                decoration: BoxDecoration(
                  color: context.colors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.divider),
                ),
                child: Column(
                  children: [
                    Icon(Icons.video_library_outlined,
                        size: 48, color: context.colors.textMuted),
                    const SizedBox(height: 12),
                    Text('暂无章节信息',
                        style: TextStyle(color: context.colors.textSecondary)),
                  ],
                ),
              ),
            );
          }

          if (!_episodeGridView) {
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) return const SizedBox(height: 8);
                  final episodeIndex = index ~/ 2;
                  final ep = _store.currentEpisodes[episodeIndex];
                  return FadeSlideIn(
                    delay: Duration(
                      milliseconds: episodeIndex.clamp(0, 10) * 35,
                    ),
                    child: _EpisodeListTile(
                      episode: ep,
                      index: episodeIndex,
                      onTap: () => _onEpisodeTap(episodeIndex),
                    ),
                  );
                },
                childCount: _store.currentEpisodes.length * 2 - 1,
              ),
            );
          }

          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.15,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ep = _store.currentEpisodes[index];
                return FadeSlideIn(
                  delay: Duration(milliseconds: index.clamp(0, 10) * 35),
                  child: _EpisodeChip(
                    episode: ep,
                    onTap: () => _onEpisodeTap(index),
                  ),
                );
              },
              childCount: _store.currentEpisodes.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSourceIndicator() {
    // CMS 直接来源
    if (_anime.sourcePlugin.startsWith('cms_')) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.scoreGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: AppTheme.scoreGreen),
            SizedBox(width: 4),
            Text(
              '视频源: ${_anime.sourcePlugin.replaceAll("cms_", "")}',
              style: TextStyle(color: AppTheme.scoreGreen, fontSize: 11),
            ),
          ],
        ),
      );
    }
    // Jikan/Anilist/Bangumi 找到了 CMS 视频源
    if (_cmsAnimeUrl != null && _cmsSourceName != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.scoreGreen.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: AppTheme.scoreGreen),
            SizedBox(width: 4),
            Text(
              '视频源: $_cmsSourceName',
              style: TextStyle(color: AppTheme.scoreGreen, fontSize: 11),
            ),
          ],
        ),
      );
    }
    // 正在搜索视频源
    if (_searchingSource) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.scoreOrange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppTheme.scoreOrange,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '搜索视频源中...',
              style: TextStyle(color: AppTheme.scoreOrange, fontSize: 11),
            ),
          ],
        ),
      );
    }
    // 未找到视频源 → 显示警告 + 手动搜索按钮
    if (_anime.sourcePlugin == 'jikan' ||
        _anime.sourcePlugin == 'anilist' ||
        _anime.sourcePlugin == 'bangumi') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.scoreRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 14, color: AppTheme.scoreRed),
                SizedBox(width: 4),
                Text(
                  '暂无视频源',
                  style: TextStyle(color: AppTheme.scoreRed, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _manualSearchSource,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 14, color: AppTheme.primaryBlue),
                    SizedBox(width: 4),
                    Text(
                      '手动搜索',
                      style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildScoreBadge(double score) {
    Color color;
    String label;
    if (score >= 8.0) {
      color = AppTheme.scoreGreen;
      label = '极好';
    } else if (score >= 7.0) {
      color = AppTheme.scoreOrange;
      label = '不错';
    } else {
      color = AppTheme.scoreRed;
      label = '还行';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: (score / 10).clamp(0.0, 1.0),
              color: color,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(label,
                  style: TextStyle(color: color, fontSize: 10, height: 1.2)),
            ],
          ),
        ],
      ),
    );
  }
}
