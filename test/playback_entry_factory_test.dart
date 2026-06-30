import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/library/playback_entry_factory.dart';

void main() {
  test('download entry keeps anime title separate from episode title', () {
    final item = PlaybackEntryFactory.download(
      animeName: '世界在起舞',
      animeUrl: 'cms_yinhua:29128',
      coverUrl: 'https://example.com/cover.webp',
      episodeName: '第01集',
      episodeUrl: 'https://example.com/ep-1.m3u8',
      sourcePlugin: 'cms_yinhua',
    );

    expect(item.animeName, '世界在起舞');
    expect(item.episodeName, '第01集');
    expect(item.cover, 'https://example.com/cover.webp');
  });

  test('history entry keeps anime title and cover for the timeline', () {
    final item = PlaybackEntryFactory.history(
      animeName: '世界在起舞',
      animeUrl: 'cms_yinhua:29128',
      coverUrl: 'https://example.com/cover.webp',
      episodeName: '第01集',
      episodeUrl: 'https://example.com/ep-1.m3u8',
      sourcePlugin: 'cms_yinhua',
      position: const Duration(minutes: 3),
      duration: const Duration(minutes: 24),
    );

    expect(item.animeName, '世界在起舞');
    expect(item.episodeName, '第01集');
    expect(item.cover, 'https://example.com/cover.webp');
  });
}
