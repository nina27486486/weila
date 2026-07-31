import 'package:flutter_test/flutter_test.dart';
import 'package:weila/bootstrap/app_bootstrap.dart';
import 'package:weila/platform/app_window_controller.dart';

void main() {
  test('bootstrap preserves initialization order and optional downloads',
      () async {
    final calls = <String>[];
    final bootstrap = AppBootstrap(
      windowController: _RecordingWindowController(calls),
      initializeStorage: () async => calls.add('storage'),
      initializeCredentials: () async => calls.add('credentials'),
      loadTheme: () => calls.add('theme'),
      initializePlugins: () async => calls.add('plugins'),
      initializeDownloads: () async => calls.add('downloads'),
    );

    await bootstrap.initialize();

    expect(calls, [
      'window',
      'storage',
      'credentials',
      'theme',
      'plugins',
      'downloads',
    ]);
  });

  test('bootstrap does not initialize downloads when capability omits it',
      () async {
    final calls = <String>[];
    final bootstrap = AppBootstrap(
      windowController: _RecordingWindowController(calls),
      initializeStorage: () async => calls.add('storage'),
      initializeCredentials: () async => calls.add('credentials'),
      loadTheme: () => calls.add('theme'),
      initializePlugins: () async => calls.add('plugins'),
    );

    await bootstrap.initialize();

    expect(calls, isNot(contains('downloads')));
  });
}

class _RecordingWindowController implements AppWindowController {
  _RecordingWindowController(this.calls);

  final List<String> calls;

  @override
  Future<void> initialize() async => calls.add('window');
}
