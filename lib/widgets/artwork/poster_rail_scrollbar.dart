part of 'poster_rail.dart';

const double _posterRailScrollbarExtent = 48;
const double _posterRailScrollbarTrackHeight = 12;
const double _posterRailScrollbarThumbVisualHeight = 10;
const double _posterRailScrollbarMascotSize = 40;
const double _posterRailScrollbarMinThumbWidth = 96;

class _MascotRailScrollbar extends StatefulWidget {
  final ScrollController controller;

  const _MascotRailScrollbar({required this.controller});

  @override
  State<_MascotRailScrollbar> createState() => _MascotRailScrollbarState();
}

class _PosterRailScrollIntent extends Intent {
  final double direction;

  const _PosterRailScrollIntent(this.direction);
}

class _MascotRailScrollbarState extends State<_MascotRailScrollbar> {
  final FocusNode _focusNode = FocusNode();
  var _hovered = false;
  var _focused = false;
  var _dragging = false;
  double? _pendingAnimatedTarget;
  var _animationGeneration = 0;
  bool? _lastMotionEnabled;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleScrollChange);
    _refreshAfterLayout();
  }

  @override
  void didUpdateWidget(covariant _MascotRailScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleScrollChange);
      widget.controller.addListener(_handleScrollChange);
    }
    _refreshAfterLayout();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motionEnabled =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_lastMotionEnabled == true && !motionEnabled) {
      final hadActiveAnimation = _pendingAnimatedTarget != null;
      _invalidatePendingAnimatedTarget();
      if (hadActiveAnimation) {
        _stopActiveAnimationAfterFrame();
      }
    }
    _lastMotionEnabled = motionEnabled;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleScrollChange);
    _invalidatePendingAnimatedTarget();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleScrollChange() {
    if (!mounted) return;
    setState(() {});
  }

  void _refreshAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleScrollChange();
    });
  }

  void _scrollTo(double target, {required bool motionEnabled}) {
    if (!mounted || !widget.controller.hasClients) return;
    final position = widget.controller.position;
    final destination = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (motionEnabled) {
      final generation = ++_animationGeneration;
      _pendingAnimatedTarget = destination;
      final animation = position.animateTo(
        destination,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      unawaited(
        animation.then<void>(
          (_) => _completePendingAnimatedTarget(destination, generation),
          onError: (Object _, StackTrace __) {
            _completePendingAnimatedTarget(destination, generation);
          },
        ),
      );
    } else {
      _invalidatePendingAnimatedTarget();
      position.jumpTo(destination);
    }
  }

  void _invalidatePendingAnimatedTarget() {
    _animationGeneration += 1;
    _pendingAnimatedTarget = null;
  }

  void _stopActiveAnimationAfterFrame() {
    final generation = _animationGeneration;
    final controller = widget.controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _animationGeneration ||
          !identical(widget.controller, controller) ||
          !controller.hasClients) {
        return;
      }
      final position = controller.position;
      position.jumpTo(position.pixels);
    });
  }

  void _completePendingAnimatedTarget(double destination, int generation) {
    if (!mounted ||
        generation != _animationGeneration ||
        _pendingAnimatedTarget != destination) {
      return;
    }
    _pendingAnimatedTarget = null;
  }

  void _pageBy(double direction, {required bool motionEnabled}) {
    if (!mounted || !widget.controller.hasClients) return;
    final position = widget.controller.position;
    if (!position.hasContentDimensions ||
        position.maxScrollExtent <= precisionErrorTolerance) {
      return;
    }
    final base = motionEnabled
        ? _pendingAnimatedTarget ?? position.pixels
        : position.pixels;
    _scrollTo(
      base + direction * position.viewportDimension / 2,
      motionEnabled: motionEnabled,
    );
  }

  void _dragBy(double delta, double travel, double maxScrollExtent) {
    if (!widget.controller.hasClients ||
        travel <= precisionErrorTolerance ||
        maxScrollExtent <= precisionErrorTolerance) {
      return;
    }
    final position = widget.controller.position;
    _invalidatePendingAnimatedTarget();
    position.jumpTo(
      (position.pixels + delta / travel * maxScrollExtent).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionEnabled =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        var thumbWidth = trackWidth;
        var thumbLeft = 0.0;
        var maxScrollExtent = 0.0;
        var isScrollable = false;
        var scrollProgress = 0.0;
        final showMascot = trackWidth >= _posterRailScrollbarMascotSize + 4;

        if (widget.controller.hasClients) {
          final position = widget.controller.position;
          if (position.hasContentDimensions) {
            final viewport = position.viewportDimension;
            maxScrollExtent = position.maxScrollExtent;
            final contentExtent = viewport + maxScrollExtent;
            isScrollable = maxScrollExtent > precisionErrorTolerance;

            if (isScrollable && contentExtent > precisionErrorTolerance) {
              final proportionalWidth = trackWidth * viewport / contentExtent;
              final minThumbWidth = math.min(
                _posterRailScrollbarMinThumbWidth,
                trackWidth,
              );
              thumbWidth =
                  proportionalWidth.clamp(minThumbWidth, trackWidth).toDouble();
              final travel = math.max(0.0, trackWidth - thumbWidth);
              final progress =
                  (position.pixels / maxScrollExtent).clamp(0.0, 1.0);
              scrollProgress = progress;
              thumbLeft = travel * progress;
            }
          }
        }
        final travel = math.max(0.0, trackWidth - thumbWidth);
        final active = isScrollable && (_hovered || _focused || _dragging);

        return SizedBox(
          key: const ValueKey('poster-rail-scrollbar'),
          height: _posterRailScrollbarExtent,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: isScrollable
                    ? (details) {
                        final x = details.localPosition.dx;
                        if (x >= thumbLeft && x <= thumbLeft + thumbWidth) {
                          return;
                        }
                        final progress =
                            ((x - thumbWidth / 2) / travel).clamp(0.0, 1.0);
                        _scrollTo(
                          progress * maxScrollExtent,
                          motionEnabled: motionEnabled,
                        );
                      }
                    : null,
                child: _PosterRailScrollTrack(isDark: isDark),
              ),
              Positioned(
                key: const ValueKey('poster-rail-scroll-thumb'),
                left: thumbLeft,
                width: thumbWidth,
                height: 44,
                child: MouseRegion(
                  cursor: isScrollable
                      ? (_dragging
                          ? SystemMouseCursors.grabbing
                          : SystemMouseCursors.grab)
                      : SystemMouseCursors.basic,
                  onEnter: isScrollable
                      ? (_) => setState(() => _hovered = true)
                      : null,
                  onExit: isScrollable
                      ? (_) => setState(() => _hovered = false)
                      : null,
                  child: FocusableActionDetector(
                    enabled: isScrollable,
                    focusNode: _focusNode,
                    includeFocusSemantics: false,
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.arrowRight):
                          _PosterRailScrollIntent(1),
                      SingleActivator(LogicalKeyboardKey.arrowLeft):
                          _PosterRailScrollIntent(-1),
                    },
                    actions: {
                      _PosterRailScrollIntent:
                          CallbackAction<_PosterRailScrollIntent>(
                        onInvoke: (intent) {
                          _pageBy(
                            intent.direction,
                            motionEnabled: motionEnabled,
                          );
                          return null;
                        },
                      ),
                    },
                    onFocusChange: (value) => setState(() => _focused = value),
                    child: Semantics(
                      container: true,
                      excludeSemantics: true,
                      slider: true,
                      enabled: isScrollable,
                      focusable: isScrollable,
                      focused: isScrollable ? _focused : null,
                      label: '拖动浏览本季作品',
                      value: '${(scrollProgress * 100).round()}%',
                      increasedValue: isScrollable ? '向后浏览' : null,
                      decreasedValue: isScrollable ? '向前浏览' : null,
                      onFocus: isScrollable ? _focusNode.requestFocus : null,
                      onIncrease: isScrollable
                          ? () => _pageBy(
                                1,
                                motionEnabled: motionEnabled,
                              )
                          : null,
                      onDecrease: isScrollable
                          ? () => _pageBy(
                                -1,
                                motionEnabled: motionEnabled,
                              )
                          : null,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: isScrollable
                            ? (_) => _focusNode.requestFocus()
                            : null,
                        onHorizontalDragStart: isScrollable
                            ? (_) {
                                _focusNode.requestFocus();
                                setState(() => _dragging = true);
                              }
                            : null,
                        onHorizontalDragUpdate: isScrollable
                            ? (details) => _dragBy(
                                  details.delta.dx,
                                  travel,
                                  maxScrollExtent,
                                )
                            : null,
                        onHorizontalDragEnd: isScrollable
                            ? (_) => setState(() => _dragging = false)
                            : null,
                        onHorizontalDragCancel: isScrollable
                            ? () => setState(() => _dragging = false)
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerLeft,
                          children: [
                            _PosterRailScrollThumbVisual(
                              active: active,
                              isDark: isDark,
                              motionEnabled: motionEnabled,
                            ),
                            if (showMascot) const _PosterRailScrollbarMascot(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
