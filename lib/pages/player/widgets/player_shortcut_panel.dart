import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class PlayerShortcutPanel extends StatelessWidget {
  final VoidCallback onClose;

  const PlayerShortcutPanel({
    super.key,
    required this.onClose,
  });

  static const _shortcuts = [
    ('空格', '播放 / 暂停'),
    ('← / →', '快退 / 快进 5 秒'),
    ('↑ / ↓', '音量调节'),
    ('D', '显示 / 隐藏弹幕'),
    ('F', '进入 / 退出全屏'),
    ('/', '打开快捷键面板'),
    ('Esc', '关闭面板 / 退出全屏'),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '播放器快捷键面板',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 460,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1420).withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        Icons.keyboard_command_key_rounded,
                        color: AppTheme.primaryBlue,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '快捷键',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '桌面观看时可以直接用键盘控制播放',
                            style: TextStyle(
                              color: Color(0xFF8C99AA),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭快捷键面板',
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.64),
                        size: 19,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(36, 36),
                        fixedSize: const Size(36, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ).copyWith(
                        mouseCursor:
                            WidgetStateProperty.all(SystemMouseCursors.click),
                        overlayColor: WidgetStateProperty.all(
                          Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ..._shortcuts.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        _ShortcutKeycap(label: item.$1),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            item.$2,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutKeycap extends StatelessWidget {
  final String label;

  const _ShortcutKeycap({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.11),
            Colors.white.withValues(alpha: 0.055),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
