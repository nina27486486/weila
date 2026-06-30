import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/anime.dart';

class EpisodeSidebar extends StatelessWidget {
  final List<Episode> episodes;
  final int currentIndex;
  final ValueChanged<int> onEpisodeTap;
  final VoidCallback onClose;
  final bool loading;

  const EpisodeSidebar({
    super.key,
    required this.episodes,
    required this.currentIndex,
    required this.onEpisodeTap,
    required this.onClose,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF080B14),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '选集',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loading
                            ? '正在整理节目单'
                            : '${episodes.length}集 · 当前第${currentIndex + 1}集',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭选集',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white70,
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    itemCount: 8,
                    itemBuilder: (_, __) => const _EpisodeSkeleton(),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      return _EpisodeTile(
                        episodeName: episode.name,
                        index: index,
                        selected: index == currentIndex,
                        onTap: () => onEpisodeTap(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatefulWidget {
  const _EpisodeTile({
    required this.episodeName,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final String episodeName;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_EpisodeTile> createState() => _EpisodeTileState();
}

class _EpisodeTileState extends State<_EpisodeTile> {
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
          duration: const Duration(milliseconds: 170),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppTheme.primaryBlue.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: _hovering ? 0.08 : 0.035),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.selected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${widget.index + 1}'.padLeft(2, '0'),
                style: TextStyle(
                  color: widget.selected
                      ? AppTheme.primaryBlue
                      : Colors.white.withValues(alpha: 0.38),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.episodeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.25,
                    fontWeight:
                        widget.selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (widget.selected)
                const Icon(
                  Icons.play_arrow_rounded,
                  color: AppTheme.primaryBlue,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeSkeleton extends StatefulWidget {
  const _EpisodeSkeleton();

  @override
  State<_EpisodeSkeleton> createState() => _EpisodeSkeletonState();
}

class _EpisodeSkeletonState extends State<_EpisodeSkeleton> {
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pulse());
  }

  void _pulse() {
    if (!mounted) return;
    setState(() => _lit = !_lit);
    Future.delayed(const Duration(milliseconds: 760), _pulse);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 760),
      margin: const EdgeInsets.only(bottom: 8),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          colors: _lit
              ? [
                  Colors.white.withValues(alpha: 0.04),
                  Colors.white.withValues(alpha: 0.09),
                  Colors.white.withValues(alpha: 0.04),
                ]
              : [
                  Colors.white.withValues(alpha: 0.025),
                  Colors.white.withValues(alpha: 0.055),
                  Colors.white.withValues(alpha: 0.025),
                ],
        ),
      ),
    );
  }
}
