import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:weila/models/collect_item.dart';
import 'package:weila/models/download_item.dart';
import 'package:weila/models/history_item.dart';
import 'package:weila/models/track_item.dart';

void main() {
  late Directory directory;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('weila-library-v1-');
    Hive.init(directory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('new identity fields round-trip while legacy records remain readable',
      () async {
    Hive.registerAdapter<HistoryItem>(_LegacyHistoryAdapter());
    Hive.registerAdapter<CollectItem>(_LegacyCollectAdapter());
    Hive.registerAdapter<TrackItem>(_LegacyTrackAdapter());
    Hive.registerAdapter<DownloadItem>(_LegacyDownloadAdapter());

    final history = await Hive.openBox<HistoryItem>('legacy_history');
    final collects = await Hive.openBox<CollectItem>('legacy_collect');
    final tracks = await Hive.openBox<TrackItem>('legacy_track');
    final downloads = await Hive.openBox<DownloadItem>('legacy_download');
    await history.put(
      'legacy-url',
      HistoryItem(
        animeName: '旧历史',
        animeUrl: 'legacy-url',
        episodeName: '第1集',
        episodeUrl: 'ep-url',
        sourcePlugin: 'cms_test',
      ),
    );
    await collects.put(
      'legacy-url',
      CollectItem(
        animeName: '旧收藏',
        animeUrl: 'legacy-url',
        sourcePlugin: 'cms_test',
      ),
    );
    await tracks.put(
      'legacy-url',
      TrackItem(
        animeName: '旧追番',
        animeUrl: 'legacy-url',
        sourcePlugin: 'cms_test',
      ),
    );
    await downloads.put(
      'ep-url',
      DownloadItem(
        animeName: '旧下载',
        animeUrl: 'legacy-url',
        episodeName: '第1集',
        episodeUrl: 'ep-url',
        sourcePlugin: 'cms_test',
        m3u8Url: 'https://example.test/ep.m3u8',
      ),
    );
    await Future.wait([
      history.close(),
      collects.close(),
      tracks.close(),
      downloads.close(),
    ]);

    Hive.registerAdapter<HistoryItem>(HistoryItemAdapter(), override: true);
    Hive.registerAdapter<CollectItem>(CollectItemAdapter(), override: true);
    Hive.registerAdapter<TrackItem>(TrackItemAdapter(), override: true);
    Hive.registerAdapter<DownloadItem>(DownloadItemAdapter(), override: true);

    final restoredHistory = await Hive.openBox<HistoryItem>('legacy_history');
    final restoredCollect = await Hive.openBox<CollectItem>('legacy_collect');
    final restoredTrack = await Hive.openBox<TrackItem>('legacy_track');
    final restoredDownload =
        await Hive.openBox<DownloadItem>('legacy_download');
    expect(restoredHistory.get('legacy-url')?.contentId, isNull);
    expect(restoredHistory.get('legacy-url')?.episodeId, isNull);
    expect(restoredCollect.get('legacy-url')?.contentId, isNull);
    expect(restoredTrack.get('legacy-url')?.contentId, isNull);
    expect(restoredDownload.get('ep-url')?.contentId, isNull);

    await restoredHistory.put(
      'same-legacy-key',
      HistoryItem(
        animeName: '新历史',
        animeUrl: 'same-legacy-key',
        episodeName: '第2集',
        episodeUrl: 'new-ep-url',
        sourcePlugin: 'cms_test',
        contentId: 'opaque-content',
        episodeId: 'episode:2',
      ),
    );
    final current = restoredHistory.get('same-legacy-key');
    expect(current?.contentId, 'opaque-content');
    expect(current?.episodeId, 'episode:2');
    expect(restoredHistory.keys, contains('same-legacy-key'));
  });
}

class _LegacyHistoryAdapter extends TypeAdapter<HistoryItem> {
  @override
  int get typeId => 3;

  @override
  HistoryItem read(BinaryReader reader) => throw UnsupportedError('write only');

  @override
  void write(BinaryWriter writer, HistoryItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.animeName)
      ..writeByte(1)
      ..write(obj.animeUrl)
      ..writeByte(2)
      ..write(obj.episodeName)
      ..writeByte(3)
      ..write(obj.episodeUrl)
      ..writeByte(4)
      ..write(obj.sourcePlugin)
      ..writeByte(5)
      ..write(obj.cover)
      ..writeByte(6)
      ..write(obj.position)
      ..writeByte(7)
      ..write(obj.duration)
      ..writeByte(8)
      ..write(obj.watchedAt);
  }
}

class _LegacyCollectAdapter extends TypeAdapter<CollectItem> {
  @override
  int get typeId => 4;

  @override
  CollectItem read(BinaryReader reader) => throw UnsupportedError('write only');

  @override
  void write(BinaryWriter writer, CollectItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.animeName)
      ..writeByte(1)
      ..write(obj.animeUrl)
      ..writeByte(2)
      ..write(obj.sourcePlugin)
      ..writeByte(3)
      ..write(obj.cover)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.collectedAt);
  }
}

class _LegacyTrackAdapter extends TypeAdapter<TrackItem> {
  @override
  int get typeId => 5;

  @override
  TrackItem read(BinaryReader reader) => throw UnsupportedError('write only');

  @override
  void write(BinaryWriter writer, TrackItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.animeName)
      ..writeByte(1)
      ..write(obj.animeUrl)
      ..writeByte(2)
      ..write(obj.sourcePlugin)
      ..writeByte(3)
      ..write(obj.cover)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.totalEpisodes)
      ..writeByte(6)
      ..write(obj.watchedEpisodes)
      ..writeByte(7)
      ..write(obj.trackedAt)
      ..writeByte(8)
      ..write(obj.lastUpdated);
  }
}

class _LegacyDownloadAdapter extends TypeAdapter<DownloadItem> {
  @override
  int get typeId => 6;

  @override
  DownloadItem read(BinaryReader reader) =>
      throw UnsupportedError('write only');

  @override
  void write(BinaryWriter writer, DownloadItem obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.animeName)
      ..writeByte(1)
      ..write(obj.animeUrl)
      ..writeByte(2)
      ..write(obj.episodeName)
      ..writeByte(3)
      ..write(obj.episodeUrl)
      ..writeByte(4)
      ..write(obj.sourcePlugin)
      ..writeByte(5)
      ..write(obj.cover)
      ..writeByte(6)
      ..write(obj.localPath)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.progress)
      ..writeByte(9)
      ..write(obj.totalSegments)
      ..writeByte(10)
      ..write(obj.downloadedSegments)
      ..writeByte(11)
      ..write(obj.createdAt)
      ..writeByte(12)
      ..write(obj.fileSize)
      ..writeByte(13)
      ..write(obj.m3u8Url)
      ..writeByte(14)
      ..write(obj.referer)
      ..writeByte(15)
      ..write(obj.failureReason);
  }
}
