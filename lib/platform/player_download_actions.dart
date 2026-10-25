import '../models/download_item.dart';

class PlayerDownloadActions {
  const PlayerDownloadActions({
    required this.isDownloaded,
    required this.getAllDownloads,
    required this.addDownload,
  });

  final Future<bool> Function(String episodeUrl) isDownloaded;
  final List<DownloadItem> Function() getAllDownloads;
  final Future<void> Function(DownloadItem item) addDownload;
}
