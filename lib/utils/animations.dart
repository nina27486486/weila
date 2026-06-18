import 'package:flutter/material.dart';

/// 薇拉动画工具集
class AppAnimations {
  // 时长
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration stagger = Duration(milliseconds: 80);

  // 曲线
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve bounce = Curves.easeOutBack;
  static const Curve smooth = Curves.easeInOutCubic;
}

/// 淡入滑入包装器 - 单个元素入场动画
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.beginOffset = const Offset(0, 0.1),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: widget.duration,
      curve: AppAnimations.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.beginOffset,
        duration: widget.duration,
        curve: AppAnimations.easeOut,
        child: widget.child,
      ),
    );
  }
}
