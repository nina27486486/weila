import 'package:flutter/material.dart';

class PlayerBackScope extends StatelessWidget {
  const PlayerBackScope({
    super.key,
    required this.fullscreen,
    required this.hasOpenPanel,
    required this.hasOpenDrawer,
    required this.onClosePanel,
    required this.onCloseDrawer,
    required this.onExitFullscreen,
    required this.child,
  });

  final bool fullscreen;
  final bool hasOpenPanel;
  final bool hasOpenDrawer;
  final VoidCallback onClosePanel;
  final VoidCallback onCloseDrawer;
  final VoidCallback onExitFullscreen;
  final Widget child;

  static void requestBack(
    BuildContext context, {
    required VoidCallback onDesktopBack,
  }) {
    if (Theme.of(context).platform == TargetPlatform.android) {
      Navigator.of(context).maybePop();
    } else {
      onDesktopBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.android) return child;
    return PopScope<void>(
      canPop: !hasOpenPanel && !hasOpenDrawer && !fullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (hasOpenPanel) {
          onClosePanel();
        } else if (hasOpenDrawer) {
          onCloseDrawer();
        } else if (fullscreen) {
          onExitFullscreen();
        }
      },
      child: child,
    );
  }
}
