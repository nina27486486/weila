import 'package:flutter/material.dart';

import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';
import 'artwork_models.dart';

class ArtworkCardSurface extends StatefulWidget {
  final String id;
  final String semanticLabel;
  final VoidCallback onOpen;
  final ArtworkCardContentBuilder contentBuilder;
  final Widget? foreground;
  final double lift;
  final double borderRadius;

  const ArtworkCardSurface({
    super.key,
    required this.id,
    required this.semanticLabel,
    required this.onOpen,
    required this.contentBuilder,
    this.foreground,
    this.lift = 6,
    this.borderRadius = 16,
  });

  @override
  State<ArtworkCardSurface> createState() => _ArtworkCardSurfaceState();
}

class _ArtworkCardSurfaceState extends State<ArtworkCardSurface> {
  var _hovered = false;
  var _focused = false;

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    setState(() => _hovered = hovered);
  }

  void _setFocused(bool focused) {
    if (_focused == focused) return;
    setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final motionEnabled =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    final active = _hovered || _focused;
    final duration = motionEnabled ? AppAnimations.fast : Duration.zero;
    final interaction = ArtworkCardInteraction(
      active: active,
      motionEnabled: motionEnabled,
      duration: duration,
    );
    final radius = BorderRadius.circular(widget.borderRadius);

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Padding(
        padding: EdgeInsets.only(top: widget.lift),
        child: AnimatedContainer(
          key: ValueKey('artwork-card-${widget.id}'),
          duration: duration,
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
            0,
            motionEnabled && active ? -widget.lift : 0,
            0,
          ),
          transformAlignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [
                      colors.paper.withValues(alpha: 0.96),
                      colors.bgCard.withValues(alpha: 0.90),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.96),
                      colors.paper.withValues(alpha: 0.90),
                    ],
            ),
            border: Border.all(
              color: active
                  ? colors.sky.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: dark ? 0.20 : 0.82),
              width: active ? 1.4 : 1,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(
                  alpha: active ? 0.16 : 0.08,
                ),
                blurRadius: active ? 28 : 18,
                offset: Offset(0, active ? 13 : 8),
              ),
              BoxShadow(
                color: colors.sky.withValues(
                  alpha: active ? 0.14 : 0.06,
                ),
                blurRadius: active ? 20 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: widget.contentBuilder(context, interaction),
              ),
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: widget.semanticLabel,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('artwork-card-action-${widget.id}'),
                      onTap: widget.onOpen,
                      mouseCursor: SystemMouseCursors.click,
                      onFocusChange: _setFocused,
                      borderRadius: radius,
                      hoverColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      splashColor: colors.sky.withValues(alpha: 0.12),
                      highlightColor: colors.sky.withValues(alpha: 0.08),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              if (_focused)
                IgnorePointer(
                  key: ValueKey('artwork-card-focus-${widget.id}'),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(color: colors.sky, width: 2),
                    ),
                  ),
                ),
              if (widget.foreground case final foreground?) foreground,
            ],
          ),
        ),
      ),
    );
  }
}

class ArtworkCardBadge extends StatelessWidget {
  final Widget child;
  final bool dark;
  final EdgeInsetsGeometry padding;

  const ArtworkCardBadge({
    super.key,
    required this.child,
    this.dark = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? Colors.black.withValues(alpha: 0.62)
            : colors.paper.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.22 : 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
