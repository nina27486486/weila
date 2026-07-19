import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/playback/playback_source.dart';
import 'package:weila/services/playback/playback_probe_service.dart';

PlaybackSource _source({
  required String id,
  required String url,
  Map<String, String> headers = const {},
}) {
  return PlaybackSource(
    id: id,
    label: id,
    kind: PlaybackSourceKind.cms,
    headers: headers,
    variants: [
      PlaybackVariant(
        id: '$id-original',
        label: '原始',
        url: url,
        kind: PlaybackVariantKind.original,
      ),
    ],
  );
}

void main() {
  test('probes HLS manifest with source headers and bounded bytes', () async {
    Uri? requestedUri;
    Map<String, String>? requestedHeaders;
    bool? requestedManifest;
    int? requestedMaxBytes;
    final service = PlaybackProbeService(
      load: (
          {required uri,
          required headers,
          required manifest,
          required maxBytes}) async {
        requestedUri = uri;
        requestedHeaders = headers;
        requestedManifest = manifest;
        requestedMaxBytes = maxBytes;
        return PlaybackProbePayload(
          statusCode: 200,
          elapsed: const Duration(milliseconds: 120),
          bytesRead: 64,
          contentType: 'application/vnd.apple.mpegurl',
          prefix: utf8.encode('#EXTM3U\n#EXT-X-VERSION:3'),
        );
      },
    );

    final result = await service.probe(
      _source(
        id: 'main',
        url: 'https://media.example/master.m3u8?token=private',
        headers: const {'Referer': 'https://site.example/'},
      ),
    );

    expect(result.success, isTrue);
    expect(requestedUri!.path, '/master.m3u8');
    expect(requestedHeaders, const {'Referer': 'https://site.example/'});
    expect(requestedManifest, isTrue);
    expect(requestedMaxBytes, 256 * 1024);
  });

  test('probes direct media with range without mutating source headers',
      () async {
    Map<String, String>? requestedHeaders;
    final source = _source(
      id: 'direct',
      url: 'https://media.example/video.mp4',
      headers: const {'User-Agent': 'Weila-Test'},
    );
    final service = PlaybackProbeService(
      load: (
          {required uri,
          required headers,
          required manifest,
          required maxBytes}) async {
        requestedHeaders = headers;
        expect(manifest, isFalse);
        return const PlaybackProbePayload(
          statusCode: 206,
          elapsed: Duration(milliseconds: 80),
          bytesRead: 1,
          contentType: 'video/mp4',
          prefix: <int>[0],
        );
      },
    );

    final result = await service.probe(source);

    expect(result.success, isTrue);
    expect(requestedHeaders, {
      'User-Agent': 'Weila-Test',
      'Range': 'bytes=0-0',
    });
    expect(source.headers, const {'User-Agent': 'Weila-Test'});
  });

  test('classifies HTTP status and timeout failures', () async {
    Future<PlaybackProbeResult> probeStatus(int statusCode) {
      return PlaybackProbeService(
        load: (
            {required uri,
            required headers,
            required manifest,
            required maxBytes}) async {
          return PlaybackProbePayload(
            statusCode: statusCode,
            elapsed: const Duration(milliseconds: 50),
            bytesRead: 0,
          );
        },
      ).probe(_source(
          id: 'status-$statusCode', url: 'https://media.example/a.mp4'));
    }

    expect((await probeStatus(403)).failure, PlaybackProbeFailure.forbidden);
    expect((await probeStatus(404)).failure, PlaybackProbeFailure.notFound);
    expect((await probeStatus(503)).failure, PlaybackProbeFailure.server);

    final timeout = PlaybackProbeService(
      load: (
          {required uri,
          required headers,
          required manifest,
          required maxBytes}) {
        throw TimeoutException('probe timed out');
      },
    );
    final timeoutResult = await timeout.probe(
      _source(id: 'timeout', url: 'https://media.example/a.mp4'),
    );
    expect(timeoutResult.failure, PlaybackProbeFailure.timeout);
  });

  test('uses ten-minute success cache without query-string identity', () async {
    var now = DateTime.utc(2026, 7, 11, 12);
    var calls = 0;
    final service = PlaybackProbeService(
      now: () => now,
      load: (
          {required uri,
          required headers,
          required manifest,
          required maxBytes}) async {
        calls += 1;
        return const PlaybackProbePayload(
          statusCode: 206,
          elapsed: Duration(milliseconds: 30),
          bytesRead: 1,
        );
      },
    );

    await service.probe(
      _source(id: 'cached', url: 'https://media.example/a.mp4?token=one'),
    );
    now = now.add(const Duration(minutes: 9, seconds: 59));
    await service.probe(
      _source(id: 'cached', url: 'https://media.example/a.mp4?token=two'),
    );
    expect(calls, 1);

    now = now.add(const Duration(seconds: 2));
    await service.probe(
      _source(id: 'cached', url: 'https://media.example/a.mp4?token=three'),
    );
    expect(calls, 2);
  });

  test('uses two-minute failure cache', () async {
    var now = DateTime.utc(2026, 7, 11, 12);
    var calls = 0;
    final service = PlaybackProbeService(
      now: () => now,
      load: (
          {required uri,
          required headers,
          required manifest,
          required maxBytes}) async {
        calls += 1;
        return const PlaybackProbePayload(
          statusCode: 404,
          elapsed: Duration(milliseconds: 30),
          bytesRead: 0,
        );
      },
    );
    final source = _source(id: 'failed', url: 'https://media.example/a.mp4');

    await service.probe(source);
    now = now.add(const Duration(minutes: 1, seconds: 59));
    await service.probe(source);
    expect(calls, 1);

    now = now.add(const Duration(seconds: 2));
    await service.probe(source);
    expect(calls, 2);
  });

  test('Dio loader consumes only one byte for direct media', () async {
    final adapter = _ProbeHttpAdapter(
      statusCode: 206,
      headers: const {
        'content-type': ['video/mp4'],
      },
      chunks: const [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
      ],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final loader = DioPlaybackProbeLoader(dio: dio);

    final payload = await loader(
      uri: Uri.parse('https://media.example/video.mp4'),
      headers: const {
        'Referer': 'https://site.example/',
        'Range': 'bytes=0-0',
      },
      manifest: false,
      maxBytes: 256 * 1024,
    );

    expect(payload.statusCode, 206);
    expect(payload.bytesRead, 1);
    expect(payload.prefix, const [1]);
    expect(adapter.requestOptions!.headers['Referer'], 'https://site.example/');
    expect(adapter.requestOptions!.headers['Range'], 'bytes=0-0');
  });

  test('Dio loader truncates manifests at the byte limit', () async {
    final adapter = _ProbeHttpAdapter(
      statusCode: 200,
      headers: const {
        'content-type': ['application/vnd.apple.mpegurl'],
      },
      chunks: [utf8.encode('#EXTM3U\n#EXT-X-VERSION:3')],
    );
    final dio = Dio()..httpClientAdapter = adapter;
    final loader = DioPlaybackProbeLoader(dio: dio);

    final payload = await loader(
      uri: Uri.parse('https://media.example/master.m3u8'),
      headers: const {},
      manifest: true,
      maxBytes: 8,
    );

    expect(payload.bytesRead, 8);
    expect(utf8.decode(payload.prefix), '#EXTM3U\n');
    expect(payload.contentType, 'application/vnd.apple.mpegurl');
  });
}

class _ProbeHttpAdapter implements HttpClientAdapter {
  _ProbeHttpAdapter({
    required this.statusCode,
    required this.headers,
    required this.chunks,
  });

  final int statusCode;
  final Map<String, List<String>> headers;
  final List<List<int>> chunks;
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    return ResponseBody(
      Stream<Uint8List>.fromIterable(
        chunks.map(Uint8List.fromList),
      ),
      statusCode,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}
