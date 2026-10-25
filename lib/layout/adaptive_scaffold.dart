import 'package:flutter/material.dart';

import 'breakpoints.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.backgroundColor,
    required this.headerBuilder,
    required this.bottomNavigationBar,
    required this.child,
  });

  final Color backgroundColor;
  final Widget Function(BuildContext context, AdaptiveLayout layout)
      headerBuilder;
  final Widget bottomNavigationBar;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final layout = Breakpoints.layoutFor(constraints.maxWidth);
          final compact = layout == AdaptiveLayout.compact;
          return Scaffold(
            backgroundColor: backgroundColor,
            body: SafeArea(
              bottom: !compact,
              child: Column(
                children: [
                  headerBuilder(context, layout),
                  Expanded(child: child),
                ],
              ),
            ),
            bottomNavigationBar: compact ? bottomNavigationBar : null,
          );
        },
      );
}
