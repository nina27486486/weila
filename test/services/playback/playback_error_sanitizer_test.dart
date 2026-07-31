import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/playback/playback_diagnostics.dart';
import 'package:weila/services/playback/playback_error_sanitizer.dart';

void main() {
  group('classifyPlaybackFailure', () {
    test('maps known player failures to stable failure kinds', () {
      expect(
        classifyPlaybackFailure('HTTP 403 Forbidden'),
        PlaybackFailureKind.forbidden,
      );
      expect(
        classifyPlaybackFailure('404 not found'),
        PlaybackFailureKind.notFound,
      );
      expect(
        classifyPlaybackFailure('codec decode failed'),
        PlaybackFailureKind.decode,
      );
      expect(
        classifyPlaybackFailure('request timed out'),
        PlaybackFailureKind.timeout,
      );
      expect(
        classifyPlaybackFailure('HTTP 503 unavailable'),
        PlaybackFailureKind.server,
      );
      expect(
        classifyPlaybackFailure('connection refused'),
        PlaybackFailureKind.network,
      );
      expect(
        classifyPlaybackFailure('unexpected player state'),
        PlaybackFailureKind.unknown,
      );
    });
  });

  group('safePlaybackLogMessage', () {
    test('contains only controlled operation and failure kind', () {
      const rawError = 'https://media.example/video.m3u8?token=secret '
          'Authorization: Bearer hidden C:\\Users\\nina\\private.txt';
      final kind = classifyPlaybackFailure(rawError);
      final message = safePlaybackLogMessage(
        PlaybackLogOperation.playerError,
        kind,
      );

      expect(message, 'player_error failure_kind=unknown');
      expect(message, isNot(contains('https://')));
      expect(message, isNot(contains('media.example')));
      expect(message, isNot(contains('token')));
      expect(message, isNot(contains('Authorization')));
      expect(message, isNot(contains('C:\\Users')));
      expect(message, isNot(contains('secret')));
    });
  });
}
