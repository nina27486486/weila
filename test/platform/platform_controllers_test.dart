import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/platform/android_fullscreen_controller.dart';
import 'package:weila/platform/app_window_controller.dart';
import 'package:weila/platform/fullscreen_controller.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  FullscreenController androidController() => AndroidFullscreenController();

  setUp(() {
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => calls.add(call),
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('Android fullscreen requests both landscape orientations and immersion',
      () async {
    await androidController().setFullscreen(true);
    expect(calls.map((call) => call.method), [
      'SystemChrome.setPreferredOrientations',
      'SystemChrome.setEnabledSystemUIMode',
    ]);
    expect(calls[0].arguments, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    expect(calls[1].arguments, 'SystemUiMode.immersiveSticky');
  });

  test('Android fullscreen exit restores unlocked orientation and edge-to-edge',
      () async {
    final controller = androidController();
    await controller.setFullscreen(true);
    calls.clear();
    await controller.setFullscreen(false);
    expect(calls.map((call) => call.method), [
      'SystemChrome.setPreferredOrientations',
      'SystemChrome.setEnabledSystemUIMode',
    ]);
    expect(calls[0].arguments, isEmpty);
    expect(calls[1].arguments, 'SystemUiMode.edgeToEdge');
  });

  test('rapid enter exit enter requests cannot interleave platform operations',
      () async {
    final gate = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        if (calls.length == 1) await gate.future;
        return null;
      },
    );
    final controller = androidController();
    final entering = controller.setFullscreen(true);
    final exiting = controller.setFullscreen(false);
    final reentering = controller.setFullscreen(true);
    await Future<void>.delayed(Duration.zero);
    try {
      expect(calls.map((call) => call.method), [
        'SystemChrome.setPreferredOrientations',
      ]);
    } finally {
      gate.complete();
    }
    await Future.wait([entering, exiting, reentering]);
    expect(calls.map((call) => call.arguments), [
      ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      'SystemUiMode.immersiveSticky',
      [],
      'SystemUiMode.edgeToEdge',
      ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight'],
      'SystemUiMode.immersiveSticky',
    ]);
  });

  test('repeated in-flight exits share one platform restoration', () async {
    final gate = Completer<void>();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        if (calls.length == 1) await gate.future;
        return null;
      },
    );
    final controller = androidController();
    final first = controller.setFullscreen(false);
    final second = controller.setFullscreen(false);
    try {
      expect(identical(first, second), isTrue);
    } finally {
      gate.complete();
    }
    await Future.wait([first, second]);
    expect(calls, hasLength(2));
  });

  test('a failed platform request does not block later exit restoration',
      () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        if (calls.length == 1) throw PlatformException(code: 'orientation');
        return null;
      },
    );
    final controller = androidController();
    await expectLater(
        controller.setFullscreen(true), throwsA(isA<PlatformException>()));
    await controller.setFullscreen(false);
    expect(calls[1].arguments, isEmpty);
    expect(calls[2].arguments, 'SystemUiMode.edgeToEdge');
  });

  test('exit restores system bars even if orientation restoration fails',
      () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          throw PlatformException(code: 'orientation');
        }
        return null;
      },
    );
    await expectLater(androidController().setFullscreen(false),
        throwsA(isA<PlatformException>()));
    expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
  });

  test('no-op fullscreen controller is safe for Android baseline', () async {
    const controller = NoopFullscreenController();
    await controller.setFullscreen(true);
    await controller.setFullscreen(false);
  });

  test('no-op window controller initializes without side effects', () async {
    const AppWindowController controller = NoopAppWindowController();
    await controller.initialize();
  });
}
