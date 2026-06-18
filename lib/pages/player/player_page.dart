import '../../utils/logger.dart';
import 'dart:async';
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
import '../../models/download_item.dart';
import '../../widgets/danmaku_overlay.dart';
import '../../stores/history_collect_store.dart';

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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100;
  double _playbackSpeed = 1.0;
  String? _currentVideoUrl;

  // 集数列表
  List<Episode> _episodes = [];
  int _currentEpisodeIndex = 0;
  bool _loadingEpisodes = false;

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
    _player = Player();
    _controller = VideoController(_player);

    // 监听播放状态（存储订阅，dispose时cancel）
    _subscriptions.add(_player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    }));
    _subscriptions.add(_player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    }));
    _subscriptions.add(_player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    }));
    _subscriptions.add(_player.stream.buffering.listen((buf) {
      if (mounted) setState(() => _isBuffering = buf);
    }));
    _subscriptions.add(_player.stream.volume.listen((vol) {
      if (mounted) setState(() => _volume = vol);
    }));

    // 打开视频
    _openVideo(widget.videoUrl);

    // 加载集数列表
    _loadEpisodes();

    // 启动控制栏自动隐藏
    _startHideTimer();

    // 检查当前视频是否已下载
    _checkDownloadStatus();

    // 初始化弹幕服务
    _danmakuService.init();

    // 同步播放位置到弹幕控制器
    _subscriptions.add(_player.stream.position.listen((pos) {
      if (mounted) {
        _danmakuController.updatePosition(pos.inMilliseconds / 1000.0);
      }
    }));

    // 加载弹幕
    _loadDanmaku();
  }

  Future<void> _openVideo(String url) async {
    if (url.isEmpty) return;
    setState(() => _currentVideoUrl = url);
    
    // m3u8 链接可能需要 Referer 头
    final headers = <String, String>{};
    if (url.contains('.m3u8') || url.contains('/hls/') || url.contains('type=hls')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        headers['Referer'] = '${uri.scheme}://${uri.host}/';
      }
    }
    
    try {
      await _player.open(Media(url, httpHeaders: headers));
    } catch (e) {
      Log.e('Player', '播放失败: $url', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('视频播放失败，请检查网络或切换视频源'),
            backgroundColor: Colors.red.shade700,
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: () => _openVideo(url),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadEpisodes() async {
    if (widget.animeUrl.isEmpty) return;
    setState(() => _loadingEpisodes = true);

    try {
      final anime = Anime(
        name: widget.title,
        url: widget.animeUrl,
        sourcePlugin: widget.sourcePlugin.isNotEmpty ? widget.sourcePlugin : 'bangumi',
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
    setState(() => _currentEpisodeIndex = index);
    final ep = _episodes[index];

    // 尝试获取视频源
    if (widget.sourcePlugin.isNotEmpty) {
      try {
        final anime = Anime(
          name: widget.title,
          url: widget.animeUrl,
          sourcePlugin: widget.sourcePlugin,
        );
        final plugins = _pluginService.plugins;
        if (plugins.isEmpty) return;
        final plugin = plugins.firstWhere(
          (p) => p.api == widget.sourcePlugin,
          orElse: () => plugins.first,
        );
        final urls = await _pluginService.getVideoUrls(ep.url, plugin);
        if (urls.isNotEmpty && mounted) {
          _openVideo(urls.first);
          return;
        }
      } catch (e) {
        Log.d('Player', '获取视频源失败: $e');
      }
    }

    // 没有视频源，提示用户
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${ep.name}」暂无可用视频源，请配置视频源插件'),
          backgroundColor: AppTheme.bgCard,
        ),
      );
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isHoveringControls) {
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
    _seekHintTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _seekHint = null);
    });
  }

  void _togglePlay() {
    _player.playOrPause();
    _startHideTimer();
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
        _isDownloading = allDownloads.any((d) => d.episodeUrl == url && d.status == 1);
      });
    }
  }

  Future<void> _loadDanmaku() async {
    if (!_danmakuService.hasCredentials) {
      Log.d('Player', '弹幕未配置API Key，跳过加载');
      return;
    }
    try {
      final epNum = _currentEpisodeIndex + 1;

      Log.d('Player', '加载弹幕: ${widget.title} 第$epNum集');
      final danmakuList = await _danmakuService.fetchDanmaku(widget.title, epNum);

      if (mounted && danmakuList.isNotEmpty) {
        _danmakuController.loadDanmaku(danmakuList);
        Log.d('Player', '弹幕加载完成: ${danmakuList.length} 条');
      }
    } catch (e) {
      Log.e('Player', '弹幕加载失败', e);
    }
  }

  void _startDownload() {
    final url = _currentVideoUrl ?? widget.videoUrl;
    if (url.isEmpty) return;

    final epName = _episodes.isNotEmpty && _currentEpisodeIndex < _episodes.length
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加缓存: $epName'),
        backgroundColor: AppTheme.primaryBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
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
    final epName = _episodes.isNotEmpty && _currentEpisodeIndex < _episodes.length
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
        _seekBy(const Duration(seconds: -5));
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _seekBy(const Duration(seconds: 5));
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
      case LogicalKeyboardKey.escape:
        if (_isFullscreen) {
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
                  // 视频区域
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 视频画面
                        Video(
                          controller: _controller,
                          controls: NoVideoControls, // 使用自定义控制栏
                        ),

                        // 弹幕层
                        if (_showDanmaku)
                          DanmakuOverlay(controller: _danmakuController),

                        // 缓冲指示器
                        if (_isBuffering)
                          const CircularProgressIndicator(
                            color: AppTheme.primaryBlue,
                            strokeWidth: 3,
                          ),

                        // 快进快退提示
                        if (_seekHint != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _seekHint!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 集数列表侧边栏（非全屏时显示）
                  if (!_isFullscreen && _episodes.isNotEmpty)
                    _buildEpisodeSidebar(),
                ],
              ),

              // 控制栏覆盖层
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: MouseRegion(
                    onEnter: (_) => _isHoveringControls = true,
                    onExit: (_) => _isHoveringControls = false,
                    child: _buildControls(),
                  ),
                ),

              // 顶部标题栏
              if (_showControls)
                Positioned(
                  left: 0,
                  right: 0,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Modular.to.pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_episodes.isNotEmpty &&
                      _currentEpisodeIndex < _episodes.length)
                    Text(
                      _episodes[_currentEpisodeIndex].name,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // 弹幕开关
            IconButton(
              icon: Icon(
                _showDanmaku ? Icons.subtitles : Icons.subtitles_outlined,
                color: _showDanmaku ? AppTheme.primaryBlue : Colors.white70,
                size: 22,
              ),
              tooltip: _showDanmaku ? '关闭弹幕' : '开启弹幕',
              onPressed: () {
                setState(() => _showDanmaku = !_showDanmaku);
                _danmakuController.setVisible(_showDanmaku);
              },
            ),
            const SizedBox(width: 4),
            // 下载按钮
            IconButton(
              icon: Icon(
                _isDownloading ? Icons.downloading : Icons.download_outlined,
                color: _isDownloaded ? AppTheme.scoreGreen : Colors.white70,
                size: 22,
              ),
              tooltip: _isDownloaded ? '已缓存' : '缓存本集',
              onPressed: _isDownloaded ? null : _startDownload,
            ),
            const SizedBox(width: 4),
            // 播放速度
            PopupMenuButton<double>(
              icon: Text(
                '${_playbackSpeed}x',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              color: AppTheme.bgCard,
              onSelected: (speed) {
                setState(() => _playbackSpeed = speed);
                _player.setRate(speed);
              },
              itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                  .map((s) => PopupMenuItem(
                        value: s,
                        child: Text(
                          '${s}x',
                          style: TextStyle(
                            color: s == _playbackSpeed
                                ? AppTheme.primaryBlue
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部控制栏
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Row(
              children: [
                Text(
                  _formatDuration(_position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.primaryBlue,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: AppTheme.primaryBlue,
                      overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _duration.inMilliseconds > 0
                          ? _position.inMilliseconds / _duration.inMilliseconds
                          : 0,
                      onChanged: (val) {
                        final pos = Duration(
                          milliseconds: (val * _duration.inMilliseconds).round(),
                        );
                        _player.seek(pos);
                      },
                    ),
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEpisodeSidebar() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(left: BorderSide(color: AppTheme.bgCard)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Text('选集 (\${_episodes.length}集)', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _episodes.length,
              itemBuilder: (context, index) {
                final ep = _episodes[index];
                final isCurrent = index == _currentEpisodeIndex;
                return ListTile(
                  dense: true,
                  title: Text(ep.name, style: TextStyle(color: isCurrent ? AppTheme.primaryBlue : AppTheme.textSecondary, fontSize: 13)),
                  tileColor: isCurrent ? AppTheme.primaryBlue.withValues(alpha: 0.1) : null,
                  onTap: () => _playEpisode(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}