import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import '../../theme/app_theme.dart';
import '../../services/download/download_service.dart';
import '../../models/download_item.dart';
import '../../utils/helpers.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  final _service = DownloadService();
  List<DownloadItem> _downloads = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
    // 每秒刷新一次以更新进度
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _loadDownloads();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadDownloads() {
    final list = _service.getAllDownloads();
    if (mounted) {
      setState(() => _downloads = list);
    }
  }

  /// 按 animeName 分组，保持原始顺序
  Map<String, List<DownloadItem>> _groupByAnime() {
    final map = <String, List<DownloadItem>>{};
    for (final item in _downloads) {
      map.putIfAbsent(item.animeName, () => []).add(item);
    }
    return map;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // ============================================================
  // 状态图标
  // ============================================================

  Widget _statusIcon(DownloadItem item) {
    switch (item.status) {
      case 0: // 等待中
        return const Text('⏳', style: TextStyle(fontSize: 18));
      case 1: // 下载中
        return SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: item.progress,
                strokeWidth: 2.5,
                backgroundColor: AppTheme.tagBg,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
              ),
              Text(
                '${(item.progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 8,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case 2: // 已完成
        return const Text('✅', style: TextStyle(fontSize: 18));
      case 3: // 已暂停
        return const Text('⏸', style: TextStyle(fontSize: 18));
      case 4: // 失败
        return const Text('❌', style: TextStyle(fontSize: 18));
      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // 状态文字
  // ============================================================

  String _statusText(DownloadItem item) {
    switch (item.status) {
      case 0:
        return '等待中';
      case 1:
        return '下载中 ${(item.progress * 100).toInt()}%';
      case 2:
        return '已完成';
      case 3:
        return '已暂停';
      case 4:
        return '下载失败';
      default:
        return '';
    }
  }

  // ============================================================
  // 操作按钮
  // ============================================================

  List<Widget> _actionButtons(DownloadItem item) {
    final buttons = <Widget>[];

    switch (item.status) {
      case 0: // 等待中 → 暂停、取消
        buttons.add(_iconBtn(
          icon: Icons.pause,
          tooltip: '暂停',
          color: AppTheme.scoreOrange,
          onTap: () async {
            await _service.pauseDownload(item.episodeUrl);
            _loadDownloads();
          },
        ));
        buttons.add(_iconBtn(
          icon: Icons.close,
          tooltip: '取消',
          color: Colors.redAccent,
          onTap: () => _confirmCancel(item),
        ));
        break;

      case 1: // 下载中 → 暂停、取消
        buttons.add(_iconBtn(
          icon: Icons.pause,
          tooltip: '暂停',
          color: AppTheme.scoreOrange,
          onTap: () async {
            await _service.pauseDownload(item.episodeUrl);
            _loadDownloads();
          },
        ));
        buttons.add(_iconBtn(
          icon: Icons.close,
          tooltip: '取消',
          color: Colors.redAccent,
          onTap: () => _confirmCancel(item),
        ));
        break;

      case 2: // 已完成 → 播放
        buttons.add(_iconBtn(
          icon: Icons.play_arrow,
          tooltip: '播放',
          color: AppTheme.primaryBlue,
          onTap: () => _playItem(item),
        ));
        buttons.add(_iconBtn(
          icon: Icons.close,
          tooltip: '删除',
          color: Colors.redAccent,
          onTap: () => _confirmCancel(item),
        ));
        break;

      case 3: // 已暂停 → 恢复、取消
        buttons.add(_iconBtn(
          icon: Icons.play_arrow,
          tooltip: '恢复',
          color: AppTheme.scoreGreen,
          onTap: () async {
            await _service.resumeDownload(item.episodeUrl);
            _loadDownloads();
          },
        ));
        buttons.add(_iconBtn(
          icon: Icons.close,
          tooltip: '取消',
          color: Colors.redAccent,
          onTap: () => _confirmCancel(item),
        ));
        break;

      case 4: // 失败 → 重试、取消
        buttons.add(_iconBtn(
          icon: Icons.refresh,
          tooltip: '重试',
          color: AppTheme.accentBlue,
          onTap: () async {
            await _service.retryDownload(item.episodeUrl);
            _loadDownloads();
          },
        ));
        buttons.add(_iconBtn(
          icon: Icons.close,
          tooltip: '删除',
          color: Colors.redAccent,
          onTap: () => _confirmCancel(item),
        ));
        break;
    }

    return buttons;
  }

  Widget _iconBtn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ============================================================
  // 播放
  // ============================================================

  void _playItem(DownloadItem item) {
    final localPath = _service.getLocalPath(item.episodeUrl);
    if (localPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件不存在', style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: AppTheme.bgCard,
        ),
      );
      return;
    }
    Modular.to.pushNamed(
      '/player?url=${Uri.encodeComponent(localPath)}'
      '&title=${Uri.encodeComponent(item.episodeName)}'
      '&animeUrl=${Uri.encodeComponent(item.animeUrl)}'
      '&source=${Uri.encodeComponent(item.sourcePlugin)}',
    );
  }

  // ============================================================
  // 确认取消/删除
  // ============================================================

  void _confirmCancel(DownloadItem item) {
    final isCompleted = item.status == 2;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text(
          isCompleted ? '删除下载' : '取消下载',
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          isCompleted
              ? '确定要删除「${item.episodeName}」的缓存文件吗？'
              : '确定要取消下载「${item.episodeName}」吗？',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.cancelDownload(item.episodeUrl);
              _loadDownloads();
            },
            child: const Text('确定', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByAnime();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Modular.to.navigate('/'),
        ),
        title: const Text('离线缓存', style: TextStyle(color: AppTheme.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            tooltip: '刷新',
            onPressed: _loadDownloads,
          ),
        ],
      ),
      body: _downloads.isEmpty ? _buildEmpty() : _buildList(grouped),
    );
  }

  // ============================================================
  // 空状态
  // ============================================================

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_outlined, size: 64, color: AppTheme.textMuted),
          SizedBox(height: 16),
          Text('暂无下载', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
          SizedBox(height: 4),
          Text('在播放页面可以缓存视频', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  // ============================================================
  // 下载列表（按番剧分组）
  // ============================================================

  Widget _buildList(Map<String, List<DownloadItem>> grouped) {
    final animeNames = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: animeNames.length,
      itemBuilder: (context, index) {
        final animeName = animeNames[index];
        final items = grouped[animeName]!;

        return _AnimeGroup(
          animeName: animeName,
          items: items,
          statusIcon: _statusIcon,
          statusText: _statusText,
          actionButtons: _actionButtons,
          formatFileSize: _formatFileSize,
        );
      },
    );
  }
}

// ============================================================
// 番剧分组组件
// ============================================================

class _AnimeGroup extends StatelessWidget {
  final String animeName;
  final List<DownloadItem> items;
  final Widget Function(DownloadItem) statusIcon;
  final String Function(DownloadItem) statusText;
  final List<Widget> Function(DownloadItem) actionButtons;
  final String Function(int) formatFileSize;

  const _AnimeGroup({
    required this.animeName,
    required this.items,
    required this.statusIcon,
    required this.statusText,
    required this.actionButtons,
    required this.formatFileSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 番剧名称标题
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Text(
                animeName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(color: AppTheme.divider, height: 1, thickness: 0.5),
            // 各集列表
            ...items.map((item) => _DownloadItemRow(
                  item: item,
                  statusIcon: statusIcon,
                  statusText: statusText,
                  actionButtons: actionButtons,
                  formatFileSize: formatFileSize,
                )),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 单条下载项
// ============================================================

class _DownloadItemRow extends StatefulWidget {
  final DownloadItem item;
  final Widget Function(DownloadItem) statusIcon;
  final String Function(DownloadItem) statusText;
  final List<Widget> Function(DownloadItem) actionButtons;
  final String Function(int) formatFileSize;

  const _DownloadItemRow({
    required this.item,
    required this.statusIcon,
    required this.statusText,
    required this.actionButtons,
    required this.formatFileSize,
  });

  @override
  State<_DownloadItemRow> createState() => _DownloadItemRowState();
}

class _DownloadItemRowState extends State<_DownloadItemRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: _hovering ? AppTheme.bgHover : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // 状态图标
            widget.statusIcon(item),
            const SizedBox(width: 10),

            // 集名 + 进度条 + 状态文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 集名
                  Text(
                    item.episodeName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // 进度条（下载中 / 已暂停 / 等待中时显示）
                  if (item.status == 1 || item.status == 3 || item.status == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: item.status == 0 ? null : item.progress,
                          backgroundColor: AppTheme.tagBg,
                          valueColor: AlwaysStoppedAnimation(
                            item.status == 3
                                ? AppTheme.scoreOrange
                                : AppTheme.primaryBlue,
                          ),
                          minHeight: 3,
                        ),
                      ),
                    ),

                  // 底部信息行：状态 + 文件大小
                  Row(
                    children: [
                      Text(
                        widget.statusText(item),
                        style: TextStyle(
                          color: item.status == 4
                              ? Colors.redAccent
                              : AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      if (item.fileSize > 0) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                        Text(
                          widget.formatFileSize(item.fileSize),
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (item.status == 1 && item.totalSegments > 0) ...[
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                        Text(
                          '${item.downloadedSegments}/${item.totalSegments}',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // 操作按钮
            ...widget.actionButtons(item),
          ],
        ),
      ),
    );
  }
}
