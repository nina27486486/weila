import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/dandanplay_api_client.dart';
import 'package:weila/services/danmaku/dandanplay_credentials.dart';
import 'package:weila/services/danmaku/danmaku_diagnostics.dart';
import 'package:weila/services/danmaku/danmaku_load_result.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';
import 'package:weila/services/danmaku/danmaku_repository.dart';
import 'package:weila/services/danmaku/danmaku_service.dart';

void main() {
  test('returns an explicit not-configured state before credentials exist',
      () async {
    final service = DanmakuService.testing(
      repositoryFactory: (_) => _FakeRepository(),
      apiFactory: (_) => _FakeApi(),
    );

    final result = await service.load(anime: 'Frieren', episode: 1);

    expect(result.status, DanmakuLoadStatus.notConfigured);
    expect(result.diagnostics.errorStage, DanmakuErrorStage.credentials);
    expect(service.hasCredentials, isFalse);
  });

  test('configures repository without exposing the secret in diagnostics',
      () async {
    DandanplayCredentials? received;
    final service = DanmakuService.testing(
      repositoryFactory: (credentials) {
        received = credentials;
        return _FakeRepository();
      },
      apiFactory: (_) => _FakeApi(),
    );

    service.setCredentials(' app-id ', ' top-secret ');
    final result = await service.load(anime: 'Frieren', episode: 1);

    expect(service.hasCredentials, isTrue);
    expect(result.status, DanmakuLoadStatus.loaded);
    expect(received?.appId, 'app-id');
    expect(received?.appSecret, 'top-secret');
    expect(received.toString(), isNot(contains('top-secret')));
  });

  test('tests credentials through a signed API client and maps failures',
      () async {
    final success = DanmakuService.testing(
      repositoryFactory: (_) => _FakeRepository(),
      apiFactory: (_) => _FakeApi(),
    );
    final rejected = DanmakuService.testing(
      repositoryFactory: (_) => _FakeRepository(),
      apiFactory: (_) => _FakeApi(
        error: const DandanplayApiException(
          DandanplayApiErrorKind.invalidSignature,
          '签名无效',
        ),
      ),
    );

    expect(
      (await success.testCredentials(appId: 'id', appSecret: 'secret')).success,
      isTrue,
    );
    final failed =
        await rejected.testCredentials(appId: 'id', appSecret: 'secret');
    expect(failed.success, isFalse);
    expect(failed.message, '签名无效');
  });

  test('clearing credentials prevents later loads', () async {
    final service = DanmakuService.testing(
      repositoryFactory: (_) => _FakeRepository(),
      apiFactory: (_) => _FakeApi(),
    )..setCredentials('id', 'secret');

    service.clearCredentials();

    expect(service.hasCredentials, isFalse);
    expect(
      (await service.load(anime: 'Frieren', episode: 1)).status,
      DanmakuLoadStatus.notConfigured,
    );
  });
}

class _FakeRepository implements DanmakuRepository {
  @override
  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) async =>
      DanmakuLoadResult(status: DanmakuLoadStatus.loaded);

  @override
  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) async =>
      DanmakuLoadResult(
        status: DanmakuLoadStatus.loaded,
        selected: candidate,
      );

  @override
  Future<void> clear() async {}
}

class _FakeApi implements DandanplayApi {
  _FakeApi({this.error});

  final DandanplayApiException? error;

  @override
  Future<Map<String, dynamic>> getComments(int episodeId) async => {};

  @override
  Future<Map<String, dynamic>> searchEpisodes(String anime, int episode) async {
    if (error != null) throw error!;
    return {'success': true, 'animes': <Object>[]};
  }
}
