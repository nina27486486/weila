import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/services/danmaku/danmaku_load_result.dart';
import 'package:weila/services/danmaku/danmaku_matcher.dart';
import 'package:weila/pages/player/widgets/player_danmaku_settings_panel.dart';

void main() {
  testWidgets('shows an explicit configuration state and retry action', (
    tester,
  ) async {
    await tester.pumpWidget(_host(
      result: DanmakuLoadResult(status: DanmakuLoadStatus.notConfigured),
    ));

    expect(find.text('未配置弹幕服务'), findsOneWidget);
    expect(find.text('刷新匹配'), findsOneWidget);
  });

  testWidgets('renders ambiguous candidates as accessible choices', (
    tester,
  ) async {
    final candidate = DanmakuMatchCandidate(
      animeId: 1,
      animeTitle: '葬送的芙莉莲',
      typeDescription: 'TV',
      episodeId: 2,
      episodeTitle: '第1话',
      score: 88,
    );
    DanmakuMatchCandidate? selected;
    await tester.pumpWidget(_host(
      result: DanmakuLoadResult(
        status: DanmakuLoadStatus.ambiguous,
        candidates: [candidate],
      ),
      onCandidateSelected: (value) => selected = value,
    ));

    expect(find.text('请选择匹配剧集'), findsOneWidget);
    expect(find.text('葬送的芙莉莲'), findsOneWidget);
    await tester.tap(find.text('葬送的芙莉莲'));
    expect(selected, same(candidate));
  });
}

Widget _host({
  required DanmakuLoadResult result,
  ValueChanged<DanmakuMatchCandidate>? onCandidateSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PlayerDanmakuSettingsPanel(
        visible: true,
        opacity: 1,
        area: 1,
        speed: 1,
        fontScale: 1,
        loadResult: result,
        onToggleVisible: () {},
        onOpacityChanged: (_) {},
        onAreaChanged: (_) {},
        onSpeedChanged: (_) {},
        onFontScaleChanged: (_) {},
        onRefresh: () {},
        onCandidateSelected: onCandidateSelected ?? (_) {},
      ),
    ),
  );
}
