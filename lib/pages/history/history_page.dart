import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../theme/app_theme.dart';
import '../../stores/history_collect_store.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _store = HistoryCollectStore();

  @override
  void initState() {
    super.initState();
    _store.loadHistory();
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
        title: const Text('观看历史', style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          Observer(
            builder: (_) => _store.historyList.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
                    tooltip: '清空历史',
                    onPressed: () => _confirmClear(context),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Observer(
        builder: (_) {
          if (_store.historyList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: AppTheme.textMuted),
                  SizedBox(height: 16),
                  Text('暂无观看历史', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  SizedBox(height: 4),
                  Text('去看点什么吧', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _store.historyList.length,
            itemBuilder: (context, index) {
              final item = _store.historyList[index];
              return _HistoryCard(
                item: item,
                onTap: () {
                  Modular.to.pushNamed(
                    '/player?url=${Uri.encodeComponent(item.episodeUrl)}'
                    '&title=${Uri.encodeComponent(item.episodeName)}'
                    '&animeUrl=${Uri.encodeComponent(item.animeUrl)}'
                    '&ep=${item.episodeUrl.split('/ep/').last}'
                    '&source=${Uri.encodeComponent(item.sourcePlugin)}',
                  );
                },
                onDelete: () async {
                  await item.delete();
                  _store.loadHistory();
                },
              );
            },
          );
        },
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('清空历史', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('确定要清空所有观看历史吗？', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              _store.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('清空', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatefulWidget {
  final dynamic item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _hovering = false;

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final progress = item.duration.inMilliseconds > 0
        ? item.position.inMilliseconds / item.duration.inMilliseconds
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
                  width: 80,
                  height: 56,
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
                      // 番名
                      Text(
                        item.animeName,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // 集数
                      Text(
                        item.episodeName,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // 进度条
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                backgroundColor: AppTheme.tagBg,
                                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
                                minHeight: 3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _timeAgo(item.watchedAt),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 删除按钮
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
