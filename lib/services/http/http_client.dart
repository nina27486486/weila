import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../../utils/constants.dart';
import '../../utils/logger.dart';

/// 可达性探测结果：不抛异常，由调用方根据 reachable/statusCode 决定提示。
class HttpProbeResult {
  const HttpProbeResult({required this.reachable, this.statusCode});

  final bool reachable;
  final int? statusCode;
}

class HttpClient {
  static final HttpClient _instance = HttpClient._();
  factory HttpClient() => _instance;

  late final Dio dio;

  HttpClient._() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': AppConstants.defaultUserAgent,
        'Accept': '*/*',
      },
    ));

    // 拦截器：日志（只打印URL，不打印body）
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      logPrint: (obj) => Log.d('HTTP', obj.toString()),
    ));
  }

  /// 配置全局代理规则，签名与 DownloadSettings.proxyRuleFor 一致
  /// （返回 'DIRECT' / 'PROXY host:port'）。传 null 恢复直连。
  void setProxy(String Function(Uri uri)? proxyRule) {
    if (proxyRule == null) {
      dio.httpClientAdapter = IOHttpClientAdapter();
      return;
    }
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = io.HttpClient();
        client.findProxy = proxyRule;
        return client;
      },
    );
  }

  /// GET 请求，返回 HTML 字符串
  Future<String> getHtml(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
    bool retry = false,
  }) async {
    final response = await _withRetry(
      retry,
      () => dio.get<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
          receiveTimeout: timeout,
        ),
      ),
    );
    return response.data ?? '';
  }

  /// GET 请求，返回 JSON
  Future<dynamic> getJson(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
    bool retry = false,
  }) async {
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      if (headers != null) ...headers,
    };
    final response = await _withRetry(
      retry,
      () => dio.get(
        url,
        options: Options(
          responseType: ResponseType.json,
          headers: mergedHeaders,
          receiveTimeout: timeout,
        ),
      ),
    );
    return _decodeJsonBody(response.data);
  }

  /// POST 请求，返回 JSON（用于 GraphQL 等）
  Future<dynamic> postJson(
    String url, {
    dynamic data,
    Map<String, String>? headers,
    Duration? timeout,
    bool retry = false,
  }) async {
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    };
    final response = await _withRetry(
      retry,
      () => dio.post(
        url,
        data: data,
        options: Options(
          responseType: ResponseType.json,
          headers: mergedHeaders,
          receiveTimeout: timeout,
        ),
      ),
    );
    return _decodeJsonBody(response.data);
  }

  /// 可达性探测：连接异常才失败，任何 <500 的 HTTP 响应都算可达。
  Future<HttpProbeResult> probe(
    String url, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await dio.get<Object?>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          headers: headers,
          receiveTimeout: timeout,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return HttpProbeResult(
        reachable: true,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const HttpProbeResult(reachable: false);
    }
  }

  /// 瞬态错误（连接超时/断开/5xx）重试一次；默认关闭，调用方显式开启。
  Future<Response<T>> _withRetry<T>(
    bool retry,
    Future<Response<T>> Function() run,
  ) async {
    try {
      return await run();
    } on DioException catch (error) {
      if (!retry || !_isTransient(error)) rethrow;
      return await run();
    }
  }

  bool _isTransient(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        (error.type == DioExceptionType.badResponse &&
            (error.response?.statusCode ?? 0) >= 500);
  }

  // Dio 对 text/html 不会自动解析为 JSON，需要手动处理
  dynamic _decodeJsonBody(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return data;
      }
    }
    return data;
  }
}
