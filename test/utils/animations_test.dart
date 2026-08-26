import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/utils/animations.dart';

Widget _host({bool disableAnimations = false, Duration delay = Duration.zero}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      home: Scaffold(
        body: FadeSlideIn(
          delay: delay,
          child: const Text('入场内容'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('FadeSlideIn 完成后内容完全可见', (tester) async {
    await tester.pumpWidget(_host());

    // 初始帧：透明度为 0。
    var opacity = tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
        .opacity;
    expect(opacity, 0.0);

    // 推进动画时长后：透明度为 1。
    await tester.pump(AppAnimations.normal);
    await tester.pumpAndSettle();
    opacity = tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
        .opacity;
    expect(opacity, 1.0);
    expect(find.text('入场内容'), findsOneWidget);
  });

  testWidgets('FadeSlideIn 尊重 delay 延迟', (tester) async {
    const delay = Duration(milliseconds: 200);
    await tester.pumpWidget(_host(delay: delay));

    // delay 未到：仍不可见。
    await tester.pump(const Duration(milliseconds: 100));
    var opacity = tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
        .opacity;
    expect(opacity, 0.0);

    // 越过 delay 并完成动画：可见。
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    opacity = tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
        .opacity;
    expect(opacity, 1.0);
  });

  testWidgets('disableAnimations 时直接展示内容不做动画', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));
    // 推进时钟，让 initState 调度的零延迟回调走完，避免悬挂 Timer。
    await tester.pump(const Duration(milliseconds: 300));

    // 直接渲染 child，没有 AnimatedOpacity 包装。
    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(find.text('入场内容'), findsOneWidget);
  });
}
