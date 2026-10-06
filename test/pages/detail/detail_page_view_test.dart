import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/detail/detail_page.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/widgets/artwork_components.dart';

/// 与 Pixel 7 真机验收截图相同的数据密度：
/// 非空日期、形态、总集数、两行标题、日文名、两行简介、评分、
/// 评分人数、排名、可用来源状态与五个标签。
const _fullFields = (
  name: '葬送的芙莉莲',
  nameJa: '葬送のフリーレン',
  summary: '魔法使芙莉莲和勇者辛美尔等人一起，历经十年的冒险之后击败了魔王。',
  rating: 8.5,
  ratingCount: 35880,
  rank: 41,
  tags: ['奇幻', '冒险', '治愈', '旅行', '成长'],
  date: '2023-09-29',
  platform: 'TV',
  totalEpisodeCount: 36,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: child,
    ),
  );
}

DetailHeroPanel _panel({
  DetailHeroSourcePresentation? source,
  bool playEnabled = true,
  bool tracked = false,
  bool collected = false,
  VoidCallback? onPlay,
  VoidCallback? onToggleTrack,
  VoidCallback? onToggleCollect,
}) {
  return DetailHeroPanel(
    palette: ArtworkPalette.fallback,
    coverUrl: null,
    heroTag: 'anime-cover-test:frieren',
    name: _fullFields.name,
    nameJa: _fullFields.nameJa,
    summary: _fullFields.summary,
    rating: _fullFields.rating,
    ratingCount: _fullFields.ratingCount,
    rank: _fullFields.rank,
    tags: _fullFields.tags,
    date: _fullFields.date,
    platform: _fullFields.platform,
    totalEpisodeCount: _fullFields.totalEpisodeCount,
    source: source ?? const DetailHeroSourcePresentation.available('视频源: 樱花动漫'),
    playEnabled: playEnabled,
    tracked: tracked,
    collected: collected,
    // 与页面映射层契约一致：playEnabled=false 时 onPlay 必须为 null。
    onPlay: playEnabled ? (onPlay ?? () {}) : onPlay,
    onToggleTrack: onToggleTrack ?? () {},
    onToggleCollect: onToggleCollect ?? () {},
  );
}

Finder get _heroPanel => find.byKey(const ValueKey('detail-ambient-hero'));

void main() {
  testWidgets('Pixel 7 完整详情 Hero 无横向或纵向溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(child: _panel()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_heroPanel, findsOneWidget);
    expect(find.text('葬送的芙莉莲'), findsOneWidget);
    expect(find.text('2023-09-29'), findsOneWidget);
    expect(find.text('TV'), findsOneWidget);
    expect(find.text('36集'), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
    expect(find.text('35880人评分'), findsOneWidget);
    expect(find.text('排名 41'), findsOneWidget);
    for (final tag in _fullFields.tags) {
      expect(find.text(tag), findsOneWidget);
    }
    expect(find.text('视频源: 樱花动漫'), findsOneWidget);
    expect(find.text('立即播放'), findsOneWidget);
    // 追番/收藏是图标按钮的 Tooltip 消息，不是可见文本。
    expect(find.byTooltip('追番'), findsOneWidget);
    expect(find.byTooltip('收藏'), findsOneWidget);

    // 窄屏下海报应位于标题上方，且 panel 不再是固定 410 高。
    final posterCenter = tester.getCenter(find.byType(Hero));
    final titleTop = tester.getTopLeft(find.text('葬送的芙莉莲')).dy;
    final panelRect = tester.getRect(_heroPanel);
    expect(panelRect.height, greaterThan(410));
    final panelCenterX = panelRect.center.dx;
    expect(posterCenter.dx, closeTo(panelCenterX, 1));
    expect(posterCenter.dy, lessThan(titleTop));
  });

  testWidgets('411 宽 unavailable 来源显示警告与手动搜索并可点击', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var manualSearchCalls = 0;
    await tester.pumpWidget(
      _wrap(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: _panel(
              source: DetailHeroSourcePresentation.unavailable(
                onManualSearch: () => manualSearchCalls++,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('暂无视频源'), findsOneWidget);
    expect(find.text('手动搜索'), findsOneWidget);

    await tester.tap(find.text('手动搜索'));
    expect(manualSearchCalls, 1);
  });

  testWidgets('411 宽超长来源标签单行省略且无横向溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const longLabel = '视频源: 一个特别特别特别长的片源名称片源名称片源名称片源名称';
    await tester.pumpWidget(
      _wrap(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: _panel(
              source: const DetailHeroSourcePresentation.available(longLabel),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final textWidget = tester.widget<Text>(
      find.textContaining('一个特别特别特别长的片源名称'),
    );
    expect(textWidget.maxLines, 1);
    expect(textWidget.overflow, TextOverflow.ellipsis);
  });
  testWidgets('1039 宽走 compact 自然高度分支', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1039, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(SingleChildScrollView(child: _panel())),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('detail-hero-compact')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-hero-horizontal')), findsNothing);

    final panelRect = tester.getRect(_heroPanel);
    expect(panelRect.width, 1039);
    expect(panelRect.height, isNot(410));
    expect(panelRect.height, greaterThan(410));

    // 海报仍在标题上方。
    final posterCenter = tester.getCenter(find.byType(Hero));
    final titleTop = tester.getTopLeft(find.text('葬送的芙莉莲')).dy;
    expect(posterCenter.dy, lessThan(titleTop));
  });

  testWidgets('1040 宽走横向固定 410 高分支且海报在左侧', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1040, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(_panel()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
        find.byKey(const ValueKey('detail-hero-horizontal')), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-hero-compact')), findsNothing);

    final panelRect = tester.getRect(_heroPanel);
    expect(panelRect.height, 410);

    final heroRect = tester.getRect(find.byType(Hero));
    expect(heroRect.size, const Size(178, 252));
    final titleLeft = tester.getTopLeft(find.text('葬送的芙莉莲')).dx;
    expect(heroRect.center.dx, lessThan(titleLeft));
  });

  testWidgets('桌面完整数据三操作回调可用且字段完整', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var playCalls = 0;
    var trackCalls = 0;
    var collectCalls = 0;

    await tester.pumpWidget(
      _wrap(
        _panel(
          onPlay: () => playCalls++,
          onToggleTrack: () => trackCalls++,
          onToggleCollect: () => collectCalls++,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('葬送的芙莉莲'), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
    expect(find.text('视频源: 樱花动漫'), findsOneWidget);

    await tester.tap(find.text('立即播放'));
    await tester.tap(find.byTooltip('追番'));
    await tester.tap(find.byTooltip('收藏'));
    expect(playCalls, 1);
    expect(trackCalls, 1);
    expect(collectCalls, 1);
  });
  testWidgets('compact 搜索中状态显示搜索指示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: _panel(
              source: const DetailHeroSourcePresentation.searching(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('搜索视频源中...'), findsOneWidget);
    // 评分徽章的分数环 + 来源搜索指示各一个。
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
  });

  testWidgets('compact 隐藏状态不渲染来源行', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: _panel(source: const DetailHeroSourcePresentation.hidden()),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('视频源'), findsNothing);
  });

  testWidgets('无片源时显示等待片源且播放不可点', (tester) async {
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: _panel(playEnabled: false),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('等待片源'), findsOneWidget);
    expect(find.text('立即播放'), findsNothing);

    // 禁用契约：等待片源按钮的手势回调必须为 null。
    final gestures = tester.widgetList<GestureDetector>(
      find.ancestor(
        of: find.text('等待片源'),
        matching: find.byType(GestureDetector),
      ),
    );
    expect(gestures, isNotEmpty);
    expect(gestures.every((g) => g.onTap == null), isTrue);

    // 点击无副作用且无异常。
    await tester.tap(find.text('等待片源'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('横向分支追番收藏激活态与搜索中来源', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        _panel(
          tracked: true,
          collected: true,
          source: const DetailHeroSourcePresentation.searching(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
        find.byKey(const ValueKey('detail-hero-horizontal')), findsOneWidget);
    expect(find.byTooltip('已追番'), findsOneWidget);
    expect(find.byTooltip('已收藏'), findsOneWidget);
    expect(find.text('搜索视频源中...'), findsOneWidget);
  });

  testWidgets('空日期与零集数字段不渲染对应胶囊', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        DetailHeroPanel(
          palette: ArtworkPalette.fallback,
          coverUrl: null,
          heroTag: 'anime-cover-test:frieren',
          name: '葬送的芙莉莲',
          nameJa: '',
          summary: '',
          rating: null,
          ratingCount: null,
          rank: null,
          tags: const [],
          date: '',
          platform: '',
          totalEpisodeCount: 0,
          source: const DetailHeroSourcePresentation.hidden(),
          playEnabled: false,
          tracked: false,
          collected: false,
          onPlay: null,
          onToggleTrack: () {},
          onToggleCollect: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('排名 41'), findsNothing);
    // 标题仍存在。
    expect(find.text('葬送的芙莉莲'), findsOneWidget);
  });
}
