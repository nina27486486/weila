import 'dart:async';

import 'package:dio/dio.dart';

import '../../utils/constants.dart';
import 'dandanplay_credentials.dart';
import 'dandanplay_request_signer.dart';

enum DandanplayApiErrorKind {
  notConfigured,
  invalidTimestamp,
  invalidAppId,
  invalidSignature,
  quotaExceeded,
  timeout,
  network,
  server,
  malformedResponse,
  unknown,
}

class DandanplayApiException implements Exception {
  const DandanplayApiException(
    this.kind,
    this.safeMessage, {
    this.statusCode,
  });

  final DandanplayApiErrorKind kind;
  final String safeMessage;
  final int? statusCode;

  @override
  String toString() => 'DandanplayApiException($kind: $safeMessage)';
}

class DandanplayTransportException implements Exception {
  const DandanplayTransportException({
    this.statusCode,
    this.errorMessage,
    this.timedOut = false,
  });

  final int? statusCode;
  final String? errorMessage;
  final bool timedOut;

  @override
  String toString() => 'DandanplayTransportException(status: $statusCode)';
}

abstract interface class DandanplayTransport {
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required Map<String, String> headers,
  });
}

abstract interface class DandanplayApi {
  Future<Map<String, dynamic>> searchEpisodes(String anime, int episode);
  Future<Map<String, dynamic>> getComments(int episodeId);
}

class DioDandanplayTransport implements DandanplayTransport {
  DioDandanplayTransport({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'User-Agent':
                      'Weila/${AppConstants.appVersion} (Desktop Anime Player)',
                  'Accept': 'application/json',
                },
              ),
            );

  final Dio _dio;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    required Map<String, String> headers,
  }) async {
    var current = uri;
    var requestHeaders = Map<String, String>.from(headers);
    var redirects = 0;
    var transientRetries = 0;
    while (true) {
      if (current.scheme != 'https') {
        throw const DandanplayTransportException(
          errorMessage: 'Insecure Redirect',
        );
      }
      try {
        final response = await _dio.get<Object?>(
          current.toString(),
          options: Options(
            headers: requestHeaders,
            responseType: ResponseType.json,
            followRedirects: false,
            validateStatus: (status) =>
                status != null && status >= 200 && status < 400,
          ),
        );
        final statusCode = response.statusCode ?? 0;
        if (statusCode >= 300 && statusCode < 400) {
          final location = response.headers.value('location');
          if (location == null || redirects == 3) {
            throw DandanplayTransportException(statusCode: statusCode);
          }
          final next = current.resolve(location);
          if (next.scheme != 'https') {
            throw const DandanplayTransportException(
              errorMessage: 'Insecure Redirect',
            );
          }
          if (next.origin != current.origin) {
            requestHeaders = const {};
          }
          redirects += 1;
          transientRetries = 0;
          current = next;
          continue;
        }
        final data = response.data;
        if (data is! Map) {
          throw DandanplayTransportException(statusCode: statusCode);
        }
        return Map<String, dynamic>.from(data);
      } on DioException catch (error) {
        final timedOut = error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout;
        final transient = timedOut ||
            error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.unknown;
        if (redirects > 0 && transient && transientRetries == 0) {
          transientRetries += 1;
          continue;
        }
        throw DandanplayTransportException(
          statusCode: error.response?.statusCode,
          errorMessage: error.response?.headers.value('X-Error-Message'),
          timedOut: timedOut,
        );
      }
    }
  }
}

class DandanplayApiClient implements DandanplayApi {
  DandanplayApiClient({
    required DandanplayCredentials credentials,
    required DandanplayRequestSigner signer,
    required DandanplayTransport transport,
  })  : _credentials = credentials,
        _signer = signer,
        _transport = transport;

  final DandanplayCredentials _credentials;
  final DandanplayRequestSigner _signer;
  final DandanplayTransport _transport;

  @override
  Future<Map<String, dynamic>> searchEpisodes(
    String anime,
    int episode,
  ) async {
    final uri = Uri.https(
      'api.dandanplay.net',
      '/api/v2/search/episodes',
      {'anime': anime.trim(), 'episode': '$episode'},
    );
    final data = await _get(uri);
    if (data['success'] != true) {
      throw _businessError(data);
    }
    if (data['animes'] is! List) {
      throw const DandanplayApiException(
        DandanplayApiErrorKind.malformedResponse,
        '搜索响应格式不正确',
      );
    }
    return data;
  }

  @override
  Future<Map<String, dynamic>> getComments(int episodeId) async {
    final uri = Uri.https(
      'api.dandanplay.net',
      '/api/v2/comment/$episodeId',
      {'withRelated': 'true', 'chConvert': '1'},
    );
    final data = await _get(uri);
    if (data['count'] is! num || data['comments'] is! List) {
      throw const DandanplayApiException(
        DandanplayApiErrorKind.malformedResponse,
        '弹幕响应格式不正确',
      );
    }
    return data;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    try {
      return await _transport.getJson(
        uri,
        headers: _signer.headers(uri, _credentials),
      );
    } on TimeoutException {
      throw const DandanplayApiException(
        DandanplayApiErrorKind.timeout,
        '弹幕服务连接超时',
      );
    } on DandanplayTransportException catch (error) {
      throw _transportError(error);
    } on DandanplayApiException {
      rethrow;
    } catch (_) {
      throw const DandanplayApiException(
        DandanplayApiErrorKind.network,
        '弹幕服务网络连接失败',
      );
    }
  }

  DandanplayApiException _businessError(Map<String, dynamic> data) {
    final code = data['errorCode'];
    final message = data['errorMessage']?.toString() ?? '';
    if (code == 429 || message.contains('额度') || message.contains('配额')) {
      return const DandanplayApiException(
        DandanplayApiErrorKind.quotaExceeded,
        '弹幕服务额度已用完',
      );
    }
    if (message.contains('服务器')) {
      return const DandanplayApiException(
        DandanplayApiErrorKind.server,
        '弹幕服务暂时不可用',
      );
    }
    return const DandanplayApiException(
      DandanplayApiErrorKind.unknown,
      '弹幕服务返回业务错误',
    );
  }

  DandanplayApiException _transportError(
    DandanplayTransportException error,
  ) {
    if (error.timedOut) {
      return const DandanplayApiException(
        DandanplayApiErrorKind.timeout,
        '弹幕服务连接超时',
      );
    }
    final message = error.errorMessage ?? '';
    final kind = switch (message) {
      'Missing Authentication Headers' => DandanplayApiErrorKind.notConfigured,
      'Invalid Timestamp' => DandanplayApiErrorKind.invalidTimestamp,
      'Invalid AppId' => DandanplayApiErrorKind.invalidAppId,
      'Invalid Signature' ||
      'Invalid AppSecret' =>
        DandanplayApiErrorKind.invalidSignature,
      _ when error.statusCode == 429 => DandanplayApiErrorKind.quotaExceeded,
      _ when (error.statusCode ?? 0) >= 500 => DandanplayApiErrorKind.server,
      _ => DandanplayApiErrorKind.network,
    };
    return DandanplayApiException(
      kind,
      _safeMessage(kind),
      statusCode: error.statusCode,
    );
  }

  String _safeMessage(DandanplayApiErrorKind kind) => switch (kind) {
        DandanplayApiErrorKind.notConfigured => '弹幕服务缺少应用凭据',
        DandanplayApiErrorKind.invalidTimestamp => '系统时间与服务器不同步',
        DandanplayApiErrorKind.invalidAppId => '弹幕应用 ID 无效',
        DandanplayApiErrorKind.invalidSignature => '弹幕应用签名无效',
        DandanplayApiErrorKind.quotaExceeded => '弹幕服务额度已用完',
        DandanplayApiErrorKind.timeout => '弹幕服务连接超时',
        DandanplayApiErrorKind.server => '弹幕服务暂时不可用',
        _ => '弹幕服务网络连接失败',
      };
}
