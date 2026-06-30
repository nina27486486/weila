import 'package:flutter/material.dart';

import '../../theme/vira_colors.dart';
import '../../widgets/editorial_section_header.dart';
import '../../widgets/vira_state_view.dart';

enum OfflineStatus { waiting, downloading, completed, paused, failed }

@immutable
class OfflineEpisode {
  final String id;
  final String animeName;
  final String episodeName;
  final OfflineStatus status;
  final double progress;
  final String fileSizeLabel;
  final String segmentLabel;

  const OfflineEpisode({
    required this.id,
    required this.animeName,
    required this.episodeName,
    required this.status,
    required this.progress,
    this.fileSizeLabel = '',
    this.segmentLabel = '',
  });
}

class OfflineLibraryView extends StatelessWidget {
  final List<OfflineEpisode> episodes;
  final ValueChanged<OfflineEpisode> onPause;
  final ValueChanged<OfflineEpisode> onResume;
  final ValueChanged<OfflineEpisode> onRetry;
  final ValueChanged<OfflineEpisode> onPlay;
  final ValueChanged<OfflineEpisode> onRemove;
  final VoidCallback onRefresh;

  const OfflineLibraryView({
    super.key,
    required this.episodes,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onPlay,
    required this.onRemove,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<OfflineEpisode>>{};
    for (final episode in episodes) {
      groups.putIfAbsent(episode.animeName, () => []).add(episode);
    }
    final activeCount = episodes
        .where(
          (entry) =>
              entry.status == OfflineStatus.downloading ||
              entry.status == OfflineStatus.waiting,
        )
        .length;
    final completedCount = episodes
        .where((entry) => entry.status == OfflineStatus.completed)
        .length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34),
            child: _OfflineIntroduction(
              totalCount: episodes.length,
              activeCount: activeCount,
              completedCount: completedCount,
              onRefresh: onRefresh,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34, bottom: 16),
            child: EditorialSectionHeader(
              chapter: '离线清单',
              title: '缓存任务',
              subtitle: episodes.isEmpty
                  ? '准备好后，离线也能继续放映'
                  : '${groups.length} 部作品 · ${episodes.length} 个单集',
            ),
          ),
        ),
        if (episodes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.empty(
              title: '离线放映室还是空的',
              message: '在播放器中缓存单集，出门后也能继续观看。',
            ),
          )
        else
          SliverPadding(
            key: const ValueKey('offline-task-list'),
            padding: const EdgeInsets.only(bottom: 44),
            sliver: SliverList.separated(
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final name = groups.keys.elementAt(index);
                return _OfflineAnimeGroup(
                  animeName: name,
                  episodes: groups[name]!,
                  onPause: onPause,
                  onResume: onResume,
                  onRetry: onRetry,
                  onPlay: onPlay,
                  onRemove: onRemove,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _OfflineIntroduction extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int completedCount;
  final VoidCallback onRefresh;

  const _OfflineIntroduction({
    required this.totalCount,
    required this.activeCount,
    required this.completedCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      key: const ValueKey('offline-overview'),
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
                    Container(width: 32, height: 1, color: colors.sky),
                    const SizedBox(width: 10),
                    Text(
                      '把喜欢的画面带在身边',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colors.sakura,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '离线放映室',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 40,
                      ),
                ),
                const SizedBox(height: 7),
                Text(
                  '下载任务、缓存进度与本地播放，在这里排成一张安静的放映清单。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          _OfflineMetric(
            value: totalCount.toString().padLeft(2, '0'),
            label: '全部单集',
          ),
          const SizedBox(width: 10),
          _OfflineMetric(
            value: activeCount.toString().padLeft(2, '0'),
            label: '进行中',
            accent: colors.sky,
          ),
          const SizedBox(width: 10),
          _OfflineMetric(
            value: completedCount.toString().padLeft(2, '0'),
            label: '已完成',
            accent: colors.success,
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '刷新下载状态',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineMetric extends StatelessWidget {
  final String value;
  final String label;
  final Color? accent;

  const _OfflineMetric({
    required this.value,
    required this.label,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: BoxDecoration(
        color: context.colors.paper,
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: accent ?? context.colors.textPrimary,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _OfflineAnimeGroup extends StatelessWidget {
  final String animeName;
  final List<OfflineEpisode> episodes;
  final ValueChanged<OfflineEpisode> onPause;
  final ValueChanged<OfflineEpisode> onResume;
  final ValueChanged<OfflineEpisode> onRetry;
  final ValueChanged<OfflineEpisode> onPlay;
  final ValueChanged<OfflineEpisode> onRemove;

  const _OfflineAnimeGroup({
    required this.animeName,
    required this.episodes,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final completed = episodes
        .where((entry) => entry.status == OfflineStatus.completed)
        .length;

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(width: 3, height: 22, color: context.colors.sakura),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    animeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$completed / ${episodes.length} 集已就绪',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.colors.divider),
          for (var index = 0; index < episodes.length; index++)
            _OfflineEpisodeRow(
              episode: episodes[index],
              showDivider: index != episodes.length - 1,
              onPause: () => onPause(episodes[index]),
              onResume: () => onResume(episodes[index]),
              onRetry: () => onRetry(episodes[index]),
              onPlay: () => onPlay(episodes[index]),
              onRemove: () => onRemove(episodes[index]),
            ),
        ],
      ),
    );
  }
}

class _OfflineEpisodeRow extends StatefulWidget {
  final OfflineEpisode episode;
  final bool showDivider;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _OfflineEpisodeRow({
    required this.episode,
    required this.showDivider,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  State<_OfflineEpisodeRow> createState() => _OfflineEpisodeRowState();
}

class _OfflineEpisodeRowState extends State<_OfflineEpisodeRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = _statusColor(colors, widget.episode.status);

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered ? colors.bgHover : Colors.transparent,
          border: widget.showDivider
              ? Border(bottom: BorderSide(color: colors.divider))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              color: statusColor.withValues(alpha: 0.12),
              child: Icon(
                _statusIcon(widget.episode.status),
                size: 19,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.episode.episodeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: widget.episode.status == OfflineStatus.waiting
                              ? null
                              : widget.episode.progress.clamp(0, 1),
                          minHeight: 3,
                          backgroundColor: colors.divider,
                          valueColor: AlwaysStoppedAnimation(statusColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 52,
                        child: Text(
                          '${(widget.episode.progress.clamp(0, 1) * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 170,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _statusLabel(widget.episode.status),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: statusColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      widget.episode.fileSizeLabel,
                      widget.episode.segmentLabel,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            ..._actionsForStatus(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _actionsForStatus(BuildContext context) {
    final actions = <Widget>[];
    switch (widget.episode.status) {
      case OfflineStatus.waiting:
      case OfflineStatus.downloading:
        actions.add(
          _TaskAction(
            tooltip: '暂停下载',
            icon: Icons.pause_rounded,
            onTap: widget.onPause,
          ),
        );
      case OfflineStatus.completed:
        actions.add(
          _TaskAction(
            tooltip: '播放缓存',
            icon: Icons.play_arrow_rounded,
            onTap: widget.onPlay,
          ),
        );
      case OfflineStatus.paused:
        actions.add(
          _TaskAction(
            tooltip: '继续下载',
            icon: Icons.play_arrow_rounded,
            onTap: widget.onResume,
          ),
        );
      case OfflineStatus.failed:
        actions.add(
          _TaskAction(
            tooltip: '重试下载',
            icon: Icons.refresh_rounded,
            onTap: widget.onRetry,
          ),
        );
    }
    actions.add(
      _TaskAction(
        tooltip:
            widget.episode.status == OfflineStatus.completed ? '删除缓存' : '取消下载',
        icon: Icons.close_rounded,
        danger: true,
        onTap: widget.onRemove,
      ),
    );
    return actions;
  }

  IconData _statusIcon(OfflineStatus status) => switch (status) {
        OfflineStatus.waiting => Icons.schedule_rounded,
        OfflineStatus.downloading => Icons.south_rounded,
        OfflineStatus.completed => Icons.check_rounded,
        OfflineStatus.paused => Icons.pause_rounded,
        OfflineStatus.failed => Icons.error_outline_rounded,
      };

  String _statusLabel(OfflineStatus status) => switch (status) {
        OfflineStatus.waiting => '等待下载',
        OfflineStatus.downloading => '正在下载',
        OfflineStatus.completed => '已完成',
        OfflineStatus.paused => '已暂停',
        OfflineStatus.failed => '下载失败',
      };

  Color _statusColor(ViraColors colors, OfflineStatus status) =>
      switch (status) {
        OfflineStatus.waiting => colors.textMuted,
        OfflineStatus.downloading => colors.sky,
        OfflineStatus.completed => colors.success,
        OfflineStatus.paused => colors.warning,
        OfflineStatus.failed => colors.danger,
      };
}

class _TaskAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _TaskAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            onPressed: onTap,
            icon: Icon(
              icon,
              size: 18,
              color:
                  danger ? context.colors.danger : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
