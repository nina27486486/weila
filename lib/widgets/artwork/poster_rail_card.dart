part of 'poster_rail.dart';

class _PosterRailCard extends StatelessWidget {
  final PosterRailItem item;
  final int index;
  final VoidCallback onOpen;

  const _PosterRailCard({
    required this.item,
    required this.index,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semanticLabel =
        item.meta.isEmpty ? item.title : '${item.title}，${item.meta}';
    return SizedBox(
      width: 188,
      child: ArtworkCardSurface(
        id: 'poster-$index',
        semanticLabel: semanticLabel,
        onOpen: onOpen,
        contentBuilder: (context, interaction) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                key: ValueKey('poster-cover-$index'),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                  bottom: Radius.circular(8),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedScale(
                      key: ValueKey('poster-cover-scale-$index'),
                      duration: interaction.duration,
                      curve: Curves.easeOutCubic,
                      scale: interaction.coverScale,
                      child: CoverImage(url: item.imageUrl),
                    ),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: ArtworkCardBadge(
                        key: ValueKey('poster-rank-pill-$index'),
                        child: Text(
                          '${index + 1}'.padLeft(2, '0'),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.sky,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: colors.textPrimary),
                  ),
                  if (item.meta.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
