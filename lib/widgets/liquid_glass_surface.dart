import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

/// A lightweight Liquid Glass-inspired material for navigation and controls.
///
/// The blur radius is static. [motionProgress] only moves the specular
/// highlight and adjusts its opacity, so callers can share one controller
/// across multiple surfaces.
class LiquidGlassSurface extends StatelessWidget {
  const LiquidGlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.motionProgress = 0,
    this.phase = 0,
    this.padding = EdgeInsets.zero,
    this.blurSigma = 14,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double motionProgress;
  final double phase;
  final EdgeInsets padding;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final progress = (motionProgress + phase) % 1;
    final travel = progress * 2.4 - 1.2;
    final pulse = 1 - (progress * 2 - 1).abs();

    final topColor = dark
        ? colors.paper.withValues(alpha: 0.84)
        : Colors.white.withValues(alpha: 0.84);
    final bottomColor = dark
        ? colors.bgCard.withValues(alpha: 0.72)
        : colors.paper.withValues(alpha: 0.7);
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.82);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.26 : 0.1),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            if (!dark)
              BoxShadow(
                color: colors.sky.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [topColor, bottomColor],
                ),
                border: Border.all(color: borderColor),
              ),
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FractionalTranslation(
                        key: const ValueKey('liquid-glass-highlight'),
                        translation: Offset(travel, 0),
                        child: Opacity(
                          opacity: 0.16 + pulse * 0.09,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [0.18, 0.5, 0.82],
                                colors: [
                                  Colors.transparent,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
