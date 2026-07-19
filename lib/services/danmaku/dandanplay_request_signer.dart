import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'dandanplay_credentials.dart';

typedef DandanplayClock = DateTime Function();

class DandanplayRequestSigner {
  DandanplayRequestSigner({DandanplayClock? now}) : _now = now ?? DateTime.now;

  final DandanplayClock _now;

  Map<String, String> headers(
    Uri uri,
    DandanplayCredentials credentials,
  ) {
    if (!credentials.isValid) {
      throw ArgumentError('DandanPlay credentials are not configured');
    }
    if (uri.path.isEmpty || !uri.path.startsWith('/')) {
      throw ArgumentError.value(uri.path, 'uri', 'API path must start with /');
    }
    final appId = credentials.appId.trim();
    final appSecret = credentials.appSecret.trim();
    final timestamp =
        _now().toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final path = uri.path.toLowerCase();
    final digest = sha256.convert(
      utf8.encode('$appId$timestamp$path$appSecret'),
    );
    return {
      'X-AppId': appId,
      'X-Timestamp': '$timestamp',
      'X-Signature': base64Encode(digest.bytes),
    };
  }
}
