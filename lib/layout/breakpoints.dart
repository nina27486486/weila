enum AdaptiveLayout { compact, medium, expanded }

abstract final class Breakpoints {
  static const double compact = 600;
  static const double medium = 840;

  static AdaptiveLayout layoutFor(double width) => switch (width) {
        < compact => AdaptiveLayout.compact,
        < medium => AdaptiveLayout.medium,
        _ => AdaptiveLayout.expanded,
      };
}
