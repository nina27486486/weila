import '../../utils/logger.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../utils/constants.dart';

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
  
  /// GET 请求，返回 HTML 字符串
  Future<String> getHtml(String url, {Map<String, String>? headers}) async {
    final response = await dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: headers,
      ),
    );
    return response.data ?? '';
  }
  
  /// GET 请求，返回 JSON
  Future<dynamic> getJson(String url, {Map<String, String>? headers}) async {
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      if (headers != null) ...headers,
    };
    final response = await dio.get(
      url,
      options: Options(
        responseType: ResponseType.json,
        headers: mergedHeaders,
      ),
    );
    // Dio 对 text/html 不会自动解析为 JSON，需要手动处理
    if (response.data is String) {
      try {
        return jsonDecode(response.data as String);
      } catch (_) {
        return response.data;
      }
    }
    return response.data;
  }

  /// POST 请求，返回 JSON（用于 GraphQL 等）
  Future<dynamic> postJson(String url, {dynamic data, Map<String, String>? headers}) async {
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (headers != null) ...headers,
    };
    final response = await dio.post(
      url,
      data: data,
      options: Options(
        responseType: ResponseType.json,
        headers: mergedHeaders,
      ),
    );
    // 与getJson一致：处理text/html返回JSON的情况
    if (response.data is String) {
      try {
        return jsonDecode(response.data as String);
      } catch (_) {
        return response.data;
      }
    }
    return response.data;
  }
}
