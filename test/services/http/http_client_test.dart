import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/http/http_client.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.statusCode = 200;
      request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('probe 对可达地址返回状态码', () async {
    final result = await HttpClient().probe('http://127.0.0.1:${server.port}');
    expect(result.reachable, isTrue);
    expect(result.statusCode, 200);
  });

  test('probe 对 404 仍视为可达（<500 即算连通）', () async {
    final notFoundServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    notFoundServer.listen((request) {
      request.response.statusCode = 404;
      request.response.close();
    });
    addTearDown(() => notFoundServer.close(force: true));

    final result =
        await HttpClient().probe('http://127.0.0.1:${notFoundServer.port}');
    expect(result.reachable, isTrue);
    expect(result.statusCode, 404);
  });

  test('probe 对拒绝连接的端口返回不可达且不抛异常', () async {
    final closedServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = closedServer.port;
    await closedServer.close(force: true);

    final result = await HttpClient()
        .probe('http://127.0.0.1:$port', timeout: const Duration(seconds: 2));
    expect(result.reachable, isFalse);
    expect(result.statusCode, isNull);
  });

  test('getJson 能解析 JSON 响应', () async {
    final jsonServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    jsonServer.listen((request) {
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/json');
      request.response.write('{"list": [1, 2]}');
      request.response.close();
    });
    addTearDown(() => jsonServer.close(force: true));

    final data = await HttpClient()
        .getJson('http://127.0.0.1:${jsonServer.port}');
    expect(data, isA<Map<String, dynamic>>());
    expect((data as Map<String, dynamic>)['list'], [1, 2]);
  });
}
