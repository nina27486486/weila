import 'package:flutter/material.dart';

import '../../services/artwork_palette_service.dart';
import '../../theme/vira_colors.dart';
import '../../widgets/artwork_components.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/vira_state_view.dart';
import '../../widgets/vira_text_tabs.dart';

enum ArchiveDisplayMode { poster, timeline, progress }

@immutable
class ArchiveEntry {
  final String id;
  final String title;
  final String? coverUrl;
  final String subtitle;
  final String meta;
  final String sourceLabel;
  final double progress;
  final String? statusLabel;

  const ArchiveEntry({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.subtitle,
    required this.meta,
    this.sourceLabel = '',
    this.progress = 0,
    this.statusLabel,
  });
}

@immutable
class ArchiveSection {
  final String id;
  final String label;

  const ArchiveSection({required this.id, required this.label});
}

class PersonalArchiveView extends StatelessWidget {
  final String title;
  final String description;
  final ArchiveDisplayMode mode;
  final List<ArchiveEntry> entries;
  final List<ArchiveSection> sections;
  final String? selectedSectionId;
  final ValueChanged<String>? onSectionSelected;
  final ValueChanged<ArchiveEntry> onOpen;
  final ValueChanged<ArchiveEntry> onRemove;
  final VoidCallback? onClearAll;

  const PersonalArchiveView({
    super.key,
    required this.title,
    required this.description,
    required this.mode,
    required this.entries,
    required this.onOpen,
    required this.onRemove,
    this.sections = const [],
    this.selectedSectionId,
    this.onSectionSelected,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34),
            child: _ArchiveIntroduction(
              title: title,
              description: description,
              count: entries.length,
              mode: mode,
              onClearAll: entries.isEmpty ? null : onClearAll,
            ),
          ),
        ),
        if (sections.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 18),
              child: _ArchiveSections(
                sections: sections,
                selectedId: selectedSectionId,
                onSelected: onSectionSelected,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 34, bottom: 16),
            child: _ArchiveHeading(mode: mode, count: entries.length),
          ),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ViraStateView.empty(
              title: _emptyTitle(mode),
              message: _emptyMessage(mode),
            ),
          )
        else if (mode == ArchiveDisplayMode.poster) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: _FeaturedArchiveStage(
                entries: entries.take(3).toList(growable: false),
                onOpen: onOpen,
                onRemove: onRemove,
              ),
            ),
          ),
          if (entries.length > 3)
            SliverPadding(
              key: const ValueKey('archive-poster-grid'),
              padding: const EdgeInsets.only(bottom: 40),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 218,
                  mainAxisExtent: 326,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 22,
                ),
                itemCount: entries.length - 3,
                itemBuilder: (context, index) {
                  final entryIndex = index + 3;
                  final entry = entries[entryIndex];
                  return _PosterArchiveCard(
                    entry: entry,
                    index: entryIndex,
                    onOpen: () => onOpen(entry),
                    onRemove: () => onRemove(entry),
                  );
                },
              ),
            ),
        ] else if (mode == ArchiveDisplayMode.timeline)
          SliverPadding(
            key: const ValueKey('archive-timeline-list'),
            padding: const EdgeInsets.only(bottom: 40),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.colors.divider),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _TimelineArchiveRow(
                  entry: entry,
                  index: index,
                  onOpen: () => onOpen(entry),
                  onRemove: () => onRemove(entry),
                );
              },
            ),
          )
        else
          SliverPadding(
            key: const ValueKey('archive-progress-list'),
            padding: const EdgeInsets.only(bottom: 40),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _ProgressArchiveCard(
                  entry: entry,
                  index: index,
                  onOpen: () => onOpen(entry),
                  onRemove: () => onRemove(entry),
                );
              },
            ),
          ),
      ],
    );
    return _ArchiveAmbientBackdrop(entries: entries, child: scrollView);
  }

  String _emptyTitle(ArchiveDisplayMode mode) => switch (mode) {
        ArchiveDisplayMode.poster => '收藏夹还是空的',
        ArchiveDisplayMode.timeline => '还没有观看足迹',
        ArchiveDisplayMode.progress => '追番手账还没写下第一笔',
      };

  String _emptyMessage(ArchiveDisplayMode mode) => switch (mode) {
        ArchiveDisplayMode.poster => '遇见喜欢的作品时，把它留在这里。',
        ArchiveDisplayMode.timeline => '开始播放后，薇拉会替你记住停下的位置。',
        ArchiveDisplayMode.progress => '在详情页点击追番，正在发生的故事会来到这里。',
      };
}

class _ArchiveAmbientBackdrop extends StatelessWidget {
  final List<ArchiveEntry> entries;
  final Widget child;

  const _ArchiveAmbientBackdrop({
    required this.entries,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildBackdrop(ArtworkPalette palette) {
      return Container(
        key: const ValueKey('library-ambient-backdrop'),
        child: AmbientArtworkBackdrop(
          palette: palette,
          child: child,
        ),
      );
    }

    final coverUrl = entries.isEmpty ? null : entries.first.coverUrl;
    final provider = CoverImage.providerFor(coverUrl);
    if (provider == null) return buildBackdrop(ArtworkPalette.fallback);
    return ArtworkPaletteBuilder(
      cacheKey: coverUrl!,
      provider: provider,
      builder: (_, palette) => buildBackdrop(palette),
    );
  }
}

class _FeaturedArchiveStage extends StatelessWidget {
  final List<ArchiveEntry> entries;
  final ValueChanged<ArchiveEntry> onOpen;
  final ValueChanged<ArchiveEntry> onRemove;

  const _FeaturedArchiveStage({
    required this.entries,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('archive-featured-stage'),
      height: 320,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = entries.length;
          final cardWidth = (constraints.maxWidth * 0.26).clamp(162.0, 204.0);
          final available = (constraints.maxWidth - cardWidth).clamp(0, 10000);
          final spread = count <= 1
              ? 0.0
              : (cardWidth * 0.82).clamp(0, available / (count - 1)).toDouble();
          final center = (count - 1) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: context.colors.divider),
                      bottom: BorderSide(color: context.colors.divider),
                    ),
                  ),
                ),
              ),
              for (var index = 0; index < count; index++)
                Positioned(
                  width: cardWidth,
                  height: 300,
                  left: (constraints.maxWidth - cardWidth) / 2 +
                      (index - center) * spread,
                  top: index == center ? 4 : 14,
                  child: Transform.rotate(
                    angle: (index - center) * 0.055,
                    alignment: Alignment.bottomCenter,
                    child: _PosterArchiveCard(
                      entry: entries[index],
                      index: index,
                      onOpen: () => onOpen(entries[index]),
                      onRemove: () => onRemove(entries[index]),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArchiveIntroduction extends StatelessWidget {
  final String title;
  final String description;
  final int count;
  final ArchiveDisplayMode mode;
  final VoidCallback? onClearAll;

  const _ArchiveIntroduction({
    required this.title,
    required this.description,
    required this.count,
    required this.mode,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent =
        mode == ArchiveDisplayMode.progress ? colors.sakura : colors.sky;

    return Container(
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
                    Container(width: 30, height: 1, color: accent),
                    const SizedBox(width: 10),
                    Text(
                      mode == ArchiveDisplayMode.progress
                          ? '正在发生的故事'
                          : '我的动画档案',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 40,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Container(
            width: 110,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.paper,
              border: Border.all(color: colors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: accent,
                      ),
                ),
                Text('已收录', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onClearAll != null) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: '清空全部记录',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: IconButton(
                  onPressed: onClearAll,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArchiveSections extends StatelessWidget {
  final List<ArchiveSection> sections;
  final String? selectedId;
  final ValueChanged<String>? onSelected;

  const _ArchiveSections({
    required this.sections,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex = sections.indexWhere((item) => item.id == selectedId);

    return Align(
      alignment: Alignment.centerLeft,
      child: ViraTextTabs(
        labels: sections.map((item) => item.label).toList(growable: false),
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onSelected: (index) => onSelected?.call(sections[index].id),
      ),
    );
  }
}

class _ArchiveHeading extends StatelessWidget {
  final ArchiveDisplayMode mode;
  final int count;

  const _ArchiveHeading({required this.mode, required this.count});

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      ArchiveDisplayMode.poster => '封面档案墙',
      ArchiveDisplayMode.timeline => '观看时间轴',
      ArchiveDisplayMode.progress => '本周追番进度',
    };

    return Row(
      children: [
        Container(
          width: 3,
          height: 30,
          color: mode == ArchiveDisplayMode.progress
              ? context.colors.sakura
              : context.colors.sky,
        ),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(width: 10),
        Text('$count 条记录', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PosterArchiveCard extends StatelessWidget {
  final ArchiveEntry entry;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _PosterArchiveCard({
    required this.entry,
    required this.index,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return ArtworkCardSurface(
      id: 'archive-${entry.id}',
      semanticLabel: '打开第${index + 1}项收藏，${entry.title}',
      onOpen: onOpen,
      foreground: Positioned(
        right: 7,
        top: 7,
        child: _RemoveButton(
          title: entry.title,
          onRemove: onRemove,
        ),
      ),
      contentBuilder: (context, interaction) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: ClipRect(
                      key: ValueKey('archive-cover-clip-${entry.id}'),
                      child: AnimatedScale(
                        key: ValueKey('archive-cover-scale-${entry.id}'),
                        duration: interaction.duration,
                        curve: Curves.easeOutCubic,
                        scale: interaction.coverScale,
                        child: CoverImage(
                          url: entry.coverUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 9,
                    top: 9,
                    child: ArtworkCardBadge(
                      key: ValueKey('archive-rank-${entry.id}'),
                      child: Text(
                        '${index + 1}'.padLeft(2, '0'),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: colors.sky),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    entry.meta.isEmpty ? entry.sourceLabel : entry.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TimelineArchiveRow extends StatefulWidget {
  final ArchiveEntry entry;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _TimelineArchiveRow({
    required this.entry,
    required this.index,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  State<_TimelineArchiveRow> createState() => _TimelineArchiveRowState();
}

class _TimelineArchiveRowState extends State<_TimelineArchiveRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 112,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          color: _hovered ? colors.bgHover : colors.paper,
          child: Row(
            children: [
              SizedBox(
                key: ValueKey('archive-ink-timeline-${widget.index}'),
                width: 28,
                height: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              colors.sky.withValues(alpha: 0.18),
                              colors.sakura.withValues(alpha: 0.72),
                              colors.sky.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: colors.paper,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.sakura, width: 2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: Text(
                  '${widget.index + 1}'.padLeft(2, '0'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colors.textMuted,
                      ),
                ),
              ),
              SizedBox(
                width: 126,
                height: 86,
                child: CoverImage(
                  url: widget.entry.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 9),
                    _ArchiveProgress(value: widget.entry.progress),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Text(
                widget.entry.meta,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 10),
              _RemoveButton(
                title: widget.entry.title,
                onRemove: widget.onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressArchiveCard extends StatefulWidget {
  final ArchiveEntry entry;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _ProgressArchiveCard({
    required this.entry,
    required this.index,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  State<_ProgressArchiveCard> createState() => _ProgressArchiveCardState();
}

class _ProgressArchiveCardState extends State<_ProgressArchiveCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
        child: AnimatedContainer(
          key: ValueKey('archive-progress-stack-${widget.index}'),
          duration: const Duration(milliseconds: 170),
          height: 146,
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _hovered ? colors.bgHover : colors.paper,
            border: Border.all(
              color: _hovered
                  ? colors.sakura.withValues(alpha: 0.62)
                  : colors.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.sakura.withValues(alpha: 0.12),
                offset: const Offset(5, 5),
              ),
              BoxShadow(
                color: colors.sky.withValues(alpha: 0.08),
                offset: const Offset(9, 9),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 104,
                height: double.infinity,
                child: CoverImage(
                  url: widget.entry.coverUrl,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 15, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '手账 ${(widget.index + 1).toString().padLeft(2, '0')}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.sakura),
                          ),
                          const Spacer(),
                          if (widget.entry.statusLabel case final status?)
                            Text(
                              status,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: status == '连载中'
                                        ? colors.success
                                        : colors.textMuted,
                                  ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        widget.entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        widget.entry.subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Text(
                            '看到这里',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ArchiveProgress(
                              value: widget.entry.progress,
                              color: colors.sakura,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${(widget.entry.progress.clamp(0, 1) * 100).round()}%',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _RemoveButton(
                title: widget.entry.title,
                onRemove: widget.onRemove,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveProgress extends StatelessWidget {
  final double value;
  final Color? color;

  const _ArchiveProgress({required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 3,
        backgroundColor: context.colors.divider,
        valueColor: AlwaysStoppedAnimation(color ?? context.colors.sky),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final String title;
  final VoidCallback onRemove;

  const _RemoveButton({required this.title, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '移除$title',
      child: Semantics(
        button: true,
        label: '移除$title',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ),
      ),
    );
  }
}
