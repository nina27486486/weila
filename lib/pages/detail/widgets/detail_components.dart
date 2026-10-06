part of '../detail_page.dart';

class _DetailPoster extends StatelessWidget {
  final String? coverUrl;

  const _DetailPoster({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      height: 252,
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CoverImage(url: coverUrl, fit: BoxFit.cover),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlighted;

  const _InfoPill({
    required this.icon,
    required this.text,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? AppTheme.scoreOrange : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (highlighted ? AppTheme.scoreOrange : Colors.white)
            .withValues(alpha: highlighted ? 0.16 : 0.09),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.82), size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color.withValues(alpha: 0.86),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTag extends StatelessWidget {
  final String text;

  const _DetailTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.16)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_HeroActionButton> createState() => _HeroActionButtonState();
}

class _HeroActionButtonState extends State<_HeroActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: enabled
                ? (_hovering ? AppTheme.accentBlue : AppTheme.primaryBlue)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            boxShadow: enabled && _hovering
                ? [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatefulWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _HeroIconButton({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeroIconButton> createState() => _HeroIconButtonState();
}

class _HeroIconButtonState extends State<_HeroIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: widget.active
                  ? AppTheme.primaryBlue.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: _hovering ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.active
                    ? AppTheme.primaryBlue.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              widget.icon,
              color: widget.active
                  ? AppTheme.primaryBlue
                  : Colors.white.withValues(alpha: 0.84),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatefulWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ViewToggleButton> createState() => _ViewToggleButtonState();
}

class _ViewToggleButtonState extends State<_ViewToggleButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: 34,
            height: 32,
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.18)
                  : context.colors.bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.selected || _hovering
                    ? AppTheme.primaryBlue.withValues(alpha: 0.36)
                    : context.colors.divider,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 17,
              color: widget.selected
                  ? AppTheme.primaryBlue
                  : context.colors.textSecondary,
            ),
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
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          colors: _lit
              ? [
                  context.colors.bgCard,
                  context.colors.bgHover,
                  context.colors.bgCard
                ]
              : [
                  context.colors.bgSurface.withValues(alpha: 0.55),
                  context.colors.bgCard,
                  context.colors.bgSurface.withValues(alpha: 0.55),
                ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
    );
  }
}

class _EpisodeListTile extends StatefulWidget {
  final Episode episode;
  final int index;
  final VoidCallback onTap;

  const _EpisodeListTile({
    required this.episode,
    required this.index,
    required this.onTap,
  });

  @override
  State<_EpisodeListTile> createState() => _EpisodeListTileState();
}

class _EpisodeListTileState extends State<_EpisodeListTile> {
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hovering ? context.colors.bgHover : context.colors.bgCard,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _hovering
                  ? AppTheme.primaryBlue.withValues(alpha: 0.36)
                  : context.colors.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.episode.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _hovering
                        ? AppTheme.primaryBlue
                        : context.colors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                color:
                    _hovering ? AppTheme.primaryBlue : context.colors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
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
          duration: Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovering
                ? AppTheme.primaryBlue.withValues(alpha: 0.15)
                : context.colors.bgCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: _hovering
                    ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                    : Colors.transparent),
          ),
          child: Text(widget.episode.name,
              style: TextStyle(
                  color: _hovering
                      ? AppTheme.primaryBlue
                      : context.colors.textSecondary,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

/// 详情 Hero 来源展示状态。
enum DetailHeroSourceState { hidden, available, searching, unavailable }

/// 详情 Hero 来源的纯展示描述：由页面 State 判定后传入 [DetailHeroPanel]。
class DetailHeroSourcePresentation {
  final DetailHeroSourceState state;
  final String label;
  final VoidCallback? onManualSearch;

  const DetailHeroSourcePresentation.hidden()
      : state = DetailHeroSourceState.hidden,
        label = '',
        onManualSearch = null;

  const DetailHeroSourcePresentation.available(this.label)
      : state = DetailHeroSourceState.available,
        onManualSearch = null;

  const DetailHeroSourcePresentation.searching()
      : state = DetailHeroSourceState.searching,
        label = '搜索视频源中...',
        onManualSearch = null;

  const DetailHeroSourcePresentation.unavailable({this.onManualSearch})
      : state = DetailHeroSourceState.unavailable,
        label = '暂无视频源';
}

/// 详情页 Hero 纯展示组件。
///
/// 只接收展示数据与回调，不依赖 Store、Service、网络或本地存储；
/// 内容宽度 >= [DetailHeroPanel.horizontalBreakpoint] 时保持既有固定
/// 410 高横向布局，窄屏使用自然高度纵向杂志卡布局。
class DetailHeroPanel extends StatelessWidget {
  final ArtworkPalette palette;
  final String? coverUrl;
  final Object heroTag;
  final String name;
  final String nameJa;
  final String summary;
  final double? rating;
  final Object? ratingCount;
  final Object? rank;
  final List<String> tags;
  final String date;
  final String platform;
  final int totalEpisodeCount;
  final DetailHeroSourcePresentation source;
  final bool playEnabled;
  final bool tracked;
  final bool collected;
  final VoidCallback? onPlay;
  final VoidCallback onToggleTrack;
  final VoidCallback onToggleCollect;

  const DetailHeroPanel({
    super.key,
    required this.palette,
    required this.coverUrl,
    required this.heroTag,
    required this.name,
    required this.nameJa,
    required this.summary,
    required this.rating,
    required this.ratingCount,
    required this.rank,
    required this.tags,
    required this.date,
    required this.platform,
    required this.totalEpisodeCount,
    required this.source,
    required this.playEnabled,
    required this.tracked,
    required this.collected,
    required this.onPlay,
    required this.onToggleTrack,
    required this.onToggleCollect,
  });

  /// 桌面横向布局的最小内容宽度断点（沿用首页内容密集 Hero 的分界）。
  static const double horizontalBreakpoint = 1040;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal =
            constraints.maxWidth >= DetailHeroPanel.horizontalBreakpoint;
        return horizontal
            ? KeyedSubtree(
                key: const ValueKey('detail-hero-horizontal'),
                child: _heroShell(
                    context, StackFit.expand, _horizontalChildren(context)),
              )
            : KeyedSubtree(
                key: const ValueKey('detail-hero-compact'),
                child: _heroShell(
                    context, StackFit.loose, _compactChildren(context)),
              );
      },
    );
  }

  /// 共享外壳：同 key、边框、clip 与环境背景层。
  ///
  /// 横向分支用 [StackFit.expand] 保持旧树；compact 分支用默认 loose，
  /// 背景与渐变走 [Positioned.fill]，前景决定自然高度。
  Widget _heroShell(
    BuildContext context,
    StackFit fit,
    List<Widget> stackChildren,
  ) {
    final gradient = DecoratedBox(
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
    );
    final backdrop = AmbientArtworkBackdrop(
      palette: palette,
      child: const SizedBox.expand(),
    );
    return Container(
      key: const ValueKey('detail-ambient-hero'),
      height: fit == StackFit.expand ? 410 : null,
      decoration: BoxDecoration(
        color: context.colors.bgCard,
        border: Border(
          top: BorderSide(color: context.colors.divider),
          bottom: BorderSide(color: context.colors.divider),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: fit,
        children: [
          if (fit == StackFit.expand) ...[
            backdrop,
            gradient,
          ] else ...[
            Positioned.fill(child: backdrop),
            Positioned.fill(child: gradient),
          ],
          ...stackChildren,
        ],
      ),
    );
  }

  List<Widget> _horizontalChildren(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Hero(
              tag: heroTag,
              child: ArtworkParallax(
                child: _DetailPoster(coverUrl: coverUrl),
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _infoChildren(context, compact: false),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _compactChildren(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Hero(
                tag: heroTag,
                child: ArtworkParallax(
                  child: _DetailPoster(coverUrl: coverUrl),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ..._infoChildren(context, compact: true),
          ],
        ),
      ),
    ];
  }

  /// 信息列：两分支共用同一字段顺序与文字常量。
  ///
  /// compact 差异：来源独占一行（长文本单行省略、unavailable 用 Wrap）、
  /// 操作区用 Wrap 合法换行。
  List<Widget> _infoChildren(BuildContext context, {required bool compact}) {
    final actionButtons = <Widget>[
      _HeroActionButton(
        icon: Icons.play_arrow_rounded,
        label: playEnabled ? '立即播放' : '等待片源',
        onTap: onPlay,
      ),
      _HeroIconButton(
        icon: tracked ? Icons.calendar_month : Icons.calendar_month_outlined,
        active: tracked,
        tooltip: tracked ? '已追番' : '追番',
        onTap: onToggleTrack,
      ),
      _HeroIconButton(
        icon: collected ? Icons.bookmark : Icons.bookmark_border,
        active: collected,
        tooltip: collected ? '已收藏' : '收藏',
        onTap: onToggleCollect,
      ),
    ];
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (date.isNotEmpty)
            _InfoPill(icon: Icons.calendar_today_outlined, text: date),
          if (platform.isNotEmpty)
            _InfoPill(icon: Icons.tv_outlined, text: platform),
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
          shadows: [Shadow(blurRadius: 12, color: Colors.black87)],
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
          if (rating != null) _scoreBadge(rating!),
          if (ratingCount != null)
            _InfoPill(
                icon: Icons.people_alt_outlined,
                text: '${ratingCount.toString()}人评分'),
          if (rank != null)
            _InfoPill(
                icon: Icons.emoji_events_outlined,
                text: '排名 $rank',
                highlighted: true),
          if (!compact) _sourceView(),
        ],
      ),
      if (compact && source.state != DetailHeroSourceState.hidden) ...[
        const SizedBox(height: 10),
        _compactSourceRow(),
      ],
      if (tags.isNotEmpty) ...[
        const SizedBox(height: 14),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: tags.take(5).map((tag) => _DetailTag(text: tag)).toList(),
        ),
      ],
      const SizedBox(height: 18),
      if (compact)
        Wrap(spacing: 10, runSpacing: 10, children: actionButtons)
      else
        Row(children: [
          actionButtons[0],
          const SizedBox(width: 10),
          actionButtons[1],
          const SizedBox(width: 10),
          actionButtons[2],
        ]),
    ];
  }

  /// compact 分支来源行：独占一行，长文本单行省略。
  Widget _compactSourceRow() {
    switch (source.state) {
      case DetailHeroSourceState.hidden:
        return const SizedBox.shrink();
      case DetailHeroSourceState.available:
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
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.scoreGreen, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      case DetailHeroSourceState.searching:
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
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  source.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.scoreOrange, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      case DetailHeroSourceState.unavailable:
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _sourceWarningChip(),
            _sourceManualChip(),
          ],
        );
    }
  }

  Widget _scoreBadge(double score) {
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

  /// 横向分支来源指示器（旧树逐值保留）。
  Widget _sourceView() {
    switch (source.state) {
      case DetailHeroSourceState.hidden:
        return const SizedBox.shrink();
      case DetailHeroSourceState.available:
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
              const SizedBox(width: 4),
              Text(
                source.label,
                style: TextStyle(color: AppTheme.scoreGreen, fontSize: 11),
              ),
            ],
          ),
        );
      case DetailHeroSourceState.searching:
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
              const SizedBox(width: 4),
              Text(
                source.label,
                style: TextStyle(color: AppTheme.scoreOrange, fontSize: 11),
              ),
            ],
          ),
        );
      case DetailHeroSourceState.unavailable:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sourceWarningChip(),
            const SizedBox(width: 8),
            _sourceManualChip(),
          ],
        );
    }
  }

  Widget _sourceWarningChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.scoreRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 14, color: AppTheme.scoreRed),
          const SizedBox(width: 4),
          Text(
            source.label,
            style: TextStyle(color: AppTheme.scoreRed, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _sourceManualChip() {
    return GestureDetector(
      onTap: source.onManualSearch,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border:
                Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 14, color: AppTheme.primaryBlue),
              const SizedBox(width: 4),
              const Text(
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
    );
  }
}
