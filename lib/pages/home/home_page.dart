import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import '../../widgets/left_sidebar.dart';
import '../../widgets/top_search_bar.dart';
import '../../widgets/carousel_banner.dart';
import '../../widgets/anime_card.dart';
import '../../widgets/section_title.dart';
import '../../widgets/right_sidebar.dart';
import '../../stores/home_store.dart';
import '../../stores/history_collect_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedNavIndex = 0;
  final _searchController = TextEditingController();
  final _homeStore = HomeStore();
  final _trackStore = HistoryCollectStore();

  @override
  void initState() {
    super.initState();
    _homeStore.loadAll();
    _trackStore.loadTracks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Row(
        children: [
          LeftSidebar(
            selectedIndex: _selectedNavIndex,
            onIndexChanged: (i) => setState(() => _selectedNavIndex = i),
          ),
          
          Expanded(
            child: Column(
              children: [
                TopSearchBar(
                  controller: _searchController,
                  onSearch: (q) => Modular.to.pushNamed('/search?q=$q'),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 轮播横幅（热门前5）
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 100),
                          child: _buildCarousel(),
                        ),
                        
                        const SizedBox(height: 28),
                        
                        // 最新番剧
                        const FadeSlideIn(
                          delay: Duration(milliseconds: 250),
                          child: SectionTitle(
                            title: '最新番剧',
                            subtitle: '持续更新中',
                          ),
                        ),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 350),
                          child: _buildLatestList(),
                        ),
                        
                        const SizedBox(height: 28),
                        
                        // 热门推荐
                        const FadeSlideIn(
                          delay: Duration(milliseconds: 450),
                          child: SectionTitle(
                            title: '热门推荐',
                            subtitle: '大家都在看',
                          ),
                        ),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 550),
                          child: _buildTrendingList(),
                        ),
                        
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            beginOffset: const Offset(0.05, 0),
            child: _buildRightSidebar(),
          ),
        ],
      ),
    );
  }

  /// 轮播横幅（热门前5）
  Widget _buildCarousel() {
    return Observer(
      builder: (_) {
        if (_homeStore.isLoadingTrending && _homeStore.trendingList.isEmpty) {
          return Container(
            height: 280,
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
            ),
          );
        }

        final items = _homeStore.trendingList.take(5).map((item) {
          return CarouselItem(
            title: item['name'] ?? '',
            imageUrl: item['cover'],
            tags: (item['genres'] as List?)?.cast<String>() ?? [],
            description: item['status'] ?? '',
            onDetail: () {
              Modular.to.pushNamed(
                '/detail?url=${Uri.encodeComponent(item['url'] ?? '')}'
                '&name=${Uri.encodeComponent(item['name'] ?? '')}',
              );
            },
          );
        }).toList();

        return CarouselBanner(items: items);
      },
    );
  }

  /// 最新番剧列表
  Widget _buildLatestList() {
    return Observer(
      builder: (_) {
        if (_homeStore.isLoadingLatest && _homeStore.latestList.isEmpty) {
          return const SizedBox(
            height: 270,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
            ),
          );
        }

        final items = _homeStore.latestList;
        if (items.isEmpty) {
          return const SizedBox(
            height: 270,
            child: Center(
              child: Text('暂无数据', style: TextStyle(color: AppTheme.textMuted)),
            ),
          );
        }

        return _buildHorizontalAnimeList(items);
      },
    );
  }

  /// 热门推荐列表
  Widget _buildTrendingList() {
    return Observer(
      builder: (_) {
        if (_homeStore.isLoadingTrending && _homeStore.trendingList.isEmpty) {
          return const SizedBox(
            height: 270,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
            ),
          );
        }

        final items = _homeStore.trendingList;
        if (items.isEmpty) {
          return const SizedBox(
            height: 270,
            child: Center(
              child: Text('暂无数据', style: TextStyle(color: AppTheme.textMuted)),
            ),
          );
        }

        return _buildHorizontalAnimeList(items);
      },
    );
  }

  /// 横向动漫列表
  Widget _buildHorizontalAnimeList(List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 270,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          final score = item['score'] as double?;
          final genres = (item['genres'] as List?)?.cast<String>() ?? [];
          
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + index * 80),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: AnimeCard(
              title: item['name'] ?? '',
              coverUrl: item['cover'],
              score: score,
              tags: genres,
              onTap: () {
                Modular.to.pushNamed(
                  '/detail?url=${Uri.encodeComponent(item['url'] ?? '')}'
                  '&name=${Uri.encodeComponent(item['name'] ?? '')}',
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// 右侧边栏
  Widget _buildRightSidebar() {
    return Observer(
      builder: (_) {
        final trackingList = _trackStore.trackList.map((item) {
          String updateInfo;
          if (item.totalEpisodes > 0) {
            updateInfo = '看到第${item.watchedEpisodes}集 / 共${item.totalEpisodes}集';
          } else {
            updateInfo = '看到第${item.watchedEpisodes}集';
          }
          return TrackingAnime(
            title: item.animeName,
            coverUrl: item.cover,
            updateInfo: updateInfo,
            updateTime: _timeAgo(item.lastUpdated ?? item.trackedAt),
          );
        }).toList();

        return RightSidebar(
          trackingList: trackingList,
          calendarData: const {},
        );
      },
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}
