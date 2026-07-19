import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models/playback/playback_source.dart';

enum PlaybackProbeFailure {
  timeout,
  forbidden,
  notFound,
  server,
  network,
  invalidContent,
  unknown,
}

class PlaybackProbePayload {
  const PlaybackProbePayload({
    required this.statusCode,
    required this.elapsed,
    required this.bytesRead,
    this.contentType,
    this.prefix = const <int>[],
  });

  final int statusCode;
  final Duration elapsed;
  final int bytesRead;
  final String? contentType;
  final List<int> prefix;
}

typedef PlaybackProbeLoader = Future<PlaybackProbePayload> Function({
  required Uri uri,
  required Map<String, String> headers,
  required bool manifest,
  required int maxBytes,
});

class DioPlaybackProbeLoader {
  DioPlaybackProbeLoader({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 6),
              ),
            );

  final Dio _dio;

  Future<PlaybackProbePayload> call({
    required Uri uri,
    required Map<String, String> headers,
    required bool manifest,
    required int maxBytes,
  }) async {
    final stopwatch = Stopwatch()..start();
    final response = await _dio.get<ResponseBody>(
      uri.toString(),
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        followRedirects: true,
        maxRedirects: 3,
        validateStatus: (_) => true,
      ),
    );
    final limit = manifest ? maxBytes : 1;
    final prefix = <int>[];
    final stream = response.data?.stream ?? const Stream<Uint8List>.empty();
    await for (final chunk in stream) {
      final remaining = limit - prefix.length;
      if (remaining <= 0) break;
      prefix.addAll(chunk.take(remaining));
      if (prefix.length >= limit) break;
    }
    stopwatch.stop();
    return PlaybackProbePayload(
      statusCode: response.statusCode ?? 0,
      elapsed: stopwatch.elapsed,
      bytesRead: prefix.length,
      contentType: response.headers.value(Headers.contentTypeHeader),
      prefix: List<int>.unmodifiable(prefix),
    );
  }
}

class PlaybackProbeResult {
  const PlaybackProbeResult({
    required this.success,
    required this.elapsed,
    required this.checkedAt,
    this.failure,
    this.contentType,
  });

  final bool success;
  final Duration elapsed;
  final DateTime checkedAt;
  final PlaybackProbeFailure? failure;
  final String? contentType;
}

class PlaybackProbeService {
  PlaybackProbeService({
    required PlaybackProbeLoader load,
    DateTime Function()? now,
  })  : _load = load,
        _now = now ?? DateTime.now;

  static const _maximumProbeBytes = 256 * 1024;
  static const _successTtl = Duration(minutes: 10);
  static const _failureTtl = Duration(minutes: 2);

  final PlaybackProbeLoader _load;
  final DateTime Function() _now;
  final Map<String, _PlaybackProbeCacheEntry> _cache = {};

  Future<PlaybackProbeResult> probe(PlaybackSource source) async {
    if (source.variants.isEmpty) {
      return _failure(PlaybackProbeFailure.invalidContent);
    }
    final variant = source.variants.first;
    final uri = Uri.tryParse(variant.url);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return _failure(PlaybackProbeFailure.invalidContent);
    }

    final cacheKey = _cacheKey(source, uri);
    final cached = _cache[cacheKey];
    final now = _now();
    if (cached != null && now.isBefore(cached.expiresAt)) {
      return cached.result;
    }

    final manifest = variant.kind == PlaybackVariantKind.hls ||
        uri.path.toLowerCase().endsWith('.m3u8');
    final headers = Map<String, String>.from(source.headers);
    if (!manifest) headers['Range'] = 'bytes=0-0';

    late final PlaybackProbeResult result;
    try {
      final payload = await _load(
        uri: uri,
        headers: headers,
        manifest: manifest,
        maxBytes: _maximumProbeBytes,
      ).timeout(const Duration(seconds: 6));
      result = _fromPayload(payload, manifest: manifest);
    } on TimeoutException {
      result = _failure(PlaybackProbeFailure.timeout);
    } catch (_) {
      result = _failure(PlaybackProbeFailure.network);
    }

    _cache[cacheKey] = _PlaybackProbeCacheEntry(
      result: result,
      expiresAt: now.add(result.success ? _successTtl : _failureTtl),
    );
    return result;
  }

  void clearCache() => _cache.clear();

  PlaybackProbeResult _fromPayload(
    PlaybackProbePayload payload, {
    required bool manifest,
  }) {
    final statusFailure = switch (payload.statusCode) {
      200 || 206 => null,
      401 || 403 => PlaybackProbeFailure.forbidden,
      404 => PlaybackProbeFailure.notFound,
      >= 500 => PlaybackProbeFailure.server,
      _ => PlaybackProbeFailure.invalidContent,
    };
    if (statusFailure != null) {
      return _failure(
        statusFailure,
        elapsed: payload.elapsed,
        contentType: payload.contentType,
      );
    }
    if (manifest) {
      final prefix =
          utf8.decode(payload.prefix, allowMalformed: true).trimLeft();
      if (!prefix.startsWith('#EXTM3U')) {
        return _failure(
          PlaybackProbeFailure.invalidContent,
          elapsed: payload.elapsed,
          contentType: payload.contentType,
        );
      }
    }
    return PlaybackProbeResult(
      success: true,
      elapsed: payload.elapsed,
      checkedAt: _now(),
      contentType: payload.contentType,
    );
  }

  PlaybackProbeResult _failure(
    PlaybackProbeFailure failure, {
    Duration elapsed = Duration.zero,
    String? contentType,
  }) {
    return PlaybackProbeResult(
      success: false,
      elapsed: elapsed,
      checkedAt: _now(),
      failure: failure,
      contentType: contentType,
    );
  }

  String _cacheKey(PlaybackSource source, Uri uri) {
    return '${source.kind.name}|${source.id}|${uri.host.toLowerCase()}';
  }
}

class _PlaybackProbeCacheEntry {
  const _PlaybackProbeCacheEntry({
    required this.result,
    required this.expiresAt,
  });

  final PlaybackProbeResult result;
  final DateTime expiresAt;
}
