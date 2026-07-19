import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/vira_colors.dart';
import '../../utils/animations.dart';
import '../cover_image.dart';
import 'artwork_card.dart';
import 'artwork_models.dart';

part 'poster_rail_card.dart';
part 'poster_rail_scroll_behavior.dart';
part 'poster_rail_scrollbar.dart';
part 'poster_rail_scrollbar_view.dart';

class PosterRail extends StatefulWidget {
  final List<PosterRailItem> items;
  final ValueChanged<PosterRailItem> onOpen;
  final double height;

  const PosterRail({
    super.key,
    required this.items,
    required this.onOpen,
    this.height = 310,
  });

  @override
  State<PosterRail> createState() => _PosterRailState();
}

class _PosterRailState extends State<PosterRail> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('poster-rail'),
      height: widget.height + _posterRailScrollbarExtent,
      child: Column(
        children: [
          SizedBox(
            key: const ValueKey('poster-rail-card-stage'),
            height: widget.height,
            child: Listener(
              onPointerSignal: (event) {
                if (event is! PointerScrollEvent) return;
                if (!_controller.hasClients) return;
                final position = _controller.position;
                final delta = event.scrollDelta.dy == 0
                    ? event.scrollDelta.dx
                    : event.scrollDelta.dy;
                position.jumpTo(
                  (position.pixels + delta).clamp(
                      position.minScrollExtent, position.maxScrollExtent),
                );
              },
              child: ScrollConfiguration(
                behavior: const _DesktopDragScrollBehavior(),
                child: ListView.separated(
                  controller: _controller,
                  padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
                  clipBehavior: Clip.none,
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return _PosterRailCard(
                      item: item,
                      index: index,
                      onOpen: () => widget.onOpen(item),
                    );
                  },
                ),
              ),
            ),
          ),
          SizedBox(
            height: _posterRailScrollbarExtent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _MascotRailScrollbar(controller: _controller),
            ),
          ),
        ],
      ),
    );
  }
}
