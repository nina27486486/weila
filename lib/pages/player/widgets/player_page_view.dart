part of '../player_page.dart';

extension _PlayerPageView on _PlayerPageState {
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
    _updateState(() {});
    await _openPlaybackRequest(request);
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: 3), () {
      if (mounted &&
          _isPlaying &&
          !_isHoveringControls &&
          _playbackIssue == null) {
        _updateState(() => _showControls = false);
      }
    });
  }

  void _onMouseMove() {
    if (!_showControls) {
      _updateState(() => _showControls = true);
    }
    _startHideTimer();
  }

  /// 触摸屏没有 hover，控制层只能由单击唤出/收起（MVP 计划 §4）。
  void _handleStageTap() {
    if (_playbackIssue != null) return;
    final show = !_showControls;
    _updateState(() => _showControls = show);
    if (show) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  /// 双击左/右三等分区后退/前进 10 秒，中央双击播放/暂停。
  void _handleStageDoubleTap() {
    switch (_pendingDoubleTapZone) {
      case PlayerDoubleTapZone.back:
        _seekBy(-playerDoubleTapSeekOffset);
      case PlayerDoubleTapZone.forward:
        _seekBy(playerDoubleTapSeekOffset);
      case PlayerDoubleTapZone.center:
        _togglePlay();
    }
  }

  void _seekBy(Duration offset) {
    final newPos = _position + offset;
    if (newPos < Duration.zero) {
      unawaited(_seekPlayer(Duration.zero));
    } else if (newPos > _duration) {
      unawaited(_seekPlayer(_duration));
    } else {
      unawaited(_seekPlayer(newPos));
    }
    _showSeekHint(offset);
  }

  Future<void> _seekPlayer(Duration target) {
    _danmakuController.seekTo(target.inMilliseconds / 1000.0);
    return _player.seek(target);
  }

  void _showSeekHint(Duration offset) {
    final seconds = offset.inSeconds;
    final text = seconds > 0 ? '+${seconds}s' : '${seconds}s';
    _updateState(() => _seekHint = text);
    _seekHintTimer?.cancel();
    _seekHintTimer = Timer(Duration(milliseconds: 800), () {
      if (mounted) _updateState(() => _seekHint = null);
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
    _updateState(() {
      _showDanmakuPanel = !_showDanmakuPanel;
      if (_showDanmakuPanel) _showShortcutPanel = false;
    });
    _startHideTimer();
  }

  void _toggleShortcutPanel() {
    _updateState(() {
      _showShortcutPanel = !_showShortcutPanel;
      if (_showShortcutPanel) _showDanmakuPanel = false;
    });
    _startHideTimer();
  }

  void _playNextEpisode() {
    if (_currentEpisodeIndex + 1 >= _episodes.length) return;
    _updateState(() => _showNextEpisodePrompt = false);
    _playEpisode(_currentEpisodeIndex + 1);
  }

  void _applyDanmakuOpacity(double value) {
    _updateState(() => _danmakuOpacity = value);
    _danmakuController.setOpacity(value);
  }

  void _applyDanmakuArea(double value) {
    _updateState(() => _danmakuArea = value);
    _danmakuController.setArea(value);
  }

  void _applyDanmakuSpeed(double value) {
    _updateState(() => _danmakuSpeed = value);
    _danmakuController.setSpeed(value);
  }

  void _applyDanmakuFontScale(double value) {
    _updateState(() => _danmakuFontScale = value);
    _danmakuController.setFontSizeScale(value);
  }

  Future<void> _toggleFullscreen() async {
    final goingFullscreen = !_isFullscreen;
    _updateState(() => _isFullscreen = goingFullscreen);
    await widget.fullscreenController.setFullscreen(goingFullscreen);
  }

  void _checkDownloadStatus() async {
    final downloadService = _downloadService;
    if (downloadService == null) return;
    final url = _currentVideoUrl ?? widget.videoUrl;
    final downloaded = await downloadService.isDownloaded(url);
    final allDownloads = downloadService.getAllDownloads();
    if (mounted) {
      _updateState(() {
        _isDownloaded = downloaded;
        _isDownloading =
            allDownloads.any((d) => d.episodeUrl == url && d.status == 1);
      });
    }
  }

  Future<void> _loadDanmaku({bool refresh = false}) async {
    await _danmakuSession.load(
      anime: _animeName,
      episode: _episodeSelection.danmakuEpisodeNumber,
      refresh: refresh,
    );
    if (!mounted) return;
    final result = _danmakuSession.result;
    Log.d(
      'Player',
      '弹幕状态: ${result.status.name}, 数量: ${result.items.length}',
    );
  }

  Future<void> _chooseDanmakuCandidate(
    DanmakuMatchCandidate candidate,
  ) async {
    await _danmakuSession.choose(
      anime: _animeName,
      episode: _episodeSelection.danmakuEpisodeNumber,
      candidate: candidate,
    );
  }

  void _startDownload() {
    final downloadService = _downloadService;
    if (downloadService == null) return;
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
    downloadService.addDownload(item);
    _updateState(() => _isDownloading = true);

    ErrorHandler.showInfo(context, '已添加缓存: $epName');
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
        _updateState(() => _showDanmaku = !_showDanmaku);
        _danmakuController.setVisible(_showDanmaku);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.slash:
        _toggleShortcutPanel();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        if (_showShortcutPanel || _showDanmakuPanel) {
          _updateState(() {
            _showShortcutPanel = false;
            _showDanmakuPanel = false;
          });
          return KeyEventResult.handled;
        } else if (_isEpisodeDrawerVisible) {
          _updateState(() => _showEpisodeDrawer = false);
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

  Widget _buildPlayerView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _handleStageTap,
          onDoubleTapDown: (details) {
            _pendingDoubleTapZone = resolveDoubleTapZone(
              localX: details.localPosition.dx,
              width: MediaQuery.sizeOf(context).width,
            );
          },
          onDoubleTap: _handleStageDoubleTap,
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
                    width: playerTopToolbarWidthFor(
                      MediaQuery.sizeOf(context).width,
                    ),
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
                          if (widget.capabilities.downloads)
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
                              _updateState(
                                () => _showEpisodeDrawer = !_showEpisodeDrawer,
                              );
                            case 'danmaku':
                              _updateState(() => _showDanmaku = !_showDanmaku);
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
      onSeek: (target) => unawaited(_seekPlayer(target)),
      onRewind: () => _seekBy(const Duration(seconds: -5)),
      onTogglePlay: _togglePlay,
      onForward: () => _seekBy(const Duration(seconds: 5)),
      onPlayNext: _playNextEpisode,
      onVolumeChanged: (value) {
        _updateState(() => _volume = value);
        _player.setVolume(value);
      },
      onSpeedChanged: (speed) {
        _updateState(() => _playbackSpeed = speed);
        _player.setRate(speed);
      },
      onToggleFullscreen: _toggleFullscreen,
      onCopyAcceptanceReport: () => unawaited(_copyAcceptanceReport()),
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
        _updateState(() {});
        unawaited(_openPlaybackRequest(request));
      },
      onQualitySelected: (variantId) {
        final request = variantId == 'auto'
            ? _playbackSession.selectAutoVariant(_position)
            : _playbackSession.selectVariant(variantId, _position);
        if (request == null) return;
        _updateState(() {});
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
      onCopyReport: () => unawaited(_copyAcceptanceReport()),
      onBack: () => Modular.to.pop(),
    );
  }

  Future<void> _copyAcceptanceReport() async {
    final diagnostics = selectAcceptancePlaybackDiagnostics(
      active: _playbackDiagnostics?.snapshot,
      lastCompleted: _lastPlaybackDiagnostics,
    );
    final resolved = _resolvedPlayback;
    final source = resolved?.source;
    final variant = resolved?.variant;
    final variantUrl = variant?.url ?? _activeOpenRequest?.url ?? '';
    final host = Uri.tryParse(variantUrl)?.host ?? '';
    final health = source == null ? null : _routeHealth(source);
    final danmaku = _acceptanceReports.combineDanmakuDiagnostics(
      load: _danmakuLoadResult.diagnostics,
      controller: _danmakuController.diagnostics,
    );
    final report = await _acceptanceReports.create(
      playback: diagnostics == null
          ? null
          : PlaybackAcceptanceData(
              contentId: widget.contentId,
              episodeIndex: _currentEpisodeIndex,
              providerId: _playbackProviderId,
              sourceKind: source?.kind.name ?? 'unknown',
              sourceId: source?.id ?? 'unknown',
              variantId: variant?.id ?? 'unknown',
              mediaHost: host,
              stage: diagnostics.stage,
              firstFrameRendered: diagnostics.firstFrameRendered,
              sourceResolveDuration: diagnostics.sourceResolveDuration,
              manifestDuration: diagnostics.manifestDuration,
              openDuration: diagnostics.openDuration,
              firstFrameDuration: diagnostics.firstFrameDuration,
              rebufferCount: diagnostics.rebufferCount,
              totalRebufferDuration: diagnostics.totalRebufferDuration,
              longestRebufferDuration: diagnostics.longestRebufferDuration,
              automaticRecoveryCount: _automaticRetryCount,
              playedDuration: _position,
              failureKind: diagnostics.failureKind,
            ),
      danmaku: danmaku,
      routeHealth: health == null
          ? null
          : RouteHealthAcceptanceData(
              samples: health.samples,
              successRate: health.successRate,
              firstFrameMs: health.firstFrameMs,
              rebufferRatio: health.rebufferRatio,
              probeSuccessRate: health.probeSuccessRate,
              score: health.score(DateTime.now()),
              label: health.label,
            ),
    );
    await Clipboard.setData(ClipboardData(text: report.toSafeJson()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('安全验收报告已复制，不含凭证、弹幕正文与媒体 URL'),
      ),
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
    final snapshot = selectAcceptancePlaybackDiagnostics(
      active: _playbackDiagnostics?.snapshot,
      lastCompleted: _lastPlaybackDiagnostics,
    );
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
      onDismiss: () => _updateState(() => _showNextEpisodePrompt = false),
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
        _updateState(() => _showDanmaku = !_showDanmaku);
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
      onClose: () => _updateState(() => _showEpisodeDrawer = false),
      onEpisodeTap: (index) {
        _updateState(() => _showEpisodeDrawer = false);
        _playEpisode(index);
      },
    );
  }
}
