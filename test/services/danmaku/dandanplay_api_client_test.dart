import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/dandanplay_api_client.dart';
import 'package:weila/services/danmaku/dandanplay_credentials.dart';
import 'package:weila/services/danmaku/dandanplay_request_signer.dart';

void main() {
  DandanplayApiClient clientWith(_FakeTransport transport) {
    return DandanplayApiClient(
      credentials: const DandanplayCredentials(
        appId: 'test-app',
        appSecret: 'secret-value',
      ),
      signer: DandanplayRequestSigner(
        now: () => DateTime.utc(2025, 1, 1),
      ),
      transport: transport,
    );
  }

  test('search uses encoded anime numeric episode and signature headers',
      () async {
    final transport = _FakeTransport((uri, headers) async {
      return {'success': true, 'animes': <dynamic>[]};
    });

    final response = await clientWith(transport).searchEpisodes('葬送的芙莉莲', 1);

    expect(response['animes'], isEmpty);
    expect(transport.lastUri!.path, '/api/v2/search/episodes');
    expect(transport.lastUri!.queryParameters['anime'], '葬送的芙莉莲');
    expect(transport.lastUri!.queryParameters['episode'], '1');
    expect(transport.lastHeaders!.keys, {
      'X-AppId',
      'X-Timestamp',
      'X-Signature',
    });
    expect(transport.lastHeaders, isNot(contains('X-AppSecret')));
  });

  test('comments request related simplified comments with signature', () async {
    final transport = _FakeTransport((uri, headers) async {
      return {'count': 0, 'comments': <dynamic>[]};
    });

    final response = await clientWith(transport).getComments(123450001);

    expect(response['count'], 0);
    expect(transport.lastUri!.path, '/api/v2/comment/123450001');
    expect(transport.lastUri!.queryParameters, {
      'withRelated': 'true',
      'chConvert': '1',
    });
    expect(transport.lastHeaders, contains('X-Signature'));
  });

  test('redirect transport gives CDN enough time and strips auth headers',
      () async {
    final adapter = _RedirectAdapter();
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    )..httpClientAdapter = adapter;
    final transport = DioDandanplayTransport(dio: dio);

    final response = await transport.getJson(
      Uri.https('api.dandanplay.net', '/api/v2/comment/123'),
      headers: const {
        'X-AppId': 'test-app',
        'X-Timestamp': '123',
        'X-Signature': 'signed',
      },
    );

    expect(response['count'], 1);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.headers, contains('X-Signature'));
    expect(adapter.requests.last.uri.host, 'comment-cdn.example');
    expect(adapter.requests.last.headers, isNot(contains('X-AppId')));
    expect(adapter.requests.last.headers, isNot(contains('X-Timestamp')));
    expect(adapter.requests.last.headers, isNot(contains('X-Signature')));
    expect(
      adapter.requests.last.connectTimeout,
      const Duration(seconds: 30),
    );
    expect(
      adapter.requests.last.receiveTimeout,
      const Duration(seconds: 30),
    );
  });

  test('redirect transport retries one transient CDN connection failure',
      () async {
    final adapter = _RedirectAdapter(failCdnOnce: true);
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    )..httpClientAdapter = adapter;
    final transport = DioDandanplayTransport(dio: dio);

    final response = await transport.getJson(
      Uri.https('api.dandanplay.net', '/api/v2/comment/123'),
      headers: const {'X-Signature': 'signed'},
    );

    expect(response['count'], 1);
    expect(adapter.requests, hasLength(3));
    expect(
      adapter.requests.where(
        (request) => request.uri.host == 'comment-cdn.example',
      ),
      hasLength(2),
    );
  });

  test('maps business and malformed responses to safe typed errors', () async {
    Future<DandanplayApiException> errorFor(
        Map<String, dynamic> response) async {
      final transport = _FakeTransport((uri, headers) async => response);
      try {
        await clientWith(transport).searchEpisodes('测试动画', 1);
      } on DandanplayApiException catch (error) {
        return error;
      }
      throw StateError('Expected an API exception');
    }

    final quota = await errorFor({
      'success': false,
      'errorCode': 429,
      'errorMessage': '今日额度已用完',
    });
    final business = await errorFor({
      'success': false,
      'errorCode': 1,
      'errorMessage': '服务器内部错误',
    });
    final malformed = await errorFor({'success': true, 'animes': 'bad'});

    expect(quota.kind, DandanplayApiErrorKind.quotaExceeded);
    expect(business.kind, DandanplayApiErrorKind.server);
    expect(malformed.kind, DandanplayApiErrorKind.malformedResponse);
    expect('$quota$business$malformed', isNot(contains('secret-value')));
  });

  test('maps documented 403 reasons without exposing credentials', () async {
    Future<DandanplayApiErrorKind> kindFor(String message) async {
      final transport = _FakeTransport((uri, headers) {
        throw DandanplayTransportException(
          statusCode: 403,
          errorMessage: message,
        );
      });
      try {
        await clientWith(transport).searchEpisodes('测试动画', 1);
      } on DandanplayApiException catch (error) {
        expect(error.toString(), isNot(contains('secret-value')));
        return error.kind;
      }
      throw StateError('Expected an API exception');
    }

    expect(await kindFor('Missing Authentication Headers'),
        DandanplayApiErrorKind.notConfigured);
    expect(await kindFor('Invalid Timestamp'),
        DandanplayApiErrorKind.invalidTimestamp);
    expect(await kindFor('Invalid AppId'), DandanplayApiErrorKind.invalidAppId);
    expect(await kindFor('Invalid Signature'),
        DandanplayApiErrorKind.invalidSignature);
  });

  test('maps timeout server and generic network failures', () async {
    Future<DandanplayApiErrorKind> kindFor(Object error) async {
      final transport = _FakeTransport((uri, headers) => Future.error(error));
      try {
        await clientWith(transport).searchEpisodes('测试动画', 1);
      } on DandanplayApiException catch (mapped) {
        return mapped.kind;
      }
      throw StateError('Expected an API exception');
    }

    expect(
      await kindFor(TimeoutException('timeout')),
      DandanplayApiErrorKind.timeout,
    );
    expect(
      await kindFor(const DandanplayTransportException(statusCode: 503)),
      DandanplayApiErrorKind.server,
    );
    expect(
      await kindFor(const DandanplayTransportException()),
      DandanplayApiErrorKind.network,
    );
  });
}

class _FakeTransport implements DandanplayTransport {
  _FakeTransport(this.handler);

  final Future<Map<String, dynamic>> Function(
    Uri uri,
    Map<String, String> headers,
  ) handler;
  Uri? lastUri;
  Map<String, String>? lastHeaders;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required Map<String, String> headers,
  }) {
    lastUri = uri;
    lastHeaders = Map<String, String>.from(headers);
    return handler(uri, headers);
  }
}

class _RedirectAdapter implements HttpClientAdapter {
  _RedirectAdapter({this.failCdnOnce = false});

  final bool failCdnOnce;
  final List<RequestOptions> requests = [];
  var _cdnFailures = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(
        options.copyWith(headers: Map<String, dynamic>.from(options.headers)));
    if (options.uri.host == 'api.dandanplay.net') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'location': [
            'https://comment-cdn.example/library/123.json',
          ],
        },
      );
    }
    if (failCdnOnce && _cdnFailures++ == 0) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const SocketException('temporary CDN failure'),
      );
    }
    return ResponseBody.fromString(
      jsonEncode({
        'count': 1,
        'comments': [
          {'p': '1,1,16777215,1', 'm': '真实弹幕'},
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
