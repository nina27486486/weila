import '../../../theme/vira_colors.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 视频播放器顶部标题栏
class PlayerTopBar extends StatelessWidget {
  final String title;
  final String episodeName;
  final bool showDanmaku;
  final bool isDownloaded;
  final bool isDownloading;
  final double playbackSpeed;
  final VoidCallback onBack;
  final VoidCallback onToggleDanmaku;
  final VoidCallback? onDownload;
  final ValueChanged<double> onSpeedChange;

  const PlayerTopBar({
    super.key,
    required this.title,
    required this.episodeName,
    required this.showDanmaku,
    required this.isDownloaded,
    required this.isDownloading,
    required this.playbackSpeed,
    required this.onBack,
    required this.onToggleDanmaku,
    this.onDownload,
    required this.onSpeedChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
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
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (episodeName.isNotEmpty)
                    Text(
                      episodeName,
                      style: TextStyle(
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
                showDanmaku ? Icons.subtitles : Icons.subtitles_outlined,
                color: showDanmaku ? AppTheme.primaryBlue : Colors.white70,
                size: 22,
              ),
              tooltip: showDanmaku ? '关闭弹幕' : '开启弹幕',
              onPressed: onToggleDanmaku,
            ),
            SizedBox(width: 4),
            // 下载按钮
            IconButton(
              icon: Icon(
                isDownloading ? Icons.downloading : Icons.download_outlined,
                color: isDownloaded ? AppTheme.scoreGreen : Colors.white70,
                size: 22,
              ),
              tooltip: isDownloaded ? '已缓存' : '缓存本集',
              onPressed: isDownloaded ? null : onDownload,
            ),
            SizedBox(width: 4),
            // 播放速度
            PopupMenuButton<double>(
              icon: Text(
                '${playbackSpeed}x',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              color: context.colors.bgCard,
              onSelected: onSpeedChange,
              itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                  .map((s) => PopupMenuItem(
                        value: s,
                        child: Text(
                          '${s}x',
                          style: TextStyle(
                            color: s == playbackSpeed
                                ? AppTheme.primaryBlue
                                : context.colors.textPrimary,
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
}
