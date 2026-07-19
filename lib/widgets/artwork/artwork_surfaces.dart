import 'package:flutter/material.dart';

import '../../services/artwork_palette_service.dart';
import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';

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
