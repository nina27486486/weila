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
import '../../services/diagnostics/acceptance_report.dart';
import '../../services/diagnostics/acceptance_report_service.dart';
import '../../services/library/playback_entry_factory.dart';
import '../../services/playback/hls_variant_resolver.dart';
import '../../services/playback/playback_diagnostics.dart';
import '../../services/playback/playback_error_sanitizer.dart';
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
import 'player_danmaku_session.dart';
import 'player_episode_selection.dart';
import 'player_playback_lifecycle_coordinator.dart';

part 'widgets/player_page_components.dart';
part 'widgets/player_page_view.dart';

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
  final PlayerPlaybackLifecycleCoordinator _playbackLifecycle =
      PlayerPlaybackLifecycleCoordinator();
  final PluginService _pluginService = PluginService();
  final HistoryCollectStore _historyStore = HistoryCollectStore();
  final DownloadService _downloadService = DownloadService();
  late final PlayerDanmakuSession _danmakuSession;
  final AcceptanceReportService _acceptanceReports = AcceptanceReportService();

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
  DanmakuController get _danmakuController => _danmakuSession.controller;
  DanmakuLoadResult get _danmakuLoadResult => _danmakuSession.result;
  String? _currentVideoUrl;
  bool _isOpeningVideo = false;
  bool _isReconnecting = false;
  bool _hasAudioSignal = false;
  bool _hasVideoSignal = false;
  bool _firstFrameRendered = false;
  _PlaybackIssue? _playbackIssue;
  PlaybackOpenRequest? _activeOpenRequest;
  int _playbackRequestGeneration = 0;
  int _episodeLoadGeneration = 0;
  int _automaticRetryCount = 0;
  PlaybackDiagnosticsSession? _playbackDiagnostics;
  PlaybackDiagnosticsSnapshot? _lastPlaybackDiagnostics;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // 集数列表
  List<Episode> _episodes = [];
  late final PlayerEpisodeSelection _episodeSelection;
  int get _currentEpisodeIndex => _episodeSelection.index;
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

  // Stream订阅管理（防止内存泄漏）
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _episodeSelection = PlayerEpisodeSelection(
      initialIndex: widget.episodeIndex,
    );
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
    );
    _danmakuSession = PlayerDanmakuSession(
      gateway: DanmakuServiceGateway(DanmakuService()),
      controller: DanmakuController(),
      onChanged: (_) {
        if (mounted) setState(() {});
      },
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
        _playbackLifecycle.recordPlaybackPosition(
          generation: _playbackLifecycle.currentGeneration,
          position: pos,
        );
        if (_playbackLifecycle.firstFrameEvidenceReady) {
          _markVideoSignalDetected();
        }
        // 同一条进度流顺带驱动弹幕时间轴，避免重复订阅。
        _danmakuController.updatePosition(pos.inMilliseconds / 1000.0);
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
      if (width > 0 && height > 0) {
        _playbackLifecycle.recordVideoMetadata(
          generation: _playbackLifecycle.currentGeneration,
          width: width,
          height: height,
        );
        _playbackDiagnostics?.videoSignalDetected(
          PlaybackVideoSignal.metadata,
        );
        if (_playbackLifecycle.firstFrameEvidenceReady) {
          _markVideoSignalDetected();
        }
      }
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
    final diagnosticsSession = diagnostics ??
        _playbackHealth.beginOpen(
          _playbackLifecycle.currentGeneration + 1,
        );
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
    final generation = _playbackLifecycle.nextOpenGeneration();
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
      if (!mounted || !_playbackLifecycle.isCurrent(generation)) return;
      _playbackDiagnostics?.openCompleted();
      final resumePosition = request.resumePosition;
      if (resumePosition > const Duration(seconds: 1)) {
        await _seekPlayer(resumePosition);
      }
      if (!_firstFrameRendered) {
        unawaited(_waitForFirstFrame(generation));
      }
    } on TimeoutException {
      _playbackDiagnostics?.fail(PlaybackFailureKind.timeout);
      Log.e(
        'Player',
        safePlaybackLogMessage(
          PlaybackLogOperation.openTimeout,
          PlaybackFailureKind.timeout,
        ),
      );
      _recoverOrShow(
        const _PlaybackIssue(
          icon: Icons.timer_off_outlined,
          title: '连接视频源超时',
          message: '视频服务器响应过慢，薇拉已尝试重新连接。',
        ),
        generation,
      );
    } catch (e) {
      final failureKind = classifyPlaybackFailure(e.toString());
      _playbackDiagnostics?.fail(failureKind);
      Log.e(
        'Player',
        safePlaybackLogMessage(
          PlaybackLogOperation.openFailed,
          failureKind,
        ),
      );
      _recoverOrShow(_issueFromError(e.toString()), generation);
    }
  }

  void _startPlaybackWatchdogs(int generation) {
    _playbackLifecycle.watchOpen(
      generation: generation,
      hasProgressOrVideo: () =>
          _position > const Duration(seconds: 1) || _hasVideoSignal,
      onTimeout: () {
        if (!mounted) return;
        _playbackDiagnostics?.fail(PlaybackFailureKind.timeout);
        _recoverOrShow(
          const _PlaybackIssue(
            icon: Icons.wifi_tethering_error_rounded,
            title: '视频加载时间过长',
            message: '当前线路暂时不可用，可以重新加载或切换其他线路。',
          ),
          generation,
        );
      },
    );

    _playbackLifecycle.watchNoVideo(
      generation: generation,
      shouldReport: () =>
          !_hasVideoSignal &&
          (_hasAudioSignal || _position > const Duration(seconds: 2)),
      onTimeout: () {
        if (!mounted) return;
        _playbackDiagnostics?.fail(PlaybackFailureKind.noVideo);
        _recoverOrShow(
          const _PlaybackIssue(
            icon: Icons.videocam_off_outlined,
            title: '未检测到视频画面',
            message: '音频已经开始播放，但解码器没有返回视频画面。请重新加载或切换线路。',
          ),
          generation,
        );
      },
    );
  }

  Future<void> _waitForFirstFrame(int generation) async {
    try {
      await Future.wait([
        _controller.waitUntilFirstFrameRendered,
        _playbackLifecycle.waitForFirstFrameEvidence(generation),
      ]).timeout(const Duration(seconds: 15));
      if (!mounted || !_playbackLifecycle.isCurrent(generation)) return;
      _markVideoSignalDetected();
    } on TimeoutException {
      if (!mounted ||
          !_playbackLifecycle.isCurrent(generation) ||
          _hasVideoSignal) {
        return;
      }
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
    _playbackLifecycle.markVideoSignalDetected();
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
    _playbackLifecycle.cancelBufferingWatchdog();
    if (!buffering) {
      if (_hasVideoSignal && _isOpeningVideo) {
        setState(() => _isOpeningVideo = false);
      }
      return;
    }

    final generation = _playbackLifecycle.currentGeneration;
    _playbackLifecycle.watchBuffering(
      generation: generation,
      startedAt: _position,
      currentPosition: () => _position,
      isBuffering: () => _isBuffering,
      onTimeout: () {
        if (!mounted) return;
        _playbackDiagnostics?.fail(PlaybackFailureKind.network);
        _recoverOrShow(
          const _PlaybackIssue(
            icon: Icons.signal_wifi_connected_no_internet_4_rounded,
            title: '视频缓冲超时',
            message: '网络或视频服务器没有继续传输数据，可以重新加载当前进度。',
          ),
          generation,
        );
      },
    );
  }

  void _handlePlayerError(String message) {
    if (!mounted || message.trim().isEmpty) return;
    final failureKind = classifyPlaybackFailure(message);
    _playbackDiagnostics?.fail(failureKind);
    Log.e(
      'Player',
      safePlaybackLogMessage(
        PlaybackLogOperation.playerError,
        failureKind,
      ),
    );
    _recoverOrShow(
      _issueFromError(message),
      _playbackLifecycle.currentGeneration,
    );
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

  void _recoverOrShow(_PlaybackIssue issue, int generation) {
    if (!mounted ||
        !_playbackLifecycle.isCurrent(generation) ||
        _playbackIssue != null) {
      return;
    }
    if (_playbackLifecycle.reconnectScheduled) return;
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
      _playbackLifecycle.scheduleReconnect(
        generation: generation,
        action: () {
          if (!mounted) return;
          unawaited(
            _openPlaybackRequest(
              recoveryRequest,
              automaticRetry: true,
              resolveVariants:
                  recoveryRequest.source.id != activeRequest.source.id,
            ),
          );
        },
      );
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

  void _cancelPlaybackWatchdogs() => _playbackLifecycle.cancelWatchdogs();

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
          _episodeSelection.select(widget.episodeIndex);
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
      final failureKind = classifyPlaybackFailure(e.toString());
      Log.d(
        'Player',
        safePlaybackLogMessage(
          PlaybackLogOperation.episodeListFailed,
          failureKind,
        ),
      );
      if (mounted) setState(() => _loadingEpisodes = false);
    }
  }

  void _playEpisode(int index) async {
    if (index < 0 || index >= _episodes.length) return;
    final loadGeneration = ++_episodeLoadGeneration;
    final diagnostics = _playbackHealth.beginOpen(
      _playbackLifecycle.currentGeneration + 1,
    )..sourceResolveStarted();
    setState(() {
      _episodeSelection.select(index);
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
      Log.d(
        'Player',
        safePlaybackLogMessage(
          PlaybackLogOperation.sourceResolveFailed,
          classifyPlaybackFailure(e.toString()),
        ),
      );
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playbackDiagnostics?.suspendBuffering();
    _finishPlaybackDiagnostics();
    _cancelPlaybackWatchdogs();
    _playbackLifecycle.dispose();
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
    _danmakuSession.dispose();

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

  void _updateState(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => _buildPlayerView();
}
