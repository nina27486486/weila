part of '../player_page.dart';

class _PlaybackIssue {
  const _PlaybackIssue({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}

class _PlayerIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _PlayerIconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: _hovering && enabled ? 0.10 : 0.02),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              widget.icon,
              color: enabled
                  ? Colors.white.withValues(alpha: 0.82)
                  : Colors.white.withValues(alpha: 0.32),
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}
