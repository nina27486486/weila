import '../../utils/logger.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';
import '../../theme/app_theme.dart';
import '../../models/anime.dart';
import '../../models/playback/playback_source.dart';
import '../../services/plugin/plugin_service.dart';
import '../../services/http/http_client.dart';
import '../../services/download/download_service.dart';
import '../../services/danmaku/danmaku_load_result.dart';
import '../../services/danmaku/danmaku_matcher.dart';
import '../../services/danmaku/danmaku_service.dart';
import '../../services/library/playback_entry_factory.dart';
import '../../services/playback/hls_variant_resolver.dart';
import '../../services/playback/playback_diagnostics.dart';
import '../../services/playback/playback_probe_service.dart';
import '../../services/playback/playback_route_health.dart';
import '../../services/playback/playback_route_health_repository.dart';
import '../../services/storage/storage_service.dart';
import '../../widgets/artwork_components.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../stores/history_collect_store.dart';
import '../../utils/error_handler.dart';
import 'widgets/player_danmaku_settings_panel.dart';
import 'widgets/player_control_bar.dart';
import 'widgets/player_diagnostics_overlay.dart';
import 'widgets/episode_sidebar.dart';
import 'widgets/player_next_episode_prompt.dart';
import 'widgets/player_shortcut_panel.dart';
import 'playback_session.dart';
import 'playback_health_coordinator.dart';

part 'widgets/player_page_components.dart';

class PlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String animeUrl;
  final String animeName;
  final String? coverUrl;
  final int episodeIndex;
  final String sourcePlugin;
  final String? contentId;

  const PlayerPage({
    super.key,
    required this.videoUrl,
    required this.title,
    this.animeUrl = '',
    this.animeName = '',
    this.coverUrl,
    this.episodeIndex = 0,
    this.sourcePlugin = '',
    this.contentId,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;
  late PlaybackSession _playbackSession;
  late final HlsVariantResolver _hlsVariantResolver;
  late final PlaybackHealthCoordinator _playbackHealth;
  final PluginService _pluginService = PluginService();
  final HistoryCollectStore _historyStore = HistoryCollectStore();
  final DownloadService _downloadService = DownloadService();
  final DanmakuService _danmakuService = DanmakuService();
  final DanmakuController _danmakuController = DanmakuController();

  // 播放状态
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _showDanmaku = true; // 弹幕开关
  bool _showDanmakuPanel = false;
  bool _showShortcutPanel = false;
  bool _showEpisodeDrawer = false;
  bool _showNextEpisodePrompt = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  double _playbackSpeed = 1.0;
  double _danmakuOpacity = 1.0;
  double _danmakuArea = 1.0;
  double _danmakuSpeed = 1.0;
  double _danmakuFontScale = 1.0;
  DanmakuLoadResult _danmakuLoadResult = DanmakuLoadResult(
    status: DanmakuLoadStatus.notConfigured,
  );
  int _danmakuLoadGeneration = 0;
  String? _currentVideoUrl;
  bool _isOpeningVideo = false;
  bool _isReconnecting = false;
  bool _hasAudioSignal = false;
  bool _hasVideoSignal = false;
  bool _firstFrameRendered = false;
  _PlaybackIssue? _playbackIssue;
  PlaybackOpenRequest? _activeOpenRequest;
  int _openGeneration = 0;
  int _playbackRequestGeneration = 0;
  int _episodeLoadGeneration = 0;
  int _automaticRetryCount = 0;
  PlaybackDiagnosticsSession? _playbackDiagnostics;
  PlaybackDiagnosticsSnapshot? _lastPlaybackDiagnostics;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // 集数列表
  List<Episode> _episodes = [];
  int _currentEpisodeIndex = 0;
  bool _loadingEpisodes = false;

  bool get _isEpisodeDrawerVisible =>
      !_isFullscreen &&
      _showEpisodeDrawer &&
      (_episodes.isNotEmpty || _loadingEpisodes);

  String get _animeName =>
      widget.animeName.trim().isEmpty ? widget.title : widget.animeName;

  String get _playbackProviderId => widget.sourcePlugin.trim().isEmpty
      ? 'direct'
      : widget.sourcePlugin.trim();

  // 控制栏自动隐藏
  Timer? _hideTimer;
  bool _isHoveringControls = false;

  // 快进快退提示
  String? _seekHint;
  Timer? _seekHintTimer;
  Timer? _openTimeoutTimer;
  Timer? _bufferingTimeoutTimer;
  Timer? _noVideoTimer;
  Timer? _reconnectTimer;
  Duration _bufferingStartedPosition = Duration.zero;

  // Stream订阅管理（防止内存泄漏）
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
    );
    _playbackSession = PlaybackSession(_directPlaybackSources(widget.videoUrl));
    final http = HttpClient();
    final storage = StorageService();
    _hlsVariantResolver = HlsVariantResolver(
      loadManifest: (uri, headers) => http
          .getHtml(uri.toString(), headers: headers)
          .timeout(const Duration(seconds: 4)),
    );
    _playbackHealth = PlaybackHealthCoordinator(
      probes: PlaybackProbeService(load: DioPlaybackProbeLoader().call),
      repository: SettingsPlaybackRouteHealthRepository(
        read: (key) => storage.getSetting<Object>(key),
        write: storage.setSetting,
        remove: storage.removeSetting,
      ),
    );

    // 监听播放状态（存储订阅，dispose时cancel）
    _subscriptions.add(_player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    }));
    _subscriptions.add(_player.stream.position.listen((pos) {
      if (mounted) {
        final shouldShowNext = _shouldShowNextEpisodePrompt(pos, _duration);
        setState(() {
          _position = pos;
          _showNextEpisodePrompt = shouldShowNext;
        });
      }
    }));
    _subscriptions.add(_player.stream.duration.listen((dur) {
      if (mounted) {
        final shouldShowNext = _shouldShowNextEpisodePrompt(_position, dur);
        setState(() {
          _duration = dur;
          _showNextEpisodePrompt = shouldShowNext;
        });
      }
    }));
    _subscriptions.add(_player.stream.buffering.listen((buf) {
      _handleBufferingChanged(buf);
    }));
    _subscriptions.add(_player.stream.volume.listen((vol) {
      if (mounted) setState(() => _volume = vol);
    }));
    _subscriptions.add(_player.stream.audioParams.listen((params) {
      final detected = params.sampleRate != null || params.channelCount != null;
      if (mounted && detected != _hasAudioSignal) {
        setState(() => _hasAudioSignal = detected);
      }
    }));
    _subscriptions.add(_player.stream.videoParams.listen((params) {
      final width = params.w ?? params.dw ?? 0;
      final height = params.h ?? params.dh ?? 0;
      if (width > 0 && height > 0) _markVideoSignalDetected();
    }));
    _subscriptions.add(_player.stream.error.listen(_handlePlayerError));

    // 打开视频
    unawaited(
      _openPlaybackRequest(_playbackSession.openAt(Duration.zero)),
    );

    // 加载集数列表
    _loadEpisodes();

    // 启动控制栏自动隐藏
    _startHideTimer();

    // 检查当前视频是否已下载
    _checkDownloadStatus();

    final danmakuAppId = storage.getSetting<String>('dandanplay_app_id') ?? '';
    final danmakuAppSecret =
        storage.getSetting<String>('dandanplay_app_secret') ?? '';
    if (danmakuAppId.isNotEmpty && danmakuAppSecret.isNotEmpty) {
      _danmakuService.setCredentials(danmakuAppId, danmakuAppSecret);
    }

    // 同步播放位置到弹幕控制器
    _subscriptions.add(_player.stream.position.listen((pos) {
      if (mounted) {
        _danmakuController.updatePosition(pos.inMilliseconds / 1000.0);
      }
    }));

    // 加载弹幕
    _loadDanmaku();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state != AppLifecycleState.resumed) {
      _playbackDiagnostics?.suspendBuffering();
    }
  }

  List<PlaybackSource> _directPlaybackSources(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return const [];
    return [
      PlaybackSource(
        id: 'direct',
        label: '默认线路',
        kind: PlaybackSourceKind.direct,
        variants: [
          PlaybackVariant(
            id: 'direct-original',
            label: '原始',
            url: normalized,
            kind: PlaybackVariantKind.original,
          ),
        ],
      ),
    ];
  }

  Future<void> _openPlaybackRequest(
    PlaybackOpenRequest? request, {
    bool automaticRetry = false,
    bool resolveVariants = true,
    PlaybackDiagnosticsSession? diagnostics,
  }) async {
    final requestGeneration = ++_playbackRequestGeneration;
    if (request == null) {
      _showPlaybackIssue(
        const _PlaybackIssue(
          icon: Icons.link_off_rounded,
          title: '没有可用的视频地址',
          message: '当前线路没有返回有效地址，请返回详情页更换片源。',
        ),
      );
      return;
    }
    final diagnosticsSession =
        diagnostics ?? _playbackHealth.beginOpen(_openGeneration + 1);
    var effectiveRequest = request;
    if (resolveVariants) {
      diagnosticsSession.manifestStarted();
      if (mounted) setState(() {});
      final resolvedSource = await _hlsVariantResolver.resolve(request.source);
      if (!mounted || requestGeneration != _playbackRequestGeneration) return;
      diagnosticsSession.manifestResolved();
      _playbackSession.replaceSource(resolvedSource);
      effectiveRequest =
          _playbackSession.openAt(request.resumePosition) ?? request;
      setState(() {});
    }
    await _openVideo(
      effectiveRequest,
      automaticRetry: automaticRetry,
      diagnostics: diagnosticsSession,
    );
  }

  Future<void> _openVideo(
    PlaybackOpenRequest request, {
    bool automaticRetry = false,
    required PlaybackDiagnosticsSession diagnostics,
  }) async {
    final url = request.url;
    if (url.isEmpty || !mounted) return;
    _finishPlaybackDiagnostics();
    final generation = ++_openGeneration;
    _cancelPlaybackWatchdogs();
    if (!automaticRetry) _automaticRetryCount = 0;

    setState(() {
      _currentVideoUrl = url;
      _isOpeningVideo = true;
      _isReconnecting = automaticRetry;
      _isBuffering = true;
      _hasAudioSignal = false;
      _hasVideoSignal = false;
      _firstFrameRendered = false;
      _playbackIssue = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _showControls = true;
    });
    _activeOpenRequest = request;
    _playbackDiagnostics = diagnostics.openGeneration == generation
        ? diagnostics
        : _playbackHealth.beginOpen(generation);

    final headers = Map<String, String>.from(request.headers);
    if (!headers.containsKey('Referer') &&
        (url.contains('.m3u8') ||
            url.contains('/hls/') ||
            url.contains('type=hls'))) {
      final uri = Uri.tryParse(url);
      if (uri != null) headers['Referer'] = '${uri.scheme}://${uri.host}/';
    }

    _playbackDiagnostics?.openRequested();
    _startPlaybackWatchdogs(generation);
    try {
      await _player
          .open(Media(url, httpHeaders: headers))
          .timeout(const Duration(seconds: 20));
      if (!mounted || generation != _openGeneration) return;
      _playbackDiagnostics?.openCompleted();
      final resumePosition = request.resumePosition;
      if (resumePosition > const Duration(seconds: 1)) {
        await _player.seek(resumePosition);
      }
      if (!_firstFrameRendered) {
        unawaited(_waitForFirstFrame(generation));
      }
    } on TimeoutException catch (e) {
      _playbackDiagnostics?.fail(PlaybackFailureKind.timeout);
      Log.e('Player', '连接视频源超时: $url', e);
      _recoverOrShow(
        const _PlaybackIssue(
          icon: Icons.timer_off_outlined,
          title: '连接视频源超时',
          message: '视频服务器响应过慢，薇拉已尝试重新连接。',
        ),
        generation,
      );
    } catch (e) {
      _playbackDiagnostics?.fail(_failureKindFromError(e.toString()));
      Log.e('Player', '播放失败: $url', e);
      _recoverOrShow(_issueFromError(e.toString()), generation);
    }
  }

  void _startPlaybackWatchdogs(int generation) {
    _openTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || generation != _openGeneration) return;
      if (_position > const Duration(seconds: 1) || _hasVideoSignal) return;
      _playbackDiagnostics?.fail(PlaybackFailureKind.timeout);
      _recoverOrShow(
        const _PlaybackIssue(
          icon: Icons.wifi_tethering_error_rounded,
          title: '视频加载时间过长',
          message: '当前线路暂时不可用，可以重新加载或切换其他线路。',
        ),
        generation,
      );
    });

    _noVideoTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || generation != _openGeneration || _hasVideoSignal) return;
      final mediaIsAdvancing = _position > const Duration(seconds: 2);
      if (_hasAudioSignal || mediaIsAdvancing) {
        _playbackDiagnostics?.fail(PlaybackFailureKind.noVideo);
        _recoverOrShow(
          const _PlaybackIssue(
            icon: Icons.videocam_off_outlined,
            title: '未检测到视频画面',
            message: '音频已经开始播放，但解码器没有返回视频画面。请重新加载或切换线路。',
          ),
          generation,
        );
      }
    });
  }

  Future<void> _waitForFirstFrame(int generation) async {
    try {
      await _controller.waitUntilFirstFrameRendered
          .timeout(const Duration(seconds: 15));
      if (!mounted || generation != _openGeneration) return;
      _recordFirstFrame();
      _markVideoSignalDetected();
    } on TimeoutException {
      if (!mounted || generation != _openGeneration || _hasVideoSignal) return;
      if (_hasAudioSignal || _position > const Duration(seconds: 2)) {
        _playbackDiagnostics?.fail(PlaybackFailureKind.noVideo);
        _recoverOrShow(
          const _PlaybackIssue(
            icon: Icons.videocam_off_outlined,
            title: '视频画面渲染失败',
            message: '已经收到音频，但首帧未能渲染。请重新加载或尝试其他线路。',
          ),
          generation,
        );
      }
    }
  }

  void _markVideoSignalDetected() {
    if (!mounted) return;
    _recordFirstFrame();
    if (_hasVideoSignal && !_isOpeningVideo && !_isReconnecting) return;
    _openTimeoutTimer?.cancel();
    _noVideoTimer?.cancel();
    setState(() {
      _hasVideoSignal = true;
      _isOpeningVideo = false;
      _isReconnecting = false;
      _automaticRetryCount = 0;
    });
  }

  void _handleBufferingChanged(bool buffering) {
    if (!mounted) return;
    if (_appLifecycleState == AppLifecycleState.resumed) {
      _playbackDiagnostics?.bufferingChanged(buffering);
    }
    setState(() => _isBuffering = buffering);
    _bufferingTimeoutTimer?.cancel();
    if (!buffering) {
      if (_hasVideoSignal && _isOpeningVideo) {
        setState(() => _isOpeningVideo = false);
      }
      return;
    }

    final generation = _openGeneration;
    _bufferingStartedPosition = _position;
    _bufferingTimeoutTimer = Timer(const Duration(seconds: 25), () {
      if (!mounted || generation != _openGeneration || !_isBuffering) return;
      final advanced = _position - _bufferingStartedPosition;
      if (advanced > const Duration(seconds: 1)) return;
      _playbackDiagnostics?.fail(PlaybackFailureKind.network);
      _recoverOrShow(
        const _PlaybackIssue(
          icon: Icons.signal_wifi_connected_no_internet_4_rounded,
          title: '视频缓冲超时',
          message: '网络或视频服务器没有继续传输数据，可以重新加载当前进度。',
        ),
        generation,
      );
    });
  }

  void _handlePlayerError(String message) {
    if (!mounted || message.trim().isEmpty) return;
    _playbackDiagnostics?.fail(_failureKindFromError(message));
    Log.e('Player', 'media_kit: $message');
    _recoverOrShow(_issueFromError(message), _openGeneration);
  }

  _PlaybackIssue _issueFromError(String error) {
    final message = error.toLowerCase();
    if (message.contains('403') || message.contains('forbidden')) {
      return const _PlaybackIssue(
        icon: Icons.lock_outline_rounded,
        title: '视频源拒绝访问',
        message: '该线路需要特定访问权限，请切换线路后重试。',
      );
    }
    if (message.contains('404') || message.contains('not found')) {
      return const _PlaybackIssue(
        icon: Icons.link_off_rounded,
        title: '视频地址已经失效',
        message: '当前集数的播放地址不可用，请切换线路或稍后再试。',
      );
    }
    if (message.contains('decode') ||
        message.contains('codec') ||
        message.contains('hwdec')) {
      return const _PlaybackIssue(
        icon: Icons.broken_image_outlined,
        title: '视频解码失败',
        message: '当前视频编码暂时无法解析，请重新加载或切换线路。',
      );
    }
    if (message.contains('timeout') || message.contains('timed out')) {
      return const _PlaybackIssue(
        icon: Icons.timer_off_outlined,
        title: '连接视频源超时',
        message: '网络连接时间过长，请检查网络后重新加载。',
      );
    }
    return const _PlaybackIssue(
      icon: Icons.error_outline_rounded,
      title: '视频播放中断',
      message: '播放器遇到异常，薇拉可以重新加载当前视频。',
    );
  }

  PlaybackFailureKind _failureKindFromError(String error) {
    final message = error.toLowerCase();
    if (message.contains('403') || message.contains('forbidden')) {
      return PlaybackFailureKind.forbidden;
    }
    if (message.contains('404') || message.contains('not found')) {
      return PlaybackFailureKind.notFound;
    }
    if (message.contains('decode') ||
        message.contains('codec') ||
        message.contains('hwdec')) {
      return PlaybackFailureKind.decode;
    }
    if (message.contains('timeout') || message.contains('timed out')) {
      return PlaybackFailureKind.timeout;
    }
    if (message.contains('500') ||
        message.contains('502') ||
        message.contains('503')) {
      return PlaybackFailureKind.server;
    }
    return PlaybackFailureKind.unknown;
  }

  void _recoverOrShow(_PlaybackIssue issue, int generation) {
    if (!mounted || generation != _openGeneration || _playbackIssue != null) {
      return;
    }
    if (_reconnectTimer?.isActive ?? false) return;
    final activeRequest = _activeOpenRequest;
    final sourceCount = _playbackSession.sources.length;
    final maximumRecoveries = sourceCount > 1 ? sourceCount - 1 : 1;
    if (_automaticRetryCount < maximumRecoveries && activeRequest != null) {
      final recoveryRequest = sourceCount > 1
          ? _playbackSession.selectNextSourceAfter(
              activeRequest.source.id,
              _position,
            )
          : PlaybackOpenRequest(
              source: activeRequest.source,
              variant: activeRequest.variant,
              resumePosition: _position,
            );
      if (recoveryRequest == null) {
        _showPlaybackIssue(issue);
        return;
      }
      _automaticRetryCount++;
      _cancelPlaybackWatchdogs();
      unawaited(_player.stop());
      setState(() {
        _isOpeningVideo = true;
        _isReconnecting = true;
        _isBuffering = true;
      });
      _reconnectTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || generation != _openGeneration) return;
        unawaited(
          _openPlaybackRequest(
            recoveryRequest,
            automaticRetry: true,
            resolveVariants:
                recoveryRequest.source.id != activeRequest.source.id,
          ),
        );
      });
      return;
    }
    _showPlaybackIssue(issue);
  }

  void _showPlaybackIssue(_PlaybackIssue issue) {
    if (!mounted) return;
    _cancelPlaybackWatchdogs();
    unawaited(_player.pause());
    _finishPlaybackDiagnostics();
    setState(() {
      _playbackIssue = issue;
      _isOpeningVideo = false;
      _isReconnecting = false;
      _isBuffering = false;
      _showControls = true;
    });
  }

  void _recordFirstFrame() {
    if (_firstFrameRendered) return;
    _firstFrameRendered = true;
    _playbackDiagnostics?.firstFrameRendered();
  }

  void _finishPlaybackDiagnostics() {
    final diagnostics = _playbackDiagnostics;
    final source = _activeOpenRequest?.source;
    if (diagnostics == null) return;
    final snapshot = diagnostics.end();
    _playbackDiagnostics = null;
    _lastPlaybackDiagnostics = snapshot;
    if (source == null) return;
    unawaited(
      _playbackHealth.finishOpen(
        providerId: _playbackProviderId,
        source: source,
        diagnostics: snapshot,
        playedDuration: _position,
      ),
    );
  }

  void _retryCurrentVideo() {
    final activeRequest = _activeOpenRequest;
    if (activeRequest == null) return;
    _automaticRetryCount = 0;
    unawaited(
      _openPlaybackRequest(
        PlaybackOpenRequest(
          source: activeRequest.source,
          variant: activeRequest.variant,
          resumePosition: _position,
        ),
        resolveVariants: false,
      ),
    );
  }

  ResolvedPlayback? get _resolvedPlayback =>
      _playbackSession.selection.resolve(_playbackSession.sources);

  int get _currentSourceIndex {
    final resolved = _resolvedPlayback;
    if (resolved == null) return 0;
    final index = _playbackSession.sources.indexWhere(
      (source) => source.id == resolved.source.id,
    );
    return index < 0 ? 0 : index;
  }

  int get _currentSourceCount => _playbackSession.sources.length;

  bool get _hasNextVideoSource => _currentSourceIndex + 1 < _currentSourceCount;

  void _switchToNextVideoSource() {
    if (!_hasNextVideoSource) return;
    _automaticRetryCount = 0;
    unawaited(
      _openPlaybackRequest(
        _playbackSession.selectNextSource(_position),
      ),
    );
  }

  void _cancelPlaybackWatchdogs() {
    _openTimeoutTimer?.cancel();
    _bufferingTimeoutTimer?.cancel();
    _noVideoTimer?.cancel();
    _reconnectTimer?.cancel();
  }

  Future<void> _loadEpisodes() async {
    if (widget.animeUrl.isEmpty) return;
    setState(() => _loadingEpisodes = true);

    try {
      final anime = _pageAnime;
      var playbackEpisodes = <PlaybackEpisode>[];
      List<Episode> eps;
      if (anime.sourcePlugin.startsWith('cms_')) {
        playbackEpisodes = await _pluginService.getPlaybackEpisodes(anime);
        eps = playbackEpisodes
            .map(
              (episode) => Episode(
                name: episode.name,
                index: episode.index,
                url: const PlaybackSelection.auto()
                        .resolve(episode.sources)
                        ?.variant
                        .url ??
                    '',
              ),
            )
            .toList(growable: false);
        if (widget.episodeIndex >= 0 &&
            widget.episodeIndex < playbackEpisodes.length &&
            widget.episodeIndex < eps.length) {
          final resolvedCurrent = await _pluginService.resolvePlaybackEpisode(
            anime: anime,
            episode: eps[widget.episodeIndex],
          );
          playbackEpisodes = List<PlaybackEpisode>.from(playbackEpisodes)
            ..[widget.episodeIndex] = resolvedCurrent;
          final resolved =
              const PlaybackSelection.auto().resolve(resolvedCurrent.sources);
          if (resolved != null) {
            eps[widget.episodeIndex] = Episode(
              name: eps[widget.episodeIndex].name,
              index: eps[widget.episodeIndex].index,
              url: resolved.variant.url,
            );
          }
        }
      } else {
        eps = await _pluginService.getEpisodes(anime);
      }
      if (mounted) {
        PlaybackSession? sessionToHydrate;
        setState(() {
          _episodes = eps;
          _currentEpisodeIndex = widget.episodeIndex;
          _loadingEpisodes = false;
          if (playbackEpisodes.isNotEmpty &&
              widget.episodeIndex >= 0 &&
              widget.episodeIndex < playbackEpisodes.length &&
              playbackEpisodes[widget.episodeIndex].sources.isNotEmpty) {
            sessionToHydrate = PlaybackSession(
              playbackEpisodes[widget.episodeIndex].sources,
            );
            _playbackSession = sessionToHydrate!;
          }
        });
        if (sessionToHydrate != null) {
          unawaited(
            _openPlaybackRequest(
              sessionToHydrate!.openAt(_position),
            ),
          );
        }
      }
    } catch (e) {
      Log.d('Player', '加载集数失败: $e');
      if (mounted) setState(() => _loadingEpisodes = false);
    }
  }

  void _playEpisode(int index) async {
    if (index < 0 || index >= _episodes.length) return;
    final loadGeneration = ++_episodeLoadGeneration;
    final diagnostics = _playbackHealth.beginOpen(_openGeneration + 1)
      ..sourceResolveStarted();
    setState(() {
      _currentEpisodeIndex = index;
      _isOpeningVideo = true;
      _playbackIssue = null;
      _showControls = true;
    });
    _danmakuController.loadDanmaku(const []);
    final ep = _episodes[index];

    try {
      final playbackEpisode = await _pluginService.resolvePlaybackEpisode(
        anime: _pageAnime,
        episode: ep,
      );
      diagnostics.sourceResolved();
      if (loadGeneration != _episodeLoadGeneration || !mounted) return;
      if (playbackEpisode.sources.isNotEmpty) {
        final orderedSources = playbackEpisode.sources.length > 1
            ? await _playbackHealth.prepareAutoSources(
                providerId: _playbackProviderId,
                sources: playbackEpisode.sources,
              )
            : playbackEpisode.sources;
        if (loadGeneration != _episodeLoadGeneration || !mounted) return;
        _playbackSession = PlaybackSession(orderedSources);
        await _openPlaybackRequest(
          _playbackSession.openAt(Duration.zero),
          diagnostics: diagnostics,
        );
        if (mounted) _loadDanmaku();
        return;
      }
    } catch (e) {
      diagnostics.fail(PlaybackFailureKind.network);
      Log.d('Player', '获取视频源失败: $e');
    }

    if (mounted) {
      _showPlaybackIssue(
        _PlaybackIssue(
          icon: Icons.link_off_rounded,
          title: '「${ep.name}」暂无可用线路',
          message: '当前视频源没有返回播放地址，请返回详情页更换片源。',
        ),
      );
    }
  }

  Anime get _pageAnime => Anime(
        name: widget.title,
        url: widget.animeUrl,
        sourcePlugin:
            widget.sourcePlugin.isNotEmpty ? widget.sourcePlugin : 'bangumi',
      );

  Future<void> _selectAutomaticSource() async {
    final session = _playbackSession;
    final ordered = session.sources.length > 1
        ? await _playbackHealth.prepareAutoSources(
            providerId: _playbackProviderId,
            sources: session.sources,
          )
        : session.sources;
    if (!mounted || !identical(_playbackSession, session)) return;
    session.replaceSources(ordered);
    final request = session.selectAuto(_position);
    if (request == null) return;
    setState(() {});
    await _openPlaybackRequest(request);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: 3), () {
      if (mounted &&
          _isPlaying &&
          !_isHoveringControls &&
          _playbackIssue == null) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onMouseMove() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startHideTimer();
  }

  void _seekBy(Duration offset) {
    final newPos = _position + offset;
    if (newPos < Duration.zero) {
      _player.seek(Duration.zero);
    } else if (newPos > _duration) {
      _player.seek(_duration);
    } else {
      _player.seek(newPos);
    }
    _showSeekHint(offset);
  }

  void _showSeekHint(Duration offset) {
    final seconds = offset.inSeconds;
    final text = seconds > 0 ? '+${seconds}s' : '${seconds}s';
    setState(() => _seekHint = text);
    _seekHintTimer?.cancel();
    _seekHintTimer = Timer(Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekHint = null);
    });
  }

  void _togglePlay() {
    if (_playbackIssue != null || _isOpeningVideo) return;
    _player.playOrPause();
    _startHideTimer();
  }

  bool _shouldShowNextEpisodePrompt(Duration position, Duration duration) {
    if (_episodes.isEmpty) return false;
    if (_currentEpisodeIndex >= _episodes.length - 1) return false;
    if (duration.inSeconds <= 60) return false;
    final remain = duration - position;
    return remain.inSeconds <= 30 && remain.inSeconds >= 0;
  }

  void _toggleDanmakuPanel() {
    setState(() {
      _showDanmakuPanel = !_showDanmakuPanel;
      if (_showDanmakuPanel) _showShortcutPanel = false;
    });
    _startHideTimer();
  }

  void _toggleShortcutPanel() {
    setState(() {
      _showShortcutPanel = !_showShortcutPanel;
      if (_showShortcutPanel) _showDanmakuPanel = false;
    });
    _startHideTimer();
  }

  void _playNextEpisode() {
    if (_currentEpisodeIndex + 1 >= _episodes.length) return;
    setState(() => _showNextEpisodePrompt = false);
    _playEpisode(_currentEpisodeIndex + 1);
  }

  void _applyDanmakuOpacity(double value) {
    setState(() => _danmakuOpacity = value);
    _danmakuController.setOpacity(value);
  }

  void _applyDanmakuArea(double value) {
    setState(() => _danmakuArea = value);
    _danmakuController.setArea(value);
  }

  void _applyDanmakuSpeed(double value) {
    setState(() => _danmakuSpeed = value);
    _danmakuController.setSpeed(value);
  }

  void _applyDanmakuFontScale(double value) {
    setState(() => _danmakuFontScale = value);
    _danmakuController.setFontSizeScale(value);
  }

  void _toggleFullscreen() async {
    final goingFullscreen = !_isFullscreen;
    setState(() => _isFullscreen = goingFullscreen);
    if (goingFullscreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
    }
  }

  void _checkDownloadStatus() async {
    final url = _currentVideoUrl ?? widget.videoUrl;
    final downloaded = await _downloadService.isDownloaded(url);
    final allDownloads = _downloadService.getAllDownloads();
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
        _isDownloading =
            allDownloads.any((d) => d.episodeUrl == url && d.status == 1);
      });
    }
  }

  Future<void> _loadDanmaku({bool refresh = false}) async {
    final generation = ++_danmakuLoadGeneration;
    final episode = _currentEpisodeIndex + 1;
    if (mounted) {
      setState(() {
        _danmakuLoadResult = DanmakuLoadResult(
          status: _danmakuService.hasCredentials
              ? DanmakuLoadStatus.searching
              : DanmakuLoadStatus.notConfigured,
        );
      });
    }
    _danmakuController.loadDanmaku(const []);

    final result = await _danmakuService.load(
      anime: _animeName,
      episode: episode,
      refresh: refresh,
    );
    if (!mounted || generation != _danmakuLoadGeneration) return;
    _danmakuController.loadDanmaku(result.items);
    setState(() => _danmakuLoadResult = result);
    Log.d(
      'Player',
      '弹幕状态: ${result.status.name}, 数量: ${result.items.length}',
    );
  }

  Future<void> _chooseDanmakuCandidate(
    DanmakuMatchCandidate candidate,
  ) async {
    final generation = ++_danmakuLoadGeneration;
    setState(() {
      _danmakuLoadResult = DanmakuLoadResult(
        status: DanmakuLoadStatus.loading,
        selected: candidate,
      );
    });
    final result = await _danmakuService.choose(
      anime: _animeName,
      episode: _currentEpisodeIndex + 1,
      candidate: candidate,
    );
    if (!mounted || generation != _danmakuLoadGeneration) return;
    _danmakuController.loadDanmaku(result.items);
    setState(() => _danmakuLoadResult = result);
  }

  void _startDownload() {
    final url = _currentVideoUrl ?? widget.videoUrl;
    if (url.isEmpty) return;

    final epName =
        _episodes.isNotEmpty && _currentEpisodeIndex < _episodes.length
            ? _episodes[_currentEpisodeIndex].name
            : widget.title;

    final item = PlaybackEntryFactory.download(
      animeName: _animeName,
      animeUrl: widget.animeUrl,
      coverUrl: widget.coverUrl,
      episodeName: epName,
      episodeUrl: url,
      sourcePlugin: widget.sourcePlugin,
      contentId: widget.contentId,
      episodeId: 'episode:${_currentEpisodeIndex + 1}',
    );

    // 自动设置 Referer（m3u8 CDN 需要）
    try {
      final uri = Uri.parse(url);
      item.referer = '${uri.scheme}://${uri.host}/';
    } catch (_) {}

    // DEBUG: 确认 Referer 已设置
    _downloadService.addDownload(item);
    setState(() => _isDownloading = true);

    ErrorHandler.showInfo(context, '已添加缓存: $epName');
  }

  @override
  void dispose() {
    _openGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _playbackDiagnostics?.suspendBuffering();
    _finishPlaybackDiagnostics();
    _cancelPlaybackWatchdogs();
    // 取消所有Stream订阅，防止内存泄漏
    for (final s in _subscriptions) {
      s.cancel();
    }
    _hideTimer?.cancel();
    _seekHintTimer?.cancel();

    // 退出时恢复窗口状态（用 postFrameCallback 避免 dispose 中异步问题）
    if (_isFullscreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        windowManager.setFullScreen(false);
      });
    }

    // 释放弹幕控制器
    _danmakuController.dispose();

    // 记录观看历史（用实际播放的URL，不是初始URL）
    final epName =
        _episodes.isNotEmpty && _currentEpisodeIndex < _episodes.length
            ? _episodes[_currentEpisodeIndex].name
            : widget.title;
    _historyStore.addHistory(PlaybackEntryFactory.history(
      animeName: _animeName,
      animeUrl: widget.animeUrl.isNotEmpty ? widget.animeUrl : widget.videoUrl,
      coverUrl: widget.coverUrl,
      episodeName: epName,
      episodeUrl: _currentVideoUrl ?? widget.videoUrl,
      sourcePlugin: widget.sourcePlugin,
      position: _position,
      duration: _duration,
      contentId: widget.contentId,
      episodeId: 'episode:${_currentEpisodeIndex + 1}',
    ));

    _player.dispose();
    _historyStore.dispose();
    super.dispose();
  }

  // 键盘快捷键
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _togglePlay();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _seekBy(Duration(seconds: -5));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _seekBy(Duration(seconds: 5));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _player.setVolume((_volume + 5).clamp(0, 100));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _player.setVolume((_volume - 5).clamp(0, 100));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyD:
        setState(() => _showDanmaku = !_showDanmaku);
        _danmakuController.setVisible(_showDanmaku);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.slash:
        _toggleShortcutPanel();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_showShortcutPanel || _showDanmakuPanel) {
          setState(() {
            _showShortcutPanel = false;
            _showDanmakuPanel = false;
          });
          return KeyEventResult.handled;
        } else if (_isEpisodeDrawerVisible) {
          setState(() => _showEpisodeDrawer = false);
          return KeyEventResult.handled;
        } else if (_isFullscreen) {
          _toggleFullscreen();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _togglePlay,
          onDoubleTap: _toggleFullscreen,
          child: MouseRegion(
            onHover: (_) => _onMouseMove(),
            child: Stack(
              children: [
                // 视频渲染层
                Row(
                  children: [
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Video(
                            controller: _controller,
                            controls: NoVideoControls,
                          ),
                          if (_showDanmaku && _playbackIssue == null)
                            DanmakuOverlay(controller: _danmakuController),
                          if (_playbackIssue != null)
                            Positioned.fill(
                              child: _buildPlaybackIssuePanel(_playbackIssue!),
                            )
                          else if (_isOpeningVideo || _isBuffering)
                            _buildBufferingIndicator(),
                          if (_seekHint != null) _buildSeekHint(),
                        ],
                      ),
                    ),
                    EpisodeDrawerMotion(
                      open: _isEpisodeDrawerVisible,
                      child: _buildEpisodeSidebar(),
                    ),
                  ],
                ),

                if (_showNextEpisodePrompt && _showControls)
                  Positioned(
                    right: _isEpisodeDrawerVisible ? 244 : 24,
                    bottom: 128,
                    child: _buildNextEpisodePrompt(),
                  ),

                if (_showShortcutPanel) Center(child: _buildShortcutPanel()),

                if (_showDanmakuPanel)
                  Positioned(
                    right: _isEpisodeDrawerVisible ? 244 : 24,
                    top: 86,
                    child: _buildDanmakuPanel(),
                  ),

                if (_showControls)
                  Positioned(
                    left: 0,
                    right: _isEpisodeDrawerVisible ? 220 : 0,
                    bottom: 0,
                    child: MouseRegion(
                      onEnter: (_) => _isHoveringControls = true,
                      onExit: (_) => _isHoveringControls = false,
                      child: _buildControls(),
                    ),
                  ),

                if (_showControls)
                  Positioned(
                    left: 0,
                    right: _isEpisodeDrawerVisible ? 220 : 0,
                    top: 0,
                    child: _buildTopBar(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部标题栏
  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.zero,
      child: SafeArea(
        bottom: false,
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.34),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
              ),
              child: Row(
                children: [
                  _PlayerIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: '返回',
                    onTap: () => Modular.to.pop(),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 2,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_episodes.isNotEmpty &&
                            _currentEpisodeIndex < _episodes.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              _episodes[_currentEpisodeIndex].name,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.58),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    key: const ValueKey('player-expandable-toolbar'),
                    width: 360,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ExpandableToolTabs(
                        items: [
                          if (_episodes.isNotEmpty || _loadingEpisodes)
                            ExpandableToolTab(
                              id: 'episodes',
                              icon: Icons.playlist_play_rounded,
                              label: '选集',
                              tooltip:
                                  _isEpisodeDrawerVisible ? '关闭选集' : '打开选集',
                            ),
                          ExpandableToolTab(
                            id: 'danmaku',
                            icon: _showDanmaku
                                ? Icons.subtitles_rounded
                                : Icons.subtitles_off_rounded,
                            label: _showDanmaku ? '弹幕开' : '弹幕关',
                            tooltip: _showDanmaku ? '关闭弹幕' : '打开弹幕',
                          ),
                          const ExpandableToolTab(
                            id: 'danmaku-settings',
                            icon: Icons.tune_rounded,
                            label: '弹幕设置',
                            tooltip: '弹幕设置',
                          ),
                          ExpandableToolTab(
                            id: 'download',
                            icon: _isDownloading
                                ? Icons.downloading_rounded
                                : Icons.download_rounded,
                            label: _isDownloaded ? '已缓存' : '缓存',
                            tooltip: _isDownloaded ? '已缓存' : '缓存本集',
                          ),
                          const ExpandableToolTab(
                            id: 'shortcuts',
                            icon: Icons.keyboard_command_key_rounded,
                            label: '快捷键',
                            tooltip: '快捷键',
                          ),
                        ],
                        selectedId: _isEpisodeDrawerVisible
                            ? 'episodes'
                            : _showDanmakuPanel
                                ? 'danmaku-settings'
                                : _showShortcutPanel
                                    ? 'shortcuts'
                                    : _isDownloaded || _isDownloading
                                        ? 'download'
                                        : _showDanmaku
                                            ? 'danmaku'
                                            : null,
                        foregroundColor: Colors.white.withValues(alpha: 0.72),
                        selectedColor: AppTheme.accentBlue,
                        onSelected: (id) {
                          switch (id) {
                            case 'episodes':
                              setState(
                                () => _showEpisodeDrawer = !_showEpisodeDrawer,
                              );
                            case 'danmaku':
                              setState(() => _showDanmaku = !_showDanmaku);
                              _danmakuController.setVisible(_showDanmaku);
                            case 'danmaku-settings':
                              _toggleDanmakuPanel();
                            case 'download':
                              if (!_isDownloaded && !_isDownloading) {
                                _startDownload();
                              }
                            case 'shortcuts':
                              _toggleShortcutPanel();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 底部控制栏
  Widget _buildControls() {
    final resolved = _resolvedPlayback;
    final sourceOptions = <PlayerControlMenuOption>[
      PlayerControlMenuOption(
        id: 'auto',
        label: '自动',
        selected: _playbackSession.selection.sourceId == null,
        detail: resolved == null ? null : '实际使用 ${resolved.source.label}',
      ),
      for (final source in _playbackSession.sources)
        PlayerControlMenuOption(
          id: source.id,
          label: source.label,
          selected: _playbackSession.selection.sourceId == source.id,
          detail: _healthDetail(source),
        ),
    ];
    final qualityOptions = resolved == null ||
            resolved.source.variants.length <= 1
        ? const <PlayerControlMenuOption>[]
        : <PlayerControlMenuOption>[
            PlayerControlMenuOption(
              id: 'auto',
              label: '自动',
              selected: _playbackSession.selection.variantId == null,
            ),
            for (final variant in resolved.source.variants)
              PlayerControlMenuOption(
                id: variant.id,
                label: variant.label,
                selected: _playbackSession.selection.variantId == variant.id,
              ),
          ];
    return PlayerControlBar(
      position: _position,
      duration: _duration,
      playing: _isPlaying,
      volume: _volume,
      playbackSpeed: _playbackSpeed,
      fullscreen: _isFullscreen,
      canPlayNext:
          _episodes.isNotEmpty && _currentEpisodeIndex < _episodes.length - 1,
      onSeek: _player.seek,
      onRewind: () => _seekBy(const Duration(seconds: -5)),
      onTogglePlay: _togglePlay,
      onForward: () => _seekBy(const Duration(seconds: 5)),
      onPlayNext: _playNextEpisode,
      onVolumeChanged: (value) {
        setState(() => _volume = value);
        _player.setVolume(value);
      },
      onSpeedChanged: (speed) {
        setState(() => _playbackSpeed = speed);
        _player.setRate(speed);
      },
      onToggleFullscreen: _toggleFullscreen,
      sourceOptions:
          _playbackSession.sources.isEmpty ? const [] : sourceOptions,
      qualityOptions: qualityOptions,
      qualityUnavailableMessage:
          resolved != null && resolved.source.variants.length <= 1
              ? '当前线路未提供可切换清晰度'
              : null,
      onSourceSelected: (sourceId) {
        if (sourceId == 'auto') {
          unawaited(_selectAutomaticSource());
          return;
        }
        final request = _playbackSession.selectSource(sourceId, _position);
        if (request == null) return;
        setState(() {});
        unawaited(_openPlaybackRequest(request));
      },
      onQualitySelected: (variantId) {
        final request = variantId == 'auto'
            ? _playbackSession.selectAutoVariant(_position)
            : _playbackSession.selectVariant(variantId, _position);
        if (request == null) return;
        setState(() {});
        unawaited(
          _openPlaybackRequest(request, resolveVariants: false),
        );
      },
    );
  }

  Widget _buildBufferingIndicator() {
    final stage = _playbackDiagnostics?.snapshot.stage;
    final title = _isReconnecting
        ? '正在重新连接'
        : _isOpeningVideo
            ? '正在连接视频源'
            : '正在缓冲视频';
    final subtitle = _isReconnecting
        ? '自动切换 $_automaticRetryCount/'
            '${_currentSourceCount > 1 ? _currentSourceCount - 1 : 1}'
        : switch (stage) {
            PlaybackDiagnosticStage.resolvingSource => '解析播放源',
            PlaybackDiagnosticStage.resolvingManifest => '读取清晰度',
            PlaybackDiagnosticStage.opening => '连接视频源',
            PlaybackDiagnosticStage.waitingForFirstFrame => '等待首帧',
            _ => _isOpeningVideo ? '等待首帧' : '正在等待视频数据',
          };
    return PlayerLoadingOverlay(title: title, subtitle: subtitle);
  }

  Widget _buildPlaybackIssuePanel(_PlaybackIssue issue) {
    final resolved = _resolvedPlayback;
    return PlayerDiagnosticsOverlay(
      issue: PlayerDiagnosticIssue(
        icon: issue.icon,
        title: issue.title,
        message: issue.message,
        sourceLabel: resolved?.source.label,
        variantLabel: _playbackSession.selection.variantId == null
            ? '自动'
            : resolved?.variant.label,
      ),
      currentSourceIndex: _currentSourceIndex,
      sourceCount: _currentSourceCount,
      position: _position,
      metrics: _diagnosticMetrics,
      onRetry: _retryCurrentVideo,
      onSwitchSource: _hasNextVideoSource ? _switchToNextVideoSource : null,
      onBack: () => Modular.to.pop(),
    );
  }

  PlaybackRouteHealth? _routeHealth(PlaybackSource source) {
    final url = source.variants.isEmpty ? '' : source.variants.first.url;
    final host = Uri.tryParse(url)?.host ?? '';
    final key = PlaybackRouteKey(
      providerId: _playbackProviderId,
      sourceKind: source.kind.name,
      sourceId: source.id,
      host: host,
    );
    return _playbackHealth.health[key.storageKey];
  }

  String _healthDetail(PlaybackSource source) {
    final health = _routeHealth(source);
    if (health == null || !health.hasEnoughSamples) return '未知';
    final firstFrame = health.firstFrameMs < 1000
        ? '${health.firstFrameMs.round()}ms'
        : '${(health.firstFrameMs / 1000).toStringAsFixed(1)}s';
    return '${health.label} · 首帧 $firstFrame';
  }

  PlayerDiagnosticMetrics get _diagnosticMetrics {
    final snapshot = _lastPlaybackDiagnostics ?? _playbackDiagnostics?.snapshot;
    if (snapshot == null) return const PlayerDiagnosticMetrics();
    return PlayerDiagnosticMetrics(
      sourceResolveDuration: snapshot.sourceResolveDuration,
      manifestDuration: snapshot.manifestDuration,
      firstFrameDuration: snapshot.firstFrameDuration,
      rebufferCount: snapshot.rebufferCount,
      totalRebufferDuration: snapshot.totalRebufferDuration,
      autoSwitchCount: 0,
    );
  }

  Widget _buildSeekHint() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.22)),
          ),
          child: Text(
            _seekHint!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNextEpisodePrompt() {
    final nextIndex = _currentEpisodeIndex + 1;
    final next = _episodes[nextIndex];
    return PlayerNextEpisodePrompt(
      episodeName: next.name,
      onPlay: _playNextEpisode,
      onDismiss: () => setState(() => _showNextEpisodePrompt = false),
    );
  }

  Widget _buildDanmakuPanel() {
    return PlayerDanmakuSettingsPanel(
      visible: _showDanmaku,
      opacity: _danmakuOpacity,
      area: _danmakuArea,
      speed: _danmakuSpeed,
      fontScale: _danmakuFontScale,
      loadResult: _danmakuLoadResult,
      onToggleVisible: () {
        setState(() => _showDanmaku = !_showDanmaku);
        _danmakuController.setVisible(_showDanmaku);
      },
      onOpacityChanged: _applyDanmakuOpacity,
      onAreaChanged: _applyDanmakuArea,
      onSpeedChanged: _applyDanmakuSpeed,
      onFontScaleChanged: _applyDanmakuFontScale,
      onRefresh: () => _loadDanmaku(refresh: true),
      onCandidateSelected: _chooseDanmakuCandidate,
    );
  }

  Widget _buildShortcutPanel() {
    return PlayerShortcutPanel(onClose: _toggleShortcutPanel);
  }

  Widget _buildEpisodeSidebar() {
    return EpisodeSidebar(
      episodes: _episodes,
      currentIndex: _currentEpisodeIndex,
      loading: _loadingEpisodes,
      onClose: () => setState(() => _showEpisodeDrawer = false),
      onEpisodeTap: (index) {
        setState(() => _showEpisodeDrawer = false);
        _playEpisode(index);
      },
    );
  }
}
