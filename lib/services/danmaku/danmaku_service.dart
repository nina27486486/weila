import '../storage/storage_service.dart';
import 'dandanplay_api_client.dart';
import 'dandanplay_credentials.dart';
import 'dandanplay_request_signer.dart';
import 'danmaku_diagnostics.dart';
import 'danmaku_load_result.dart';
import 'danmaku_matcher.dart';
import 'danmaku_repository.dart';

typedef DanmakuRepositoryFactory = DanmakuRepository Function(
  DandanplayCredentials credentials,
);
typedef DandanplayApiFactory = DandanplayApi Function(
  DandanplayCredentials credentials,
);

class DanmakuConnectionTestResult {
  const DanmakuConnectionTestResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

/// 弹幕功能门面。
///
/// 请求签名、API 输送、匹配与缓存均由独立模块承担；本类只管理
/// 当前凭证与对页面友好的类型化结果。
class DanmakuService {
  factory DanmakuService() => _instance;

  DanmakuService.testing({
    required DanmakuRepositoryFactory repositoryFactory,
    required DandanplayApiFactory apiFactory,
  })  : _repositoryFactory = repositoryFactory,
        _apiFactory = apiFactory;

  DanmakuService._()
      : _repositoryFactory = _createRepository,
        _apiFactory = _createApi;

  static final DanmakuService _instance = DanmakuService._();

  final DanmakuRepositoryFactory _repositoryFactory;
  final DandanplayApiFactory _apiFactory;
  DandanplayCredentials? _credentials;
  DanmakuRepository? _repository;

  bool get hasCredentials => _credentials?.isValid ?? false;

  void setCredentials(String appId, String appSecret) {
    final credentials = DandanplayCredentials(
      appId: appId.trim(),
      appSecret: appSecret.trim(),
    );
    if (!credentials.isValid) {
      clearCredentials();
      return;
    }
    _credentials = credentials;
    _repository = _repositoryFactory(credentials);
  }

  void clearCredentials() {
    _credentials = null;
    _repository = null;
  }

  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return DanmakuLoadResult(
        status: DanmakuLoadStatus.notConfigured,
        diagnostics: const DanmakuLoadDiagnostics(
          errorStage: DanmakuErrorStage.credentials,
        ),
        safeMessage: '请先在设置中配置弹弹play应用凭证',
      );
    }
    return repository.load(anime: anime, episode: episode, refresh: refresh);
  }

  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) async {
    final repository = _repository;
    if (repository == null) {
      return DanmakuLoadResult(
        status: DanmakuLoadStatus.notConfigured,
        diagnostics: const DanmakuLoadDiagnostics(
          errorStage: DanmakuErrorStage.credentials,
        ),
        safeMessage: '请先在设置中配置弹弹play应用凭证',
      );
    }
    return repository.choose(
      anime: anime,
      episode: episode,
      candidate: candidate,
    );
  }

  Future<DanmakuConnectionTestResult> testCredentials({
    required String appId,
    required String appSecret,
  }) async {
    final credentials = DandanplayCredentials(
      appId: appId.trim(),
      appSecret: appSecret.trim(),
    );
    if (!credentials.isValid) {
      return const DanmakuConnectionTestResult(
        success: false,
        message: '请完整填写应用 ID 与密钥',
      );
    }
    try {
      await _apiFactory(credentials).searchEpisodes('葬送的芙莉莲', 1);
      return const DanmakuConnectionTestResult(
        success: true,
        message: '弹弹play 签名验证成功',
      );
    } on DandanplayApiException catch (error) {
      return DanmakuConnectionTestResult(
        success: false,
        message: error.safeMessage,
      );
    } catch (_) {
      return const DanmakuConnectionTestResult(
        success: false,
        message: '弹幕服务连接失败',
      );
    }
  }

  Future<void> clearCache() async {
    await _repository?.clear();
  }

  static DandanplayApi _createApi(DandanplayCredentials credentials) {
    return DandanplayApiClient(
      credentials: credentials,
      signer: DandanplayRequestSigner(),
      transport: DioDandanplayTransport(),
    );
  }

  static DanmakuRepository _createRepository(
    DandanplayCredentials credentials,
  ) {
    final storage = StorageService();
    return DanmakuRepository(
      client: _createApi(credentials),
      matcher: const DanmakuMatcher(),
      cache: SettingsDanmakuCacheStore(
        read: (key) => storage.getSetting<Object>(key),
        write: storage.setSetting,
        remove: storage.removeSetting,
      ),
    );
  }
}
