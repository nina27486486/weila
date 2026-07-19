import '../../models/download_item.dart';
import '../../models/history_item.dart';

class PlaybackEntryFactory {
  const PlaybackEntryFactory._();

  static DownloadItem download({
    required String animeName,
    required String animeUrl,
    required String? coverUrl,
    required String episodeName,
    required String episodeUrl,
    required String sourcePlugin,
    String? m3u8Url,
    String? contentId,
    String? episodeId,
  }) {
    return DownloadItem(
      animeName: animeName,
      animeUrl: animeUrl,
      episodeName: episodeName,
      episodeUrl: episodeUrl,
      sourcePlugin: sourcePlugin,
      m3u8Url: m3u8Url ?? episodeUrl,
      cover: coverUrl,
      contentId: contentId,
      episodeId: episodeId,
    );
  }

  static HistoryItem history({
    required String animeName,
    required String animeUrl,
    required String? coverUrl,
    required String episodeName,
    required String episodeUrl,
    required String sourcePlugin,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
    DateTime? watchedAt,
    String? contentId,
    String? episodeId,
  }) {
    return HistoryItem(
      animeName: animeName,
      animeUrl: animeUrl,
      episodeName: episodeName,
      episodeUrl: episodeUrl,
      sourcePlugin: sourcePlugin,
      cover: coverUrl,
      position: position,
      duration: duration,
      watchedAt: watchedAt,
      contentId: contentId,
      episodeId: episodeId,
    );
  }
}
