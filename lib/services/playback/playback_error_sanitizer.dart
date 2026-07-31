import 'playback_diagnostics.dart';

enum PlaybackLogOperation {
  openTimeout('open_timeout'),
  openFailed('open_failed'),
  playerError('player_error'),
  episodeListFailed('episode_list_failed'),
  sourceResolveFailed('source_resolve_failed'),
  detailResolveFailed('detail_resolve_failed');

  const PlaybackLogOperation(this.label);

  final String label;
}

PlaybackFailureKind classifyPlaybackFailure(String error) {
  final message = error.toLowerCase();
  if (message.contains('403') || message.contains('forbidden')) {
    return PlaybackFailureKind.forbidden;
  }
  if (message.contains('404') || message.contains('not found')) {
    return PlaybackFailureKind.notFound;
  }
  if (message.contains('decode') ||
      message.contains('codec') ||
      message.contains('hwdec')) {
    return PlaybackFailureKind.decode;
  }
  if (message.contains('timeout') || message.contains('timed out')) {
    return PlaybackFailureKind.timeout;
  }
  if (message.contains('500') ||
      message.contains('502') ||
      message.contains('503')) {
    return PlaybackFailureKind.server;
  }
  if (message.contains('network') ||
      message.contains('connection') ||
      message.contains('socket') ||
      message.contains('host lookup') ||
      message.contains('dns')) {
    return PlaybackFailureKind.network;
  }
  if (message.contains('no video')) {
    return PlaybackFailureKind.noVideo;
  }
  return PlaybackFailureKind.unknown;
}

String safePlaybackLogMessage(
  PlaybackLogOperation operation,
  PlaybackFailureKind failureKind,
) {
  return '${operation.label} failure_kind=${failureKind.name}';
}
