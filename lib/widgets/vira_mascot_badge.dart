import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

class ViraMascotBadge extends StatelessWidget {
  final double size;
  final double borderRadius;

  const ViraMascotBadge({
    super.key,
    this.size = 42,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.paper,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.78),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.sky.withValues(alpha: 0.18),
            blurRadius: size >= 40 ? 16 : 12,
            offset: Offset(0, size >= 40 ? 6 : 4),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/weila_brand_badge.webp',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            '薇',
            style: TextStyle(
              color: colors.sky,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
