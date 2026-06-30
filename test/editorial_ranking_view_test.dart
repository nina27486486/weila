import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/discover/editorial_ranking_view.dart';
import 'package:weila/theme/app_theme.dart';

void main() {
  final stories = List.generate(
    7,
    (index) => RankingStory(
      item: <String, dynamic>{
        'name': '排行榜作品 ${index + 1}',
        'cover': null,
        'status': '放送中',
        'url': 'ranking:$index',
      },
      rank: index + 1,
      score: 9.2 - index / 10,
      genres: const ['奇幻', '冒险'],
      delta: index == 0 ? 2 : 0,
    ),
  );

  testWidgets('排行榜使用动漫杂志头图、前三构图与完整榜单', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? source;
    Map<String, dynamic>? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: EditorialRankingView(
            stories: stories,
            source: 'jikan',
            scoreFilter: 'all',
            statusFilter: 'all',
            availableGenres: const ['奇幻', '冒险'],
            onSourceChanged: (value) => source = value,
            onScoreChanged: (_) {},
            onStatusChanged: (_) {},
            onGenreChanged: (_) {},
            onResetFilters: () {},
            onOpenAnime: (item) => opened = item,
            onRefresh: () {},
          ),
        ),
      ),
    );

    expect(find.text('排行中心'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('ranking-editorial-intro')), findsOneWidget);
    expect(find.byKey(const ValueKey('ranking-top-three')), findsOneWidget);
    expect(find.byKey(const ValueKey('ranking-list')), findsOneWidget);
    expect(find.text('本期领跑者'), findsOneWidget);

    await tester.tap(find.text('站内热榜'));
    await tester.tap(find.text('排行榜作品 1'));
    expect(source, 'cms');
    expect(opened, stories.first.item);
  });

  testWidgets('排行榜失败时提供统一恢复状态', (tester) async {
    var refreshed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: EditorialRankingView(
            stories: const [],
            source: 'jikan',
            scoreFilter: 'all',
            statusFilter: 'all',
            errorMessage: '榜单暂时走神了',
            onSourceChanged: (_) {},
            onScoreChanged: (_) {},
            onStatusChanged: (_) {},
            onGenreChanged: (_) {},
            onResetFilters: () {},
            onOpenAnime: (_) {},
            onRefresh: () => refreshed = true,
          ),
        ),
      ),
    );

    expect(find.text('榜单暂时离席'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    expect(refreshed, isTrue);
  });
}
