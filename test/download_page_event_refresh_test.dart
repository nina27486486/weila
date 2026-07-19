import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/download_item.dart';
import 'package:weila/pages/download/download_page.dart';
import 'package:weila/services/download/download_service.dart';
import 'package:weila/services/library/library_event_bus.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  testWidgets('download page refreshes from download events instead of polling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final events = LibraryEventBus();
    final service = _FakeDownloadLibrary();
    addTearDown(events.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DownloadPage(service: service, events: events),
      ),
    );
    await tester.pump();
    expect(find.text('Vira Offline'), findsNothing);

    service.items = [
      DownloadItem(
        animeName: 'Vira Offline',
        animeUrl: 'anime:offline',
        episodeName: 'Episode 1',
        episodeUrl: 'episode:1',
        sourcePlugin: 'test',
        m3u8Url: 'https://example.com/index.m3u8',
      ),
    ];

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('Vira Offline'), findsNothing);

    events.publish(const LibraryChangedEvent(
      scope: LibraryEventScope.download,
      reason: 'progress',
      key: 'episode:1',
    ));
    await tester.pump();

    expect(find.text('Vira Offline'), findsOneWidget);
  });
}

class _FakeDownloadLibrary implements DownloadLibrary {
  var items = <DownloadItem>[];

  @override
  List<DownloadItem> getAllDownloads() => List.of(items);

  @override
  Future<int> refreshMetadata() async => 0;

  @override
  Future<void> pauseDownload(String episodeUrl) async {}

  @override
  Future<void> resumeDownload(String episodeUrl) async {}

  @override
  Future<void> retryDownload(String episodeUrl) async {}

  @override
  Future<void> cancelDownload(String episodeUrl) async {}

  @override
  String? getLocalPath(String episodeUrl) => null;
}
