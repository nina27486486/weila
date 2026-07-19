import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:weila/services/danmaku/dandanplay_api_client.dart';
import 'package:weila/services/danmaku/dandanplay_credentials.dart';
import 'package:weila/services/danmaku/dandanplay_request_signer.dart';
import 'package:weila/services/danmaku/danmaku_diagnostics.dart';
import 'package:weila/services/danmaku/danmaku_load_result.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';
import 'package:weila/services/danmaku/danmaku_repository.dart';

void main() {
  final enabled = Platform.environment['DANDANPLAY_LIVE_TEST'] == '1';

  test(
    'signed search and comments work with locally stored credentials',
    () async {
      final profile = Platform.environment['USERPROFILE']!;
      final anime = Platform.environment['DANDANPLAY_LIVE_ANIME'] ?? '弱弱老师';
      final episode = int.tryParse(
            Platform.environment['DANDANPLAY_LIVE_EPISODE'] ?? '',
          ) ??
          1;
      final documents = '$profile${Platform.pathSeparator}Documents';
      final snapshot = await Directory.systemTemp.createTemp('weila-ddp-live-');
      await File('$documents${Platform.pathSeparator}settings_box.hive').copy(
        '${snapshot.path}${Platform.pathSeparator}settings_box.hive',
      );
      Hive.init(snapshot.path);
      final box = await Hive.openBox<dynamic>('settings_box');
      try {
        final appId = box.get('dandanplay_app_id');
        final appSecret = box.get('dandanplay_app_secret');
        expect(appId, isA<String>(), reason: '本机未保存 AppId');
        expect(appSecret, isA<String>(), reason: '本机未保存 AppSecret');

        final credentials = DandanplayCredentials(
          appId:
              Platform.environment['DANDANPLAY_LIVE_APP_ID'] ?? appId as String,
          appSecret: appSecret as String,
        );
        final client = DandanplayApiClient(
          credentials: credentials,
          signer: DandanplayRequestSigner(),
          transport: DioDandanplayTransport(),
        );
        final repository = DanmakuRepository(
          client: client,
          matcher: const DanmakuMatcher(),
          cache: _MemoryDanmakuCache(),
        );
        var result = await repository.load(
          anime: anime,
          episode: episode,
          refresh: true,
        );
        if (result.candidates.isNotEmpty) {
          result = await repository.choose(
            anime: anime,
            episode: episode,
            candidate: result.candidates.first,
          );
        }

        expect(result.status, DanmakuLoadStatus.loaded);
        expect(result.diagnostics.errorStage, DanmakuErrorStage.none);
        expect(result.diagnostics.episodeId, isNotNull);
        expect(result.diagnostics.commentCount, greaterThan(0));
        expect(result.diagnostics.parsedCount, greaterThan(0));
        expect(result.items.length, result.diagnostics.parsedCount);
      } finally {
        await box.close();
        await snapshot.delete(recursive: true);
      }
    },
    skip: enabled ? false : '设置 DANDANPLAY_LIVE_TEST=1 才消耗真实 API 额度',
    timeout: const Timeout(Duration(seconds: 45)),
  );
}

class _MemoryDanmakuCache implements DanmakuCacheStore {
  final Map<String, Object> values = {};

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> write(String key, Object value) async => values[key] = value;
}
