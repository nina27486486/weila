import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../services/plugin/plugin_service.dart';
import '../../widgets/cover_image.dart';

/// 排行榜页面 - 展示评分最高的动漫
class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final PluginService _pluginService = PluginService();
  List<Map<String, dynamic>> _rankingList = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _pluginService.getCmsRanking(
        pluginApi: 'cms_yinhua',
        pages: 3,
      );
      if (mounted) {
        setState(() {
          _rankingList = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载排行榜失败: $e';
          _loading = false;
        });
      }
    }
  }

  void _goToDetail(Map<String, dynamic> item) {
    final url = item['url'] ?? '';
    final name = item['name'] ?? '';
    Modular.to.pushNamed('/detail?url=${Uri.encodeComponent(url)}&name=${Uri.encodeComponent(name)}');
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 0:
        return const Color(0xFFFFD700); // 金色
      case 1:
        return const Color(0xFFC0C0C0); // 银色
      case 2:
        return const Color(0xFFCD7F32); // 铜色
      default:
        return AppTheme.textMuted;
    }
  }

  String _rankLabel(int rank) {
    switch (rank) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '#${rank + 1}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('排行榜'),
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.navigate('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRanking,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryBlue),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.scoreRed),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRanking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_rankingList.isEmpty) {
      return Center(
        child: Text('暂无排行数据', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    final podiumItems = _rankingList.take(3).toList();
    final restItems = _rankingList.skip(3).toList();

    return RefreshIndicator(
      onRefresh: _loadRanking,
      color: AppTheme.primaryBlue,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 顶部领奖台区域
          if (podiumItems.isNotEmpty) _buildPodiumSection(podiumItems),
          if (restItems.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              '完整排名',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(restItems.length, (i) {
              return _buildRankListItem(restItems[i], i + 3);
            }),
          ],
        ],
      ),
    );
  }

  /// 领奖台区域：第1、2、3名大卡片
  Widget _buildPodiumSection(List<Map<String, dynamic>> items) {
    // 确保按顺序: 1st=center, 左2nd, 右3rd
    final first = items.isNotEmpty ? items[0] : null;
    final second = items.length > 1 ? items[1] : null;
    final third = items.length > 2 ? items[2] : null;

    return Column(
      children: [
        const SizedBox(height: 8),
        // 标题装饰
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, AppTheme.primaryBlue],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.emoji_events, color: const Color(0xFFFFD700), size: 24),
            const SizedBox(width: 8),
            Text(
              'TOP 3',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue, Colors.transparent],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // 领奖台排列：2nd, 1st, 3rd
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (second != null)
              Expanded(child: _buildPodiumCard(second, 1, 140)),
            if (first != null) ...[
              const SizedBox(width: 10),
              Expanded(child: _buildPodiumCard(first, 0, 170)),
              const SizedBox(width: 10),
            ],
            if (third != null)
              Expanded(child: _buildPodiumCard(third, 2, 120)),
          ],
        ),
      ],
    );
  }

  /// 单个领奖台卡片
  Widget _buildPodiumCard(Map<String, dynamic> item, int rank, double height) {
    final color = _rankColor(rank);
    final score = item['score'] as double?;
    final cover = item['cover']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';

    return GestureDetector(
      onTap: () => _goToDetail(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // 排名徽章
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _rankLabel(rank),
                    style: TextStyle(
                      color: color,
                      fontSize: rank < 3 ? 18 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 封面
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CoverImage(url: cover, fit: BoxFit.cover, width: double.infinity),
                ),
              ),
            ),
            // 名称
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // 评分
            if (score != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 2),
                child: _buildScoreBadge(score),
              ),
          ],
        ),
      ),
    );
  }

  /// 评分徽章
  Widget _buildScoreBadge(double score) {
    Color badgeColor;
    if (score >= 8.0) {
      badgeColor = AppTheme.scoreGreen;
    } else if (score >= 6.0) {
      badgeColor = AppTheme.scoreOrange;
    } else {
      badgeColor = AppTheme.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// #4~#30 列表项
  Widget _buildRankListItem(Map<String, dynamic> item, int rank) {
    final name = item['name']?.toString() ?? '';
    final cover = item['cover']?.toString() ?? '';
    final score = item['score'] as double?;
    final status = item['status']?.toString() ?? '';
    final genres = (item['genres'] as List?)?.cast<String>() ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _goToDetail(item),
          borderRadius: BorderRadius.circular(10),
          hoverColor: AppTheme.bgHover,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                // 排名数字
                SizedBox(
                  width: 36,
                  child: Text(
                    '#$rank',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 小封面
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 48,
                    height: 64,
                    child: CoverImage(url: cover, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                // 信息区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (status.isNotEmpty || genres.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (status.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.tagBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            if (status.isNotEmpty && genres.isNotEmpty)
                              const SizedBox(width: 6),
                            if (genres.isNotEmpty)
                              Expanded(
                                child: Text(
                                  genres.join(' / '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 评分
                if (score != null) _buildScoreBadge(score),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
