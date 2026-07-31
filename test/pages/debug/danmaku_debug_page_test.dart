import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/debug/danmaku_debug_session.dart';
import 'package:weila/debug/fake_player.dart';
import 'package:weila/models/danmaku_item.dart';
import 'package:weila/pages/debug/danmaku_debug_page.dart';
import 'package:weila/services/danmaku/danmaku_diagnostics.dart';
import 'package:weila/services/danmaku/danmaku_load_result.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';
import 'package:weila/services/diagnostics/acceptance_report_service.dart';
import 'package:weila/widgets/danmaku_overlay.dart';

void main() {
  testWidgets('loads real data into a video-free stage and shows every metric',
      (tester) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map<Object?, Object?>)['text'] as String;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    final ticker = _ManualTicker();
    final session = DanmakuDebugSession(
      source: _LoadedSource(),
      player: FakePlayer(ticker: ticker),
      controller: DanmakuController(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DanmakuDebugPage(
          session: session,
          autoLoad: false,
          reportService: AcceptanceReportService(
            loadAppVersion: () async => '1.0.0+5',
            now: () => DateTime.utc(2026, 7, 23),
            platform: 'windows',
          ),
        ),
      ),
    );

    expect(find.byType(DanmakuOverlay), findsOneWidget);
    expect(find.text('弱弱老师'), findsOneWidget);
    expect(find.text('episodeId'), findsOneWidget);
    expect(find.text('commentCount'), findsOneWidget);
    expect(find.text('parsedCount'), findsOneWidget);
    expect(find.text('queuedCount'), findsOneWidget);
    expect(find.text('currentTime'), findsOneWidget);
    expect(find.text('emittedCount'), findsOneWidget);
    expect(find.text('renderedCount'), findsOneWidget);
    expect(find.text('danmakuEnabled'), findsOneWidget);
    expect(find.text('opacity'), findsOneWidget);
    expect(find.text('area'), findsOneWidget);
    expect(find.text('errorStage'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('danmaku-debug-load')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('24680'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsWidgets);

    final playButton = find.byKey(const ValueKey('danmaku-debug-play'));
    await tester.ensureVisible(playButton);
    await tester.pump();
    await tester.tap(playButton);
    ticker.elapse(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('0.1'), findsOneWidget);

    final copyButton =
        find.byKey(const ValueKey('danmaku-debug-copy'));
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(copiedText, contains('"schemaVersion": 1'));
    expect(copiedText, contains('"episodeId": 24680'));
    expect(copiedText, isNot(contains('first')));
    expect(copiedText, isNot(contains('second')));
  });
}

class _LoadedSource implements DanmakuDebugSource {
  @override
  Future<DanmakuLoadResult> load({
    required String anime,
    required int episode,
    bool refresh = false,
  }) async {
    return DanmakuLoadResult(
      status: DanmakuLoadStatus.loaded,
      selected: const DanmakuMatchCandidate(
        animeId: 12,
        animeTitle: '弱弱老师',
        typeDescription: 'TV',
        episodeId: 24680,
        episodeTitle: '第1话',
        score: 100,
      ),
      items: [
        DanmakuItem(text: 'first', time: 0),
        DanmakuItem(text: 'second', time: 0.1),
      ],
      diagnostics: const DanmakuLoadDiagnostics(
        episodeId: 24680,
        commentCount: 3,
        parsedCount: 2,
      ),
    );
  }

  @override
  Future<DanmakuLoadResult> choose({
    required String anime,
    required int episode,
    required DanmakuMatchCandidate candidate,
  }) {
    return load(anime: anime, episode: episode);
  }
}

class _ManualTicker implements LocalTimelineTicker {
  void Function(Duration delta)? _onTick;

  @override
  void start(void Function(Duration delta) onTick) => _onTick = onTick;

  void elapse(Duration delta) => _onTick?.call(delta);

  @override
  void stop() => _onTick = null;

  @override
  void dispose() => stop();
}
