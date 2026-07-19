import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/danmaku_item.dart';
import 'package:weila/widgets/danmaku_overlay.dart';

void main() {
  test('frame delta tracker uses the interval between animation ticks', () {
    final start = DateTime.utc(2026, 7, 15, 12);
    final tracker = DanmakuFrameDeltaTracker(start);

    expect(
      tracker.consume(start.add(const Duration(milliseconds: 16))),
      closeTo(0.016, 0.0001),
    );
    expect(
      tracker.consume(start.add(const Duration(milliseconds: 32))),
      closeTo(0.016, 0.0001),
    );
    expect(
      tracker.consume(start.add(const Duration(seconds: 1))),
      0.1,
    );
  });

  testWidgets('tracks queue, unique emission, and successful paint counts',
      (tester) async {
    final controller = DanmakuController();
    controller.loadDanmaku([
      DanmakuItem(text: 'zero', time: 0),
      DanmakuItem(text: 'half', time: 0.5),
      DanmakuItem(text: 'one', time: 1),
    ]);

    await _pumpOverlay(tester, controller);
    controller.updatePosition(1.1);
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.diagnostics.queuedCount, 3);
    expect(controller.diagnostics.emittedCount, 3);
    expect(controller.diagnostics.renderedCount, 3);
    expect(controller.diagnostics.currentTime, 1.1);
    expect(controller.diagnostics.danmakuEnabled, isTrue);
    expect(controller.diagnostics.opacity, 1);
    expect(controller.diagnostics.area, 1);

    controller.updatePosition(0);
    expect(controller.diagnostics.queuedCount, 3);
    expect(controller.diagnostics.emittedCount, 0);
    expect(controller.diagnostics.renderedCount, 0);

    await tester.pump(const Duration(milliseconds: 16));
    expect(controller.diagnostics.emittedCount, 1);
    expect(controller.diagnostics.renderedCount, 1);
  });

  testWidgets('disabled danmaku remains queued without emission or paint',
      (tester) async {
    final controller = DanmakuController()
      ..loadDanmaku([DanmakuItem(text: 'hidden', time: 0)])
      ..setVisible(false)
      ..setOpacity(0.4)
      ..setArea(0.5);

    await _pumpOverlay(tester, controller);
    await tester.pump(const Duration(milliseconds: 16));

    expect(controller.diagnostics.queuedCount, 1);
    expect(controller.diagnostics.emittedCount, 0);
    expect(controller.diagnostics.renderedCount, 0);
    expect(controller.diagnostics.danmakuEnabled, isFalse);
    expect(controller.diagnostics.opacity, 0.4);
    expect(controller.diagnostics.area, 0.5);
  });

  testWidgets('publishes paint telemetry after the frame completes',
      (tester) async {
    final controller = DanmakuController()
      ..loadDanmaku([DanmakuItem(text: 'painted', time: 0)]);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    await _pumpOverlay(tester, controller);

    expect(controller.diagnostics.renderedCount, 1);
    expect(notifications, greaterThan(0));
  });
}

Future<void> _pumpOverlay(
  WidgetTester tester,
  DanmakuController controller,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 800,
            height: 450,
            child: DanmakuOverlay(controller: controller),
          ),
        ),
      ),
    ),
  );
}
