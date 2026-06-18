import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../theme/app_theme.dart';
import '../../stores/history_collect_store.dart';

class TrackPage extends StatefulWidget {
  const TrackPage({super.key});

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage> {
  final _store = HistoryCollectStore();

  @override
  void initState() {
    super.initState();
    _store.loadTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.navigate('/'),
        ),
        title: const Text('追番列表', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: Observer(
        builder: (_) {
          if (_store.trackList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text('暂无追番', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('在详情页点击「追番」添加正在追的番', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _store.trackList.length,
            itemBuilder: (context, index) {
              final item = _store.trackList[index];
              final isAiring = item.status == 'RELEASING';
              final isFinished = item.status == 'FINISHED';

              return _TrackCard(
                item: item,
                isAiring: isAiring,
                isFinished: isFinished,
                onTap: () {
                  Modular.to.pushNamed(
                    '/detail?url=${Uri.encodeComponent(item.animeUrl)}'
                    '&name=${Uri.encodeComponent(item.animeName)}',
                  );
                },
                onRemove: () async {
                  await _store.removeTrack(item.animeUrl);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TrackCard extends StatefulWidget {
  final dynamic item;
  final bool isAiring;
  final bool isFinished;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _TrackCard({
    required this.item,
    required this.isAiring,
    required this.isFinished,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<_TrackCard> {
  bool _hovering = false;

  Color get _statusColor {
    if (widget.isAiring) return AppTheme.airing;
    if (widget.isFinished) return AppTheme.textMuted;
    return AppTheme.updating;
  }

  String get _statusText {
    if (widget.isAiring) return '连载中';
    if (widget.isFinished) return '已完结';
    if (widget.item.status == 'NOT_YET_RELEASED') return '未开播';
    return '未知';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final progress = item.totalEpisodes > 0
        ? item.watchedEpisodes / item.totalEpisodes
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _hovering ? AppTheme.bgHover : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hovering ? AppTheme.primaryBlue.withValues(alpha: 0.3) : AppTheme.divider,
              ),
            ),
            child: Row(
              children: [
                // 封面
                Container(
                  width: 64,
                  height: 86,
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: item.cover != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            item.cover!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.movie_outlined, size: 24, color: AppTheme.textMuted),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.movie_outlined, size: 24, color: AppTheme.textMuted),
                        ),
                ),
                const SizedBox(width: 12),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题 + 状态
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.animeName,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _statusText,
                              style: TextStyle(color: _statusColor, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 进度
                      Row(
                        children: [
                          Text(
                            '看到第${item.watchedEpisodes}集',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          if (item.totalEpisodes > 0) ...[
                            const SizedBox(width: 4),
                            Text(
                              '/ 共${item.totalEpisodes}集',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 进度条
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: AppTheme.tagBg,
                          valueColor: AlwaysStoppedAnimation(_statusColor),
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // 来源 + 追番时间
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.tagBg,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              item.sourcePlugin,
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 9),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _timeAgo(item.trackedAt),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 移除按钮
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays < 1) return '今天';
    if (diff.inDays < 7) return '${diff.inDays}天前追番';
    return '${time.month}/${time.day}追番';
  }
}
