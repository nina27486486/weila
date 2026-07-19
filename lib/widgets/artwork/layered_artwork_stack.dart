import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';
import '../cover_image.dart';
import 'artwork_models.dart';

class LayeredArtworkStack extends StatefulWidget {
  final List<ArtworkStackItem> items;
  final ValueChanged<ArtworkStackItem> onOpen;
  final int groupSize;

  const LayeredArtworkStack({
    super.key,
    required this.items,
    required this.onOpen,
    this.groupSize = 3,
  });

  @override
  State<LayeredArtworkStack> createState() => _LayeredArtworkStackState();
}

class _LayeredArtworkStackState extends State<LayeredArtworkStack> {
  final FocusNode _focusNode = FocusNode();
  var _start = 0;

  int get _groupCount => widget.items.isEmpty
      ? 0
      : (widget.items.length / widget.groupSize).ceil();
  int get _group => _groupCount == 0 ? 0 : _start ~/ widget.groupSize;

  @override
  void didUpdateWidget(covariant LayeredArtworkStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_start >= widget.items.length) {
      _start = 0;
    }
  }

  void _move(int delta) {
    if (_groupCount <= 1) return;
    final next = (_group + delta) % _groupCount;
    setState(() {
      _start = (next < 0 ? next + _groupCount : next) * widget.groupSize;
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _move(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final visible = widget.items
        .skip(_start)
        .take(widget.groupSize)
        .toList(growable: false);

    return Focus(
      key: const ValueKey('layered-artwork-stack'),
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Semantics(
        label: '继续观看故事组',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusNode.requestFocus,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 80) return;
            _move(velocity < 0 ? 1 : -1);
          },
          child: Column(
            children: [
              SizedBox(
                height: 204,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 720;
                    final cardWidth = compact
                        ? constraints.maxWidth - 28
                        : (constraints.maxWidth - 56) / visible.length;
                    final stride = compact
                        ? 14.0
                        : (constraints.maxWidth - cardWidth) /
                            (visible.length == 1 ? 1 : visible.length - 1);
                    return AnimatedSwitcher(
                      duration: AppAnimations.normal,
                      switchInCurve: AppAnimations.easeOut,
                      switchOutCurve: AppAnimations.easeIn,
                      child: Stack(
                        key: ValueKey(_start),
                        clipBehavior: Clip.none,
                        children: [
                          for (var index = visible.length - 1;
                              index >= 0;
                              index--)
                            Positioned(
                              left: stride * index,
                              top: compact ? index * 5 : index * 3,
                              bottom:
                                  compact ? (visible.length - index) * 5 : 0,
                              width: cardWidth,
                              child: _ArtworkStackCard(
                                item: visible[index],
                                onOpen: () => widget.onOpen(visible[index]),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_groupCount > 1) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StackNavigationButton(
                      tooltip: '上一组',
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => _move(-1),
                    ),
                    const SizedBox(width: 12),
                    for (var index = 0; index < _groupCount; index++)
                      AnimatedContainer(
                        duration: AppAnimations.fast,
                        width: index == _group ? 22 : 6,
                        height: 3,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        color: index == _group
                            ? context.colors.sky
                            : context.colors.divider,
                      ),
                    const SizedBox(width: 12),
                    _StackNavigationButton(
                      tooltip: '下一组',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => _move(1),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtworkStackCard extends StatefulWidget {
  final ArtworkStackItem item;
  final VoidCallback onOpen;

  const _ArtworkStackCard({required this.item, required this.onOpen});

  @override
  State<_ArtworkStackCard> createState() => _ArtworkStackCardState();
}

class _ArtworkStackCardState extends State<_ArtworkStackCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: AppAnimations.fast,
          transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.paper,
            border: Border.all(
              color: _hovered
                  ? colors.sky.withValues(alpha: 0.64)
                  : colors.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(
                  alpha: _hovered ? 0.12 : 0.06,
                ),
                blurRadius: _hovered ? 24 : 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 112,
                child: CoverImage(
                  url: widget.item.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 16, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      LinearProgressIndicator(
                        minHeight: 3,
                        value: widget.item.progress.clamp(0, 1),
                        backgroundColor: colors.divider,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors.sakura),
                      ),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_fill_rounded,
                            size: 18,
                            color: colors.sky,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '继续观看',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colors.sky,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackNavigationButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _StackNavigationButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
    );
  }
}
