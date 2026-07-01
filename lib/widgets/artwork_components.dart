import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/artwork_palette_service.dart';
import '../theme/vira_colors.dart';
import '../utils/animations.dart';
import 'cover_image.dart';

@immutable
class ArtworkStackItem {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final double progress;

  const ArtworkStackItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.progress = 0,
  });
}

@immutable
class PosterRailItem {
  final String id;
  final String title;
  final String? imageUrl;
  final String meta;

  const PosterRailItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.meta = '',
  });
}

@immutable
class ExpandableToolTab {
  final String id;
  final IconData icon;
  final String label;
  final String tooltip;

  const ExpandableToolTab({
    required this.id,
    required this.icon,
    required this.label,
    required this.tooltip,
  });
}

class ArtworkPaletteBuilder extends StatefulWidget {
  final String cacheKey;
  final ImageProvider<Object> provider;
  final ArtworkPaletteService? service;
  final Widget Function(BuildContext context, ArtworkPalette palette) builder;

  const ArtworkPaletteBuilder({
    super.key,
    required this.cacheKey,
    required this.provider,
    required this.builder,
    this.service,
  });

  @override
  State<ArtworkPaletteBuilder> createState() => _ArtworkPaletteBuilderState();
}

class _ArtworkPaletteBuilderState extends State<ArtworkPaletteBuilder> {
  ArtworkPalette _palette = ArtworkPalette.fallback;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ArtworkPaletteBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey ||
        oldWidget.provider != widget.provider ||
        oldWidget.service != widget.service) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final generation = ++_generation;
    final palette =
        await (widget.service ?? ArtworkPaletteService.shared).resolve(
      cacheKey: widget.cacheKey,
      provider: widget.provider,
    );
    if (!mounted || generation != _generation) return;
    setState(() => _palette = palette);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _palette);
}

class AmbientArtworkBackdrop extends StatefulWidget {
  final ArtworkPalette palette;
  final Widget child;
  final bool enabled;
  final BorderRadius? borderRadius;

  const AmbientArtworkBackdrop({
    super.key,
    required this.palette,
    required this.child,
    this.enabled = true,
    this.borderRadius,
  });

  @override
  State<AmbientArtworkBackdrop> createState() => _AmbientArtworkBackdropState();
}

class _AmbientArtworkBackdropState extends State<AmbientArtworkBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AmbientArtworkBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final shouldAnimate = widget.enabled &&
        !reduceMotion &&
        tickerEnabled &&
        _lifecycle == AppLifecycleState.resumed;
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget background(double value, Key key) {
      final drift = (value - 0.5) * 26;
      return RepaintBoundary(
        key: key,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + value * 0.25, -0.9),
                  end: Alignment(0.8, 1 - value * 0.2),
                  colors: [
                    widget.palette.primary.withValues(
                      alpha: isDark ? 0.17 : 0.11,
                    ),
                    colors.paper.withValues(alpha: 0.92),
                    widget.palette.secondary.withValues(
                      alpha: isDark ? 0.13 : 0.08,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              left: drift,
              right: -drift,
              child: Opacity(
                opacity: isDark ? 0.07 : 0.045,
                child: Image.asset(
                  isDark
                      ? 'assets/textures/paper-night.webp'
                      : 'assets/textures/paper-light.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned.fill(
              left: -drift * 1.4,
              right: drift * 1.4,
              child: Opacity(
                opacity: isDark ? 0.08 : 0.055,
                child: Image.asset(
                  'assets/textures/ink-path.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final backdrop = reduceMotion || !widget.enabled
        ? background(0.5, const ValueKey('ambient-artwork-static'))
        : AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => background(
              _controller.value,
              const ValueKey('ambient-artwork-animated'),
            ),
          );

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          backdrop,
          widget.child,
        ],
      ),
    );
  }
}

class ArtworkParallax extends StatefulWidget {
  final Widget child;
  final double maxTiltRadians;

  const ArtworkParallax({
    super.key,
    required this.child,
    this.maxTiltRadians = 0.035,
  });

  @override
  State<ArtworkParallax> createState() => _ArtworkParallaxState();
}

class _ArtworkParallaxState extends State<ArtworkParallax> {
  Offset _position = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final transform = reduceMotion
            ? Matrix4.identity()
            : (Matrix4.identity()
              ..setEntry(3, 2, 0.0008)
              ..rotateX(-_position.dy * widget.maxTiltRadians)
              ..rotateY(_position.dx * widget.maxTiltRadians));
        return MouseRegion(
          onHover: (event) {
            if (reduceMotion ||
                constraints.maxWidth <= 0 ||
                constraints.maxHeight <= 0) {
              return;
            }
            setState(() {
              _position = Offset(
                (event.localPosition.dx / constraints.maxWidth - 0.5) * 2,
                (event.localPosition.dy / constraints.maxHeight - 0.5) * 2,
              );
            });
          },
          onExit: (_) {
            if (_position != Offset.zero) {
              setState(() => _position = Offset.zero);
            }
          },
          child: AnimatedContainer(
            key: const ValueKey('artwork-parallax-transform'),
            duration: reduceMotion ? Duration.zero : AppAnimations.normal,
            curve: AppAnimations.easeOut,
            transform: transform,
            transformAlignment: Alignment.center,
            child: widget.child,
          ),
        );
      },
    );
  }
}

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

class PosterRail extends StatefulWidget {
  final List<PosterRailItem> items;
  final ValueChanged<PosterRailItem> onOpen;
  final double height;

  const PosterRail({
    super.key,
    required this.items,
    required this.onOpen,
    this.height = 310,
  });

  @override
  State<PosterRail> createState() => _PosterRailState();
}

class _PosterRailState extends State<PosterRail> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('poster-rail'),
      height: widget.height,
      child: Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          if (!_controller.hasClients) return;
          final position = _controller.position;
          final delta = event.scrollDelta.dy == 0
              ? event.scrollDelta.dx
              : event.scrollDelta.dy;
          position.jumpTo(
            (position.pixels + delta)
                .clamp(position.minScrollExtent, position.maxScrollExtent),
          );
        },
        child: ScrollConfiguration(
          behavior: const _DesktopDragScrollBehavior(),
          child: ListView.separated(
            controller: _controller,
            padding: const EdgeInsets.symmetric(vertical: 8),
            scrollDirection: Axis.horizontal,
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _PosterRailCard(
                item: item,
                index: index,
                onOpen: () => widget.onOpen(item),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PosterRailCard extends StatefulWidget {
  final PosterRailItem item;
  final int index;
  final VoidCallback onOpen;

  const _PosterRailCard({
    required this.item,
    required this.index,
    required this.onOpen,
  });

  @override
  State<_PosterRailCard> createState() => _PosterRailCardState();
}

class _PosterRailCardState extends State<_PosterRailCard> {
  var _hovered = false;
  var _focused = false;

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    setState(() => _hovered = hovered);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 188,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: AnimatedContainer(
          key: ValueKey('poster-card-${widget.index}'),
          duration: AppAnimations.fast,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.paper,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onOpen,
                  onFocusChange: (focused) {
                    setState(() => _focused = focused);
                  },
                  borderRadius: BorderRadius.circular(16),
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  splashColor: colors.sky.withValues(alpha: 0.12),
                  highlightColor: colors.sky.withValues(alpha: 0.08),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          key: ValueKey('poster-cover-${widget.index}'),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(15),
                            bottom: Radius.circular(8),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CoverImage(url: widget.item.imageUrl),
                              Positioned(
                                left: 10,
                                top: 10,
                                child: Container(
                                  key: ValueKey(
                                    'poster-rank-pill-${widget.index}',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.paper.withValues(alpha: 0.88),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: colors.divider.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${widget.index + 1}'.padLeft(2, '0'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colors.sky,
                                          fontWeight: FontWeight.w700,
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
                              widget.item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (widget.item.meta.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                widget.item.meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_focused)
                IgnorePointer(
                  key: ValueKey('poster-focus-ring-${widget.index}'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.sky, width: 2),
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

class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const _DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class ExpandableToolTabs extends StatelessWidget {
  final List<ExpandableToolTab> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final Color? foregroundColor;
  final Color? selectedColor;

  const ExpandableToolTabs({
    super.key,
    required this.items,
    required this.onSelected,
    this.selectedId,
    this.foregroundColor,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _ExpandableToolTabButton(
              item: item,
              selected: selectedId == item.id,
              foregroundColor: foregroundColor,
              selectedColor: selectedColor,
              onPressed: () => onSelected(item.id),
            ),
          ),
      ],
    );
  }
}

class _ExpandableToolTabButton extends StatefulWidget {
  final ExpandableToolTab item;
  final bool selected;
  final Color? foregroundColor;
  final Color? selectedColor;
  final VoidCallback onPressed;

  const _ExpandableToolTabButton({
    required this.item,
    required this.selected,
    required this.foregroundColor,
    required this.selectedColor,
    required this.onPressed,
  });

  @override
  State<_ExpandableToolTabButton> createState() =>
      _ExpandableToolTabButtonState();
}

class _ExpandableToolTabButtonState extends State<_ExpandableToolTabButton> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final expanded = _hovered || _focused || widget.selected;
    final foreground = widget.selected
        ? (widget.selectedColor ?? colors.sky)
        : (widget.foregroundColor ?? colors.textSecondary);

    return Tooltip(
      message: widget.item.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          child: Semantics(
            button: true,
            selected: widget.selected,
            label: widget.item.tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                curve: AppAnimations.easeOut,
                height: 36,
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 11 : 9,
                ),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? foreground.withValues(alpha: 0.16)
                      : _hovered
                          ? foreground.withValues(alpha: 0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: expanded
                        ? foreground.withValues(alpha: 0.28)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.item.icon, size: 18, color: foreground),
                    AnimatedSize(
                      duration: AppAnimations.fast,
                      curve: AppAnimations.easeOut,
                      child: expanded
                          ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                widget.item.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: foreground,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
