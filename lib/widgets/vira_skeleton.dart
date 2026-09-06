import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

/// 骨架屏基础块：bgSurface/bgCard 交替的柔和脉动。
///
/// 自动尊重 `MediaQuery.disableAnimations`（静态降级）与 `TickerMode`
/// （离屏不动画），各页面的骨架布局用多个块组合，不再各自实现脉动循环。
class ViraSkeleton extends StatefulWidget {
  const ViraSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.widthFactor,
    this.borderRadius = 6,
    this.color,
  });

  /// 固定宽度；与 [widthFactor] 二选一（都传时固定宽度优先）。
  final double? width;

  final double height;

  /// 相对父宽的比例（0-1），适合模拟长短错落的文本行。
  final double? widthFactor;

  final double borderRadius;

  /// 未点亮相位的基色，默认 bgSurface。
  final Color? color;

  @override
  State<ViraSkeleton> createState() => _ViraSkeletonState();
}

class _ViraSkeletonState extends State<ViraSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _lit = true);
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          setState(() => _lit = false);
          _controller.forward();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (disableAnimations || !tickerEnabled) {
      if (_controller.isAnimating || _controller.value != 0) {
        _controller.stop();
        _lit = false;
      }
    } else if (!_controller.isAnimating && _controller.isDismissed) {
      _controller.forward();
    }

    final colors = context.colors;
    Widget block = AnimatedContainer(
      duration: const Duration(milliseconds: 760),
      curve: Curves.easeInOut,
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: _lit ? colors.bgCard : (widget.color ?? colors.bgSurface),
        border: Border.all(color: colors.divider),
      ),
    );
    if (widget.widthFactor case final factor?) {
      block = FractionallySizedBox(
        widthFactor: factor,
        alignment: Alignment.centerLeft,
        child: block,
      );
    }
    return block;
  }
}
