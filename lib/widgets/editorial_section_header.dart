import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/vira_colors.dart';

class EditorialSectionHeader extends StatelessWidget {
  final String chapter;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EditorialSectionHeader({
    super.key,
    required this.chapter,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 3,
          height: 42,
          margin: const EdgeInsets.only(right: 12, bottom: 2),
          color: colors.sky,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapter,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.sky,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
              ),
              const SizedBox(height: 3),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 3,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontFamily: AppTheme.editorialFontFamily,
                          fontFamilyFallback: AppTheme.editorialFontFallback,
                        ),
                  ),
                  if (subtitle case final value?)
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (actionLabel case final label?)
          _HeaderAction(label: label, onTap: onAction),
      ],
    );
  }
}

class _HeaderAction extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const _HeaderAction({required this.label, this.onTap});

  @override
  State<_HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<_HeaderAction> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        color: _hovered ? colors.sky : colors.textSecondary,
                      ),
                  child: Text(widget.label),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: _hovered ? colors.sky : colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
