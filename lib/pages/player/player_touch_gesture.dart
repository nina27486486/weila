import 'package:flutter/widgets.dart' show EdgeInsets;

/// 播放器触摸手势解析（MVP 计划 §4）：
/// - 单击视频：显示或隐藏控制层；
/// - 双击左/右三等分区：后退/前进 [playerDoubleTapSeekOffset]；
/// - 中央双击：播放/暂停。
///
/// 解析为纯函数，便于单元测试；视图层只负责把解析结果映射到动作。
enum PlayerDoubleTapZone { back, center, forward }

const Duration playerDoubleTapSeekOffset = Duration(seconds: 10);

PlayerDoubleTapZone resolveDoubleTapZone({
  required double localX,
  required double width,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  final effectiveWidth =
      (width - padding.horizontal).clamp(0.0, double.infinity).toDouble();
  final third = effectiveWidth / 3;
  final x = (localX - padding.left).clamp(0.0, effectiveWidth).toDouble();
  if (x < third) return PlayerDoubleTapZone.back;
  if (x > effectiveWidth - third) return PlayerDoubleTapZone.forward;
  return PlayerDoubleTapZone.center;
}
