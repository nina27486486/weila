import 'package:flutter/material.dart';

@immutable
class ArtworkStackItem {
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final double progress;

  const ArtworkStackItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.progress = 0,
  });
}

@immutable
class PosterRailItem {
  final String id;
  final String title;
  final String? imageUrl;
  final String meta;

  const PosterRailItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.meta = '',
  });
}

@immutable
class ArtworkCardInteraction {
  final bool active;
  final bool motionEnabled;
  final Duration duration;

  const ArtworkCardInteraction({
    required this.active,
    required this.motionEnabled,
    required this.duration,
  });

  double get coverScale => motionEnabled && active ? 1.025 : 1;
}

typedef ArtworkCardContentBuilder = Widget Function(
  BuildContext context,
  ArtworkCardInteraction interaction,
);

@immutable
class ExpandableToolTab {
  final String id;
  final IconData icon;
  final String label;
  final String tooltip;

  const ExpandableToolTab({
    required this.id,
    required this.icon,
    required this.label,
    required this.tooltip,
  });
}
