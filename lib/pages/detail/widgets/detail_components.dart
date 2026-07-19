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
