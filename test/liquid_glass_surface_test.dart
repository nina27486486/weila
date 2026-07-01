import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/liquid_glass_surface.dart';

void main() {
  testWidgets('LiquidGlassSurface 提供静态模糊与可移动高光', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: LiquidGlassSurface(
              motionProgress: 0.25,
              phase: 0.1,
              borderRadius: BorderRadius.circular(24),
              child: const Text('导航'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      find.byKey(const ValueKey('liquid-glass-highlight')),
      findsOneWidget,
    );
    expect(find.text('导航'), findsOneWidget);
  });
}
