import 'package:flutter/material.dart';

import '../theme/vira_colors.dart';

class ViraTextTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const ViraTextTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var index = 0; index < labels.length; index++)
          _TextTab(
            label: labels[index],
            selected: index == selectedIndex,
            indicatorKey: ValueKey('vira-tab-indicator-$index'),
            onTap: () => onSelected(index),
          ),
      ],
    );
  }
}

class _TextTab extends StatefulWidget {
  final String label;
  final bool selected;
  final Key indicatorKey;
  final VoidCallback onTap;

  const _TextTab({
    required this.label,
    required this.selected,
    required this.indicatorKey,
    required this.onTap,
  });

  @override
  State<_TextTab> createState() => _TextTabState();
}

class _TextTabState extends State<_TextTab> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        color: widget.selected || _hovered
                            ? colors.sky
                            : colors.textSecondary,
                      ),
                  child: Text(widget.label),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  key: widget.selected ? widget.indicatorKey : null,
                  duration: const Duration(milliseconds: 160),
                  width: widget.selected ? 20 : 0,
                  height: 2,
                  color: colors.sky,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
