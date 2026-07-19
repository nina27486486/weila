import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../models/download_item.dart';
import '../../services/download/download_service.dart';
import '../../stores/theme_store.dart';
import '../../theme/vira_colors.dart';
import '../../utils/error_handler.dart';
import '../../widgets/vira_page_chrome.dart';
import 'offline_library_view.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage>
    with WidgetsBindingObserver {
  final _service = DownloadService();
  List<DownloadItem> _downloads = [];
  Timer? _refreshTimer;
  bool _refreshingMetadata = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDownloads();
    unawaited(_refreshMetadata());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _loadDownloads(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDownloads();
      unawaited(_refreshMetadata());
    }
  }

  Future<void> _refreshMetadata() async {
    if (_refreshingMetadata) return;
    _refreshingMetadata = true;
    try {
      await _service.refreshMetadata();
      _loadDownloads();
    } finally {
      _refreshingMetadata = false;
    }
  }

  void _refreshDownloads() {
    _loadDownloads();
    unawaited(_refreshMetadata());
  }

  void _loadDownloads() {
    if (!mounted) return;
    setState(() => _downloads = _service.getAllDownloads());
  }

  @override
  Widget build(BuildContext context) {
    final episodes = _downloads
        .map(
          (item) => OfflineEpisode(
            id: item.episodeUrl,
            animeName: item.animeName,
            coverUrl: item.cover,
            episodeName: item.episodeName,
            status: _offlineStatus(item.status),
            progress: item.progress,
            fileSizeLabel: _formatFileSize(item.fileSize),
            segmentLabel: item.totalSegments > 0
                ? '${item.downloadedSegments} / ${item.totalSegments} 分段'
                : '',
          ),
        )
        .toList(growable: false);

    return ViraPageScaffold(
      activeDestination: ViraDestination.downloads,
      onDestinationSelected: _openDestination,
      onSearch: () => Modular.to.pushNamed('/search'),
      onThemeToggle: () => Modular.get<ThemeStore>().toggleTheme(),
      onProfile: () => Modular.to.pushNamed('/settings'),
      child: OfflineLibraryView(
        episodes: episodes,
        onPause: (episode) async {
          await _service.pauseDownload(episode.id);
          _loadDownloads();
        },
        onResume: (episode) async {
          await _service.resumeDownload(episode.id);
          _loadDownloads();
        },
        onRetry: (episode) async {
          await _service.retryDownload(episode.id);
          _loadDownloads();
        },
        onPlay: (episode) {
          final item = _findItem(episode.id);
          if (item != null) _playItem(item);
        },
        onRemove: (episode) {
          final item = _findItem(episode.id);
          if (item != null) _confirmRemove(item);
        },
        onRefresh: _refreshDownloads,
      ),
    );
  }

  DownloadItem? _findItem(String episodeUrl) {
    for (final item in _downloads) {
      if (item.episodeUrl == episodeUrl) return item;
    }
    return null;
  }

  OfflineStatus _offlineStatus(int status) => switch (status) {
        0 => OfflineStatus.waiting,
        1 => OfflineStatus.downloading,
        2 => OfflineStatus.completed,
        3 => OfflineStatus.paused,
        _ => OfflineStatus.failed,
      };

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _playItem(DownloadItem item) {
    final localPath = _service.getLocalPath(item.episodeUrl);
    if (localPath == null) {
      ErrorHandler.showError(context, '缓存文件不存在，请重新下载。');
      return;
    }
    Modular.to.pushNamed(
      '/player?url=${Uri.encodeComponent(localPath)}'
      '&title=${Uri.encodeComponent(item.episodeName)}'
      '&animeUrl=${Uri.encodeComponent(item.animeUrl)}'
      '&animeName=${Uri.encodeComponent(item.animeName)}'
      '&cover=${Uri.encodeComponent(item.cover ?? '')}'
      '&source=${Uri.encodeComponent(item.sourcePlugin)}',
    );
  }

  Future<void> _confirmRemove(DownloadItem item) async {
    final completed = item.status == 2;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(completed ? '删除缓存' : '取消下载'),
        content: Text(
          completed
              ? '确定删除「${item.episodeName}」的本地缓存吗？'
              : '确定取消「${item.episodeName}」的下载任务吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('保留'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(completed ? '删除' : '取消任务'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.cancelDownload(item.episodeUrl);
      _loadDownloads();
    }
  }

  void _openDestination(ViraDestination destination) {
    final route = switch (destination) {
      ViraDestination.home => '/',
      ViraDestination.discover => '/category',
      ViraDestination.following => '/track',
      ViraDestination.library => '/collect',
      ViraDestination.downloads => '/download',
    };
    if (destination != ViraDestination.downloads) {
      Modular.to.navigate(route);
    }
  }
}
