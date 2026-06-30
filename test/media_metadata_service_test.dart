import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/download_item.dart';
import 'package:weila/models/history_item.dart';
import 'package:weila/services/library/media_metadata_service.dart';

void main() {
  test('repairs legacy history title and cover from the anime URL', () async {
    var calls = 0;
    final service = MediaMetadataService.withLoader((anime) async {
      calls++;
      expect(anime.url, 'cms_yinhua:29128');
      return {
        'name': '世界在起舞',
        'cover': 'https://example.com/cover.webp',
      };
    });
    final item = HistoryItem(
      animeName: '第01集',
      animeUrl: 'cms_yinhua:29128',
      episodeName: '第01集',
      episodeUrl: 'https://example.com/ep-1.m3u8',
      sourcePlugin: 'cms_yinhua',
    );

    final changed = await service.hydrateHistoryItem(item);

    expect(changed, isTrue);
    expect(item.animeName, '世界在起舞');
    expect(item.cover, 'https://example.com/cover.webp');
    expect(calls, 1);
  });

  test('repairs legacy download metadata and reuses the anime lookup',
      () async {
    var calls = 0;
    final service = MediaMetadataService.withLoader((anime) async {
      calls++;
      return {
        'name': '世界在起舞',
        'cover': 'https://example.com/cover.webp',
      };
    });
    final first = DownloadItem(
      animeName: '第1集',
      animeUrl: 'cms_yinhua:29128',
      episodeName: '第1集',
      episodeUrl: 'https://example.com/ep-1.m3u8',
      sourcePlugin: 'cms_yinhua',
      m3u8Url: 'https://example.com/ep-1.m3u8',
    );
    final second = DownloadItem(
      animeName: '第2集',
      animeUrl: 'cms_yinhua:29128',
      episodeName: '第2集',
      episodeUrl: 'https://example.com/ep-2.m3u8',
      sourcePlugin: 'cms_yinhua',
      m3u8Url: 'https://example.com/ep-2.m3u8',
    );

    expect(await service.hydrateDownloadItem(first), isTrue);
    expect(await service.hydrateDownloadItem(second), isTrue);

    expect(first.animeName, '世界在起舞');
    expect(second.animeName, '世界在起舞');
    expect(first.cover, 'https://example.com/cover.webp');
    expect(calls, 1);
  });

  test('does not fetch metadata for an already complete record', () async {
    var calls = 0;
    final service = MediaMetadataService.withLoader((anime) async {
      calls++;
      return null;
    });
    final item = HistoryItem(
      animeName: '世界在起舞',
      animeUrl: 'cms_yinhua:29128',
      episodeName: '第01集',
      episodeUrl: 'https://example.com/ep-1.m3u8',
      sourcePlugin: 'cms_yinhua',
      cover: 'https://example.com/cover.webp',
    );

    expect(await service.hydrateHistoryItem(item), isFalse);
    expect(calls, 0);
  });

  test('a failed metadata refresh can be retried later', () async {
    var calls = 0;
    final service = MediaMetadataService.withLoader((anime) async {
      calls++;
      if (calls == 1) return null;
      return {
        'name': '世界在起舞',
        'cover': 'https://example.com/cover.webp',
      };
    });
    final item = HistoryItem(
      animeName: '第01集',
      animeUrl: 'cms_yinhua:29128',
      episodeName: '第01集',
      episodeUrl: 'https://example.com/ep-1.m3u8',
      sourcePlugin: 'cms_yinhua',
    );

    expect(await service.hydrateHistoryItem(item), isFalse);
    expect(await service.hydrateHistoryItem(item), isTrue);
    expect(calls, 2);
  });
}
