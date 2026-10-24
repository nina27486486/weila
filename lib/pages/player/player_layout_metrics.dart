/// 播放器顶部工具栏的自适应宽度。
///
/// 桌面保持 360 逻辑像素；窄屏（手机竖屏等）按屏幕宽度的 55% 收缩，
/// 下限 160，避免固定宽度在 360dp 屏上挤爆顶栏。
double playerTopToolbarWidthFor(double screenWidth) {
  final byScreen = screenWidth * 0.55;
  if (byScreen >= 360) return 360;
  if (byScreen <= 160) return 160;
  return byScreen;
}
