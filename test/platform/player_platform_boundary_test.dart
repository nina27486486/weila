import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only Android attaches native video output diagnostics', () {
    final page = File('lib/pages/player/player_page.dart').readAsStringSync();
    expect(page,
        contains('!kIsWeb && defaultTargetPlatform == TargetPlatform.android'));
    expect(
        page,
        contains(
            'readVideoOutputConfigured: _usesAndroidVideoOutputDiagnostics'));
    expect(page, contains("getProperty('vo-configured')"));
    expect(page.contains('_handleVideoOutputLog(log, generation)'), isTrue);
    expect(page.contains('_videoOutputLogs?.cancel()'), isTrue);
    expect(page, contains("VideoControllerConfiguration(hwdec: 'auto-safe')"));
  });

  test(
      'renderer failure is shown directly rather than retried as a source error',
      () {
    final page = File('lib/pages/player/player_page.dart').readAsStringSync();
    final start =
        page.indexOf('_handleVideoOutputLog(PlayerLog log, int generation)');
    expect(start, greaterThanOrEqualTo(0));
    final handler =
        page.substring(start, page.indexOf('void _handlePlayerError', start));
    expect(handler, contains('recordVideoOutputLog('));
    expect(handler, contains('PlaybackFailureKind.noVideo'));
    expect(handler, contains('_showPlaybackIssue('));
    expect(handler.contains('_playbackRequestGeneration++'), isTrue);
    expect(handler.contains('_episodeLoadGeneration++'), isTrue);
    expect(handler.contains('generation: generation'), isTrue);
    expect(handler, isNot(contains('_recoverOrShow(')));
    expect(handler, isNot(contains('Log.e(\'Player\', log.text')));
  });

  test('Android first-frame marking rejects missing output evidence and issues',
      () {
    final page = File('lib/pages/player/player_page.dart').readAsStringSync();
    final marker = page.substring(
        page.indexOf('void _markVideoSignalDetected()'),
        page.indexOf('void _handleBufferingChanged'));
    expect(marker, contains('_usesAndroidVideoOutputDiagnostics'));
    expect(marker, contains('!_playbackLifecycle.firstFrameEvidenceReady'));
    expect(marker, contains('_playbackIssue != null'));
  });

  test('Android entry injects the SystemChrome fullscreen controller', () {
    final entry = File('lib/main_android.dart').readAsStringSync();
    expect(
        entry, contains('fullscreenController: AndroidFullscreenController()'));
    expect(entry, isNot(contains('NoopFullscreenController')));
  });

  test('player view wires transient UI into the mobile back scope', () {
    final view = File('lib/pages/player/widgets/player_page_view.dart')
        .readAsStringSync();
    expect(view, contains('PlayerBackScope('));
    expect(view,
        contains('hasOpenPanel: _showShortcutPanel || _showDanmakuPanel'));
    expect(view, contains('hasOpenDrawer: _isEpisodeDrawerVisible'));
    expect(view.contains('onExitFullscreen: _exitFullscreen'), isTrue);
    expect(RegExp(r'PlayerBackScope\.requestBack\(').allMatches(view),
        hasLength(2));
  });

  test('player disposal continues restoring fullscreen through the abstraction',
      () {
    final page = File('lib/pages/player/player_page.dart').readAsStringSync();
    final dispose = page.substring(page.indexOf('void dispose()'));
    expect(dispose, contains('if (_isFullscreen)'));
    expect(
        dispose, contains('widget.fullscreenController.setFullscreen(false)'));
  });

  test('shared player does not import window_manager', () {
    final source = File('lib/pages/player/player_page.dart').readAsStringSync();
    expect(source, isNot(contains('package:window_manager')));
    expect(source, isNot(contains('windowManager.')));
  });

  test('player gates every download entry behind capabilities', () {
    final page = File('lib/pages/player/player_page.dart').readAsStringSync();
    final view = File('lib/pages/player/widgets/player_page_view.dart')
        .readAsStringSync();
    expect(page, contains('widget.capabilities.downloads'));
    expect(view, contains('if (widget.capabilities.downloads)'));
  });
}
