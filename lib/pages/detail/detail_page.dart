import '../../utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../theme/app_theme.dart';
import '../../stores/anime_store.dart';
import '../../stores/history_collect_store.dart';
import '../../models/anime.dart';
import '../../models/collect_item.dart';
import '../../models/track_item.dart';
import '../../services/plugin/plugin_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/cover_image.dart';

class DetailPage extends StatefulWidget {
  final String animeUrl;
  final String animeName;
  
  const DetailPage({
    super.key,
    required this.animeUrl,
    required this.animeName,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _store = AnimeStore();
  final _collectStore = HistoryCollectStore();
  final _pluginService = PluginService();
  late Anime _anime;
  bool _descExpanded = false;
  bool _collected = false;
  bool _tracked = false;

  // CMS 视频源
  String? _cmsAnimeUrl;     // CMS 可播放源的 URL（如 cms_ffzy:24840）
  String? _cmsSourceName;   // CMS 源名称（如"非凡资源"）
  bool _searchingSource = false;

  @override
  void initState() {
    super.initState();
    final sourcePlugin = widget.animeUrl.contains('anilist:')
        ? 'anilist'
        : widget.animeUrl.contains('bgm.tv')
            ? 'bangumi'
            : widget.animeUrl.contains('cms_')
                ? widget.animeUrl.split(':').first
                : 'unknown';

    _anime = Anime(
      name: widget.animeName,
      url: widget.animeUrl,
      sourcePlugin: sourcePlugin,
    );
    _store.loadEpisodes(_anime);
    _collected = _collectStore.isCollected(widget.animeUrl);
    _tracked = _collectStore.isTracked(widget.animeUrl);

    // 如果是 Anilist/Bangumi 来源，自动搜索 CMS 可播放源
    if (sourcePlugin == 'anilist' || sourcePlugin == 'bangumi') {
      _searchPlayableSource();
    }
  }

  /// 自动搜索 CMS 可播放源
  Future<void> _searchPlayableSource() async {
    setState(() => _searchingSource = true);
    try {
      final results = await _pluginService.searchAll(widget.animeName);
      // 找到第一个 CMS 来源的结果
      final cmsResult = results.where((a) => a.sourcePlugin.startsWith('cms_')).firstOrNull;
      if (cmsResult != null && mounted) {
        setState(() {
          _cmsAnimeUrl = cmsResult.url;
          _cmsSourceName = _pluginService.plugins
              .where((p) => p.api == cmsResult.sourcePlugin)
              .firstOrNull?.name ?? cmsResult.sourcePlugin;
        });
      }
    } catch (e) {
      Log.d('Detail', '搜索可播放源失败: $e');
    } finally {
      if (mounted) setState(() => _searchingSource = false);
    }
  }

  /// 点击集数时，优先使用 CMS 源
  void _onEpisodeTap(int index) {
    // CMS 来源的动漫直接用已加载的集数播放
    if (_anime.sourcePlugin.startsWith('cms_')) {
      _playFromCurrentEpisodes(index);
      return;
    }

    if (_cmsAnimeUrl != null) {
      // 有 CMS 源 → 加载 CMS 集数并跳转
      _playFromCms(index);
    } else {
      // 无 CMS 源 → 提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂无可用视频源'),
          backgroundColor: AppTheme.bgCard,
        ),
      );
    }
  }

  /// 从已加载的集数直接播放（CMS来源专用）
  void _playFromCurrentEpisodes(int index) {
    final episodes = _store.currentEpisodes;
    if (episodes.isEmpty || index >= episodes.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无集数信息'), backgroundColor: AppTheme.bgCard),
      );
      return;
    }

    final ep = episodes[index];
    Modular.to.pushNamed(
      '/player?url=${Uri.encodeComponent(ep.url)}'
      '&title=${Uri.encodeComponent(ep.name)}'
      '&animeUrl=${Uri.encodeComponent(widget.animeUrl)}'
      '&ep=$index'
      '&source=${Uri.encodeComponent(_anime.sourcePlugin)}',
    );
  }

  Future<void> _playFromCms(int episodeIndex) async {
    try {
      // 加载 CMS 集数
      final cmsAnime = Anime(
        name: widget.animeName,
        url: _cmsAnimeUrl!,
        sourcePlugin: _cmsAnimeUrl!.split(':').first,
      );
      final episodes = await _pluginService.getEpisodes(cmsAnime);
      
      if (episodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到集数信息'), backgroundColor: AppTheme.bgCard),
          );
        }
        return;
      }

      // 找到对应集数（或第一集）
      final epIndex = episodeIndex < episodes.length ? episodeIndex : 0;
      final ep = episodes[epIndex];

      if (mounted) {
        Modular.to.pushNamed(
          '/player?url=${Uri.encodeComponent(ep.url)}'
          '&title=${Uri.encodeComponent(ep.name)}'
          '&animeUrl=${Uri.encodeComponent(_cmsAnimeUrl!)}'
          '&ep=$epIndex'
          '&source=${Uri.encodeComponent(_cmsAnimeUrl!.split(':').first)}',
        );
      }
    } catch (e) {
      Log.d('Detail', 'CMS 播放失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e'), backgroundColor: AppTheme.bgCard),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Observer(
        builder: (_) {
          final detail = _store.currentDetail;
          final coverUrl = detail?['cover'] ?? _anime.cover;
          final name = detail?['name'] ?? widget.animeName;
          final nameJa = detail?['name_ja'] ?? '';
          final summary = detail?['summary'] ?? '';
          final rating = detail?['rating'];
          final ratingCount = detail?['rating_count'];
          final rank = detail?['rank'];
          final tags = (detail?['tags'] as List?)?.cast<String>() ?? [];
          final date = detail?['date'] ?? '';
          final platform = detail?['platform'] ?? '';
          final totalEps = detail?['total_episodes'];

          return CustomScrollView(
            slivers: [
              // 顶部栏
              SliverAppBar(
                backgroundColor: AppTheme.bgDark,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                  onPressed: () => Modular.to.pop(),
                ),
                title: Text(
                  name,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  // 追番按钮
                  IconButton(
                    icon: Icon(
                      _tracked ? Icons.calendar_month : Icons.calendar_month_outlined,
                      color: _tracked ? AppTheme.airing : AppTheme.textSecondary,
                    ),
                    tooltip: _tracked ? '取消追番' : '追番',
                    onPressed: () {
                      setState(() => _tracked = !_tracked);
                      if (_tracked) {
                        _collectStore.addTrack(TrackItem(
                          animeName: name,
                          animeUrl: widget.animeUrl,
                          sourcePlugin: _anime.sourcePlugin,
                          cover: coverUrl?.toString(),
                          status: detail?['status']?.toString(),
                          totalEpisodes: totalEps as int? ?? 0,
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已追番'), backgroundColor: AppTheme.airing),
                        );
                      } else {
                        _collectStore.removeTrack(widget.animeUrl);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已取消追番'), backgroundColor: AppTheme.bgCard),
                        );
                      }
                    },
                  ),
                  // 收藏按钮
                  IconButton(
                    icon: Icon(
                      _collected ? Icons.bookmark : Icons.bookmark_border,
                      color: _collected ? AppTheme.primaryBlue : AppTheme.textSecondary,
                    ),
                    tooltip: _collected ? '取消收藏' : '收藏',
                    onPressed: () {
                      setState(() => _collected = !_collected);
                      if (_collected) {
                        _collectStore.addCollect(CollectItem(
                          animeName: name,
                          animeUrl: widget.animeUrl,
                          sourcePlugin: _anime.sourcePlugin,
                          cover: coverUrl?.toString(),
                          description: summary.toString(),
                        ));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已收藏'), backgroundColor: AppTheme.primaryBlue),
                        );
                      } else {
                        _collectStore.removeCollect(widget.animeUrl);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已取消收藏'), backgroundColor: AppTheme.bgCard),
                        );
                      }
                    },
                  ),
                ],
              ),
              
              // 详情内容
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 封面 + 基本信息
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 封面
                          Container(
                            width: 160,
                            height: 220,
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: AppUtils.fixCoverUrl(coverUrl?.toString()) != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CoverImage(
                                      url: coverUrl?.toString(),
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.movie_outlined, size: 48, color: AppTheme.textMuted),
                                  ),
                          ),
                          const SizedBox(width: 20),
                          // 信息区
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (nameJa.isNotEmpty && nameJa != name)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      nameJa,
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                    ),
                                  ),
                                
                                const SizedBox(height: 12),
                                
                                // 评分 + 排名
                                if (rating != null)
                                  Row(
                                    children: [
                                      _buildScoreBadge(rating.toDouble()),
                                      if (ratingCount != null) ...[
                                        const SizedBox(width: 10),
                                        Text(
                                          '${ratingCount}人评分',
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                        ),
                                      ],
                                      if (rank != null) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.tagHighlight.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            '排名 $rank',
                                            style: const TextStyle(color: AppTheme.tagHighlight, fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                
                                const SizedBox(height: 12),
                                
                                // 标签
                                if (tags.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: tags.map((tag) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.tagBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tag,
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                      ),
                                    )).toList(),
                                  ),
                                
                                const SizedBox(height: 12),
                                
                                // 元信息
                                if (date.isNotEmpty)
                                  _buildMetaRow(Icons.calendar_today_outlined, '首播: $date'),
                                if (platform.isNotEmpty)
                                  _buildMetaRow(Icons.tv_outlined, '平台: $platform'),
                                if (totalEps != null && totalEps > 0)
                                  _buildMetaRow(Icons.video_library_outlined, '集数: $totalEps集'),
                                
                                const SizedBox(height: 12),
                                
                                // 视频源状态
                                _buildSourceIndicator(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // 简介
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => setState(() => _descExpanded = !_descExpanded),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.bgCard,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '简介',
                                  style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  summary.toString(),
                                  maxLines: _descExpanded ? null : 3,
                                  overflow: _descExpanded ? null : TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                                if (summary.toString().length > 80)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _descExpanded ? '收起' : '展开全部',
                                      style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // 选集标题
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            '选集',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_store.currentEpisodes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '${_store.currentEpisodes.length}集',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              
              // 集数列表
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: Observer(
                  builder: (_) {
                    if (_store.isLoadingEpisodes) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
                        ),
                      );
                    }

                    if (_store.currentEpisodes.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.video_library_outlined, size: 48, color: AppTheme.textMuted),
                                SizedBox(height: 12),
                                Text('暂无章节信息', style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 3.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ep = _store.currentEpisodes[index];
                          return _EpisodeChip(
                            episode: ep,
                            onTap: () => _onEpisodeTap(index),
                          );
                        },
                        childCount: _store.currentEpisodes.length,
                      ),
                    );
                  },
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSourceIndicator() {
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
            const Icon(Icons.check_circle, size: 14, color: AppTheme.scoreGreen),
            const SizedBox(width: 4),
            Text(
              '视频源: ${_anime.sourcePlugin.replaceAll("cms_", "")}',
              style: const TextStyle(color: AppTheme.scoreGreen, fontSize: 11),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildScoreBadge(double score) {
    Color color;
    String label;
    if (score >= 8.0) { color = AppTheme.scoreGreen; label = '极好'; }
    else if (score >= 7.0) { color = AppTheme.scoreOrange; label = '不错'; }
    else { color = AppTheme.scoreRed; label = '还行'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(score.toStringAsFixed(1), style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ]),
    );
  }

  Widget _buildMetaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ]),
    );
  }
}

class _EpisodeChip extends StatefulWidget {
  final Episode episode;
  final VoidCallback onTap;
  const _EpisodeChip({required this.episode, required this.onTap});
  @override
  State<_EpisodeChip> createState() => _EpisodeChipState();
}

class _EpisodeChipState extends State<_EpisodeChip> {
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering ? AppTheme.primaryBlue.withValues(alpha: 0.15) : AppTheme.bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _hovering ? AppTheme.primaryBlue.withValues(alpha: 0.3) : Colors.transparent),
          ),
          child: Text(widget.episode.name, style: TextStyle(color: _hovering ? AppTheme.primaryBlue : AppTheme.textSecondary, fontSize: 13)),
        ),
      ),
    );
  }
}