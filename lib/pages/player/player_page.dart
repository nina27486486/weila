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
import '../../models/history_item.dart';
import '../../services/plugin/plugin_service.dart';
import '../../services/download/download_service.dart';
import '../../services/danmaku/danmaku_service.dart';
import '../../services/storage/storage_service.dart';
import '../../models/danmaku_item.dart';
import '../../models/download_item.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../stores/history_collect_store.dart';
import '../../utils/error_handler.dart';
import 'widgets/player_danmaku_settings_panel.dart';
import 'widgets/player_control_bar.dart';
import 'widgets/player_diagnostics_overlay.dart';
import 'widgets/episode_sidebar.dart';
import 'widgets/player_next_episode_prompt.dart';
import 'widgets/player_shortcut_panel.dart';

class _PlaybackIssue {
  const _PlaybackIssue({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;
}

class PlayerPage extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String animeUrl;
  final int episodeIndex;
  final String sourcePlugin;

  const PlayerPage({
    super.key,
    required this.videoUrl,
    required this.title,
    this.animeUrl = '',
    this.episodeIndex = 0,
    this.sourcePlugin = '',
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  static bool _danmakuServiceInitialized = false;

  late final Player _player;
  late final VideoController _controller;
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
  String? _currentVideoUrl;
  bool _isOpeningVideo = false;
  bool _isReconnecting = false;
  bool _hasAudioSignal = false;
  bool _hasVideoSignal = false;
  bool _firstFrameRendered = false;
  _PlaybackIssue? _playbackIssue;
  List<String> _videoCandidates = [];
  int _videoCandidateIndex = 0;
  int _openGeneration = 0;
  int _automaticRetryCount = 0;
  Duration _resumePositionAfterOpen = Duration.zero;

  // 集数列表
  List<Episode> _episodes = [];
  int _currentEpisodeIndex = 0;
  bool _loadingEpisodes = false;

  bool get _isEpisodeDrawerVisible =>
      !_isFullscreen &&
      _showEpisodeDrawer &&
      (_episodes.isNotEmpty || _loadingEpisodes);

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
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
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
    _openVideoCandidates([widget.videoUrl]);

    // 加载集数列表
    _loadEpisodes();

    // 启动控制栏自动隐藏
    _startHideTimer();

    // 检查当前视频是否已下载
    _checkDownloadStatus();

    // DanmakuService 是单例，重复进入播放器时不能再次写入其 late final Dio。
    if (!_danmakuServiceInitialized) {
      _danmakuService.init();
      _danmakuServiceInitialized = true;
    }
    final storage = StorageService();
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

  Future<void> _openVideoCandidates(List<String> urls) async {
    final candidates = urls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (candidates.isEmpty) {
      _showPlaybackIssue(
        const _PlaybackIssue(
          icon: Icons.link_off_rounded,
          title: '没有可用的视频地址',
          message: '当前线路没有返回有效地址，请返回详情页更换片源。',
        ),
      );
      return;
    }
    _videoCandidates = candidates;
    _videoCandidateIndex = 0;
    _resumePositionAfterOpen = Duration.zero;
    await _openVideo(candidates.first);
  }

  Future<void> _openVideo(
    String url, {
    bool automaticRetry = false,
  }) async {
    if (url.isEmpty || !mounted) return;
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
      _playbackIssue = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _showControls = true;
    });

    final headers = <String, String>{};
    if (url.contains('.m3u8') ||
        url.contains('/hls/') ||
        url.contains('type=hls')) {
      final uri = Uri.tryParse(url);
      if (uri != null) headers['Referer'] = '${uri.scheme}://${uri.host}/';
    }

    _startPlaybackWatchdogs(generation);
    try {
      await _player
          .open(Media(url, httpHeaders: headers))
          .timeout(const Duration(seconds: 20));
      if (!mounted || generation != _openGeneration) return;
      final resumePosition = _resumePositionAfterOpen;
      _resumePositionAfterOpen = Duration.zero;
      if (resumePosition > const Duration(seconds: 1)) {
        await _player.seek(resumePosition);
      }
      if (!_firstFrameRendered) {
        unawaited(_waitForFirstFrame(generation));
      }
    } on TimeoutException catch (e) {
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
      Log.e('Player', '播放失败: $url', e);
      _recoverOrShow(_issueFromError(e.toString()), generation);
    }
  }

  void _startPlaybackWatchdogs(int generation) {
    _openTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || generation != _openGeneration) return;
      if (_position > const Duration(seconds: 1) || _hasVideoSignal) return;
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
      _firstFrameRendered = true;
      _markVideoSignalDetected();
    } on TimeoutException {
      if (!mounted || generation != _openGeneration || _hasVideoSignal) return;
      if (_hasAudioSignal || _position > const Duration(seconds: 2)) {
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

  void _recoverOrShow(_PlaybackIssue issue, int generation) {
    if (!mounted || generation != _openGeneration || _playbackIssue != null) {
      return;
    }
    if (_reconnectTimer?.isActive ?? false) return;
    final url = _currentVideoUrl;
    if (_automaticRetryCount < 1 && url != null && url.isNotEmpty) {
      _automaticRetryCount++;
      _resumePositionAfterOpen = _position;
      _cancelPlaybackWatchdogs();
      unawaited(_player.stop());
      setState(() {
        _isOpeningVideo = true;
        _isReconnecting = true;
        _isBuffering = true;
      });
      _reconnectTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted || generation != _openGeneration) return;
        _openVideo(url, automaticRetry: true);
      });
      return;
    }
    _showPlaybackIssue(issue);
  }

  void _showPlaybackIssue(_PlaybackIssue issue) {
    if (!mounted) return;
    _cancelPlaybackWatchdogs();
    unawaited(_player.pause());
    setState(() {
      _playbackIssue = issue;
      _isOpeningVideo = false;
      _isReconnecting = false;
      _isBuffering = false;
      _showControls = true;
    });
  }

  void _retryCurrentVideo() {
    final url = _currentVideoUrl;
    if (url == null || url.isEmpty) return;
    _resumePositionAfterOpen = _position;
    _automaticRetryCount = 0;
    _openVideo(url);
  }

  bool get _hasNextVideoSource =>
      _videoCandidateIndex + 1 < _videoCandidates.length;

  void _switchToNextVideoSource() {
    if (!_hasNextVideoSource) return;
    _resumePositionAfterOpen = _position;
    _videoCandidateIndex++;
    _automaticRetryCount = 0;
    _openVideo(_videoCandidates[_videoCandidateIndex]);
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
      final anime = Anime(
        name: widget.title,
        url: widget.animeUrl,
        sourcePlugin:
            widget.sourcePlugin.isNotEmpty ? widget.sourcePlugin : 'bangumi',
      );
      final eps = await _pluginService.getEpisodes(anime);
      if (mounted) {
        setState(() {
          _episodes = eps;
          _currentEpisodeIndex = widget.episodeIndex;
          _loadingEpisodes = false;
        });
      }
    } catch (e) {
      Log.d('Player', '加载集数失败: $e');
      if (mounted) setState(() => _loadingEpisodes = false);
    }
  }

  void _playEpisode(int index) async {
    if (index < 0 || index >= _episodes.length) return;
    setState(() {
      _currentEpisodeIndex = index;
      _isOpeningVideo = true;
      _playbackIssue = null;
      _showControls = true;
    });
    _danmakuController.loadDanmaku(const []);
    final ep = _episodes[index];

    // 尝试获取视频源
    if (widget.sourcePlugin.isNotEmpty) {
      try {
        final plugins = _pluginService.plugins;
        if (plugins.isEmpty) {
          _showPlaybackIssue(
            const _PlaybackIssue(
              icon: Icons.extension_off_outlined,
              title: '没有可用的视频源',
              message: '请先在设置中启用一个视频源插件。',
            ),
          );
          return;
        }
        final plugin = plugins.firstWhere(
          (p) => p.api == widget.sourcePlugin,
          orElse: () => plugins.first,
        );
        final urls = await _pluginService.getVideoUrls(ep.url, plugin);
        if (urls.isNotEmpty && mounted) {
          await _openVideoCandidates(urls);
          if (mounted) _loadDanmaku();
          return;
        }
      } catch (e) {
        Log.d('Player', '获取视频源失败: $e');
      }
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

  Future<void> _loadDanmaku() async {
    if (!_danmakuService.hasCredentials) {
      Log.d('Player', '弹幕未配置API Key，使用测试弹幕');
      _loadTestDanmaku();
      return;
    }
    try {
      final epNum = _currentEpisodeIndex + 1;

      Log.d('Player', '加载弹幕: ${widget.title} 第$epNum集');
      final danmakuList =
          await _danmakuService.fetchDanmaku(widget.title, epNum);

      if (mounted && danmakuList.isNotEmpty) {
        _danmakuController.loadDanmaku(danmakuList);
        Log.d('Player', '弹幕加载完成: ${danmakuList.length} 条');
      }
    } catch (e) {
      Log.e('Player', '弹幕加载失败', e);
    }
  }

  /// 加载测试弹幕（无 API Key 时使用）
  void _loadTestDanmaku() {
    final comments = ['好看', '神作', '泪目', '哈哈', '666', '前方高能', '名场面', '太强了'];
    final testItems = List.generate(50, (i) {
      return DanmakuItem(
        text: '${comments[i % comments.length]} ${i + 1}',
        time: (i * 3.0) + 1.0,
        color: 0xFFFFFFFF,
        fontSize: 16,
      );
    });
    _danmakuController.loadDanmaku(testItems);
    Log.d('Player', '测试弹幕已加载: ${testItems.length} 条');
  }

  void _startDownload() {
    final url = _currentVideoUrl ?? widget.videoUrl;
    if (url.isEmpty) return;

    final epName =
        _episodes.isNotEmpty && _currentEpisodeIndex < _episodes.length
            ? _episodes[_currentEpisodeIndex].name
            : widget.title;

    final item = DownloadItem(
      animeName: widget.title,
      animeUrl: widget.animeUrl,
      episodeName: epName,
      episodeUrl: url,
      sourcePlugin: widget.sourcePlugin,
      m3u8Url: url,
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
    _historyStore.addHistory(HistoryItem(
      animeName: widget.title,
      animeUrl: widget.animeUrl.isNotEmpty ? widget.animeUrl : widget.videoUrl,
      episodeName: epName,
      episodeUrl: _currentVideoUrl ?? widget.videoUrl,
      sourcePlugin: widget.sourcePlugin,
      position: _position,
      duration: _duration,
    ));

    _player.dispose();
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
                    if (_isEpisodeDrawerVisible) _buildEpisodeSidebar(),
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
                  if (_episodes.isNotEmpty || _loadingEpisodes) ...[
                    _PlayerIconButton(
                      icon: Icons.playlist_play_rounded,
                      tooltip: _isEpisodeDrawerVisible ? '关闭选集' : '打开选集',
                      active: _isEpisodeDrawerVisible,
                      onTap: () {
                        setState(
                          () => _showEpisodeDrawer = !_showEpisodeDrawer,
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  _StatusChip(
                    icon: _showDanmaku
                        ? Icons.subtitles_rounded
                        : Icons.subtitles_off_rounded,
                    label: _showDanmaku ? '弹幕开' : '弹幕关',
                    active: _showDanmaku,
                    onTap: () {
                      setState(() => _showDanmaku = !_showDanmaku);
                      _danmakuController.setVisible(_showDanmaku);
                    },
                  ),
                  const SizedBox(width: 8),
                  _PlayerIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: '弹幕设置',
                    active: _showDanmakuPanel,
                    onTap: _toggleDanmakuPanel,
                  ),
                  const SizedBox(width: 8),
                  _PlayerIconButton(
                    icon: _isDownloading
                        ? Icons.downloading_rounded
                        : Icons.download_rounded,
                    tooltip: _isDownloaded ? '已缓存' : '缓存本集',
                    active: _isDownloaded || _isDownloading,
                    onTap: _isDownloaded ? null : _startDownload,
                  ),
                  const SizedBox(width: 8),
                  _PlayerIconButton(
                    icon: Icons.keyboard_command_key_rounded,
                    tooltip: '快捷键',
                    active: _showShortcutPanel,
                    onTap: _toggleShortcutPanel,
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
    );
  }

  Widget _buildBufferingIndicator() {
    final title = _isReconnecting
        ? '正在重新连接'
        : _isOpeningVideo
            ? '正在连接视频源'
            : '正在缓冲视频';
    final subtitle = _isReconnecting
        ? '自动重试 $_automaticRetryCount/1'
        : _isOpeningVideo
            ? '正在等待首帧画面'
            : '正在等待视频数据';
    return PlayerLoadingOverlay(title: title, subtitle: subtitle);
  }

  Widget _buildPlaybackIssuePanel(_PlaybackIssue issue) {
    return PlayerDiagnosticsOverlay(
      issue: PlayerDiagnosticIssue(
        icon: issue.icon,
        title: issue.title,
        message: issue.message,
      ),
      currentSourceIndex: _videoCandidateIndex,
      sourceCount: _videoCandidates.length,
      position: _position,
      onRetry: _retryCurrentVideo,
      onSwitchSource: _hasNextVideoSource ? _switchToNextVideoSource : null,
      onBack: () => Modular.to.pop(),
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
      onToggleVisible: () {
        setState(() => _showDanmaku = !_showDanmaku);
        _danmakuController.setVisible(_showDanmaku);
      },
      onOpacityChanged: _applyDanmakuOpacity,
      onAreaChanged: _applyDanmakuArea,
      onSpeedChanged: _applyDanmakuSpeed,
      onFontScaleChanged: _applyDanmakuFontScale,
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

class _PlayerIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback? onTap;

  const _PlayerIconButton({
    required this.icon,
    required this.tooltip,
    this.active = false,
    this.onTap,
  });

  @override
  State<_PlayerIconButton> createState() => _PlayerIconButtonState();
}

class _PlayerIconButtonState extends State<_PlayerIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.active
                  ? AppTheme.primaryBlue.withValues(alpha: 0.18)
                  : Colors.white
                      .withValues(alpha: _hovering && enabled ? 0.10 : 0.02),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              widget.icon,
              color: enabled
                  ? (widget.active
                      ? AppTheme.primaryBlue
                      : Colors.white.withValues(alpha: 0.82))
                  : Colors.white.withValues(alpha: 0.32),
              size: 19,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<_StatusChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.active
                ? AppTheme.primaryBlue
                    .withValues(alpha: _hovering ? 0.22 : 0.16)
                : Colors.white.withValues(alpha: _hovering ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.active
                  ? AppTheme.primaryBlue.withValues(alpha: 0.32)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.active
                    ? AppTheme.primaryBlue
                    : Colors.white.withValues(alpha: 0.74),
                size: 16,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
