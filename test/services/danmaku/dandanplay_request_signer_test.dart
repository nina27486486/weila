import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/dandanplay_credentials.dart';
import 'package:weila/services/danmaku/dandanplay_request_signer.dart';

void main() {
  const credentials = DandanplayCredentials(
    appId: 'test-app',
    appSecret: 'test-secret',
  );

  test('generates documented timestamp path and SHA-256 signature headers', () {
    final signer = DandanplayRequestSigner(
      now: () => DateTime.utc(2025, 1, 1),
    );

    final headers = signer.headers(
      Uri.parse(
        'https://api.dandanplay.net/api/v2/comment/123450001'
        '?withRelated=true',
      ),
      credentials,
    );

    expect(headers, {
      'X-AppId': 'test-app',
      'X-Timestamp': '1735689600',
      'X-Signature': 'nm9G6ijz/FkHLbMMKgBknQI8+hsFaE9BbXZjMAqOWEY=',
    });
    expect(headers, isNot(contains('X-AppSecret')));
    expect(headers, isNot(contains('X-App-Id')));
    expect(headers, isNot(contains('X-App-Secret')));
  });

  test('query parameters do not participate in the signature', () {
    final signer = DandanplayRequestSigner(
      now: () => DateTime.utc(2025, 1, 1),
    );

    final first = signer.headers(
      Uri.parse('https://api.dandanplay.net/api/v2/comment/123450001?a=1'),
      credentials,
    );
    final second = signer.headers(
      Uri.parse('https://api.dandanplay.net/api/v2/comment/123450001?b=2'),
      credentials,
    );

    expect(first['X-Signature'], second['X-Signature']);
  });

  test('normalizes API paths to lowercase before signing', () {
    final signer = DandanplayRequestSigner(
      now: () => DateTime.utc(2025, 1, 1),
    );

    final lower = signer.headers(
      Uri.parse('https://api.dandanplay.net/api/v2/search/episodes'),
      credentials,
    );
    final mixed = signer.headers(
      Uri.parse('https://api.dandanplay.net/API/V2/Search/Episodes'),
      credentials,
    );

    expect(lower['X-Signature'], mixed['X-Signature']);
  });

  test('rejects blank credentials and redacts their string form', () {
    final signer = DandanplayRequestSigner();
    const blank = DandanplayCredentials(appId: ' ', appSecret: ' ');

    expect(blank.isValid, isFalse);
    expect(
      () => signer.headers(
        Uri.parse('https://api.dandanplay.net/api/v2/search/episodes'),
        blank,
      ),
      throwsArgumentError,
    );
    expect(credentials.toString(), isNot(contains('test-secret')));
    expect(credentials.toString(), contains('redacted'));
  });
}
