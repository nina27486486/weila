import 'package:flutter/material.dart';

import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';
import 'artwork_models.dart';

class ExpandableToolTabs extends StatelessWidget {
  final List<ExpandableToolTab> items;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final Color? foregroundColor;
  final Color? selectedColor;

  const ExpandableToolTabs({
    super.key,
    required this.items,
    required this.onSelected,
    this.selectedId,
    this.foregroundColor,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _ExpandableToolTabButton(
              item: item,
              selected: selectedId == item.id,
              foregroundColor: foregroundColor,
              selectedColor: selectedColor,
              onPressed: () => onSelected(item.id),
            ),
          ),
      ],
    );
  }
}

class _ExpandableToolTabButton extends StatefulWidget {
  final ExpandableToolTab item;
  final bool selected;
  final Color? foregroundColor;
  final Color? selectedColor;
  final VoidCallback onPressed;

  const _ExpandableToolTabButton({
    required this.item,
    required this.selected,
    required this.foregroundColor,
    required this.selectedColor,
    required this.onPressed,
  });

  @override
  State<_ExpandableToolTabButton> createState() =>
      _ExpandableToolTabButtonState();
}

class _ExpandableToolTabButtonState extends State<_ExpandableToolTabButton> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final expanded = _hovered || _focused || widget.selected;
    final foreground = widget.selected
        ? (widget.selectedColor ?? colors.sky)
        : (widget.foregroundColor ?? colors.textSecondary);

    return Tooltip(
      message: widget.item.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          child: Semantics(
            button: true,
            selected: widget.selected,
            label: widget.item.tooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onPressed,
              child: AnimatedContainer(
                duration: AppAnimations.fast,
                curve: AppAnimations.easeOut,
                height: 36,
                padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 11 : 9,
                ),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? foreground.withValues(alpha: 0.16)
                      : _hovered
                          ? foreground.withValues(alpha: 0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: expanded
                        ? foreground.withValues(alpha: 0.28)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.item.icon, size: 18, color: foreground),
                    AnimatedSize(
                      duration: AppAnimations.fast,
                      curve: AppAnimations.easeOut,
                      child: expanded
                          ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                widget.item.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: foreground,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
