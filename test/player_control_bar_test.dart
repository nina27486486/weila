import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/pages/player/widgets/player_control_bar.dart';
import 'package:weila/theme/app_theme.dart';

Widget _buildControlBar({
  double width = 1200,
  Duration position = const Duration(minutes: 1, seconds: 5),
  Duration duration = const Duration(minutes: 24),
  bool playing = true,
  double volume = 80,
  double playbackSpeed = 1.25,
  bool fullscreen = false,
  bool canPlayNext = true,
  ValueChanged<Duration>? onSeek,
  VoidCallback? onRewind,
  VoidCallback? onTogglePlay,
  VoidCallback? onForward,
  VoidCallback? onPlayNext,
  ValueChanged<double>? onVolumeChanged,
  ValueChanged<double>? onSpeedChanged,
  VoidCallback? onToggleFullscreen,
  VoidCallback? onCopyAcceptanceReport,
  List<PlayerControlMenuOption> sourceOptions = const [],
  List<PlayerControlMenuOption> qualityOptions = const [],
  String? qualityUnavailableMessage,
  ValueChanged<String>? onSourceSelected,
  ValueChanged<String>? onQualitySelected,
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: width,
          child: PlayerControlBar(
            position: position,
            duration: duration,
            playing: playing,
            volume: volume,
            playbackSpeed: playbackSpeed,
            fullscreen: fullscreen,
            canPlayNext: canPlayNext,
            onSeek: onSeek ?? (_) {},
            onRewind: onRewind ?? () {},
            onTogglePlay: onTogglePlay ?? () {},
            onForward: onForward ?? () {},
            onPlayNext: onPlayNext ?? () {},
            onVolumeChanged: onVolumeChanged ?? (_) {},
            onSpeedChanged: onSpeedChanged ?? (_) {},
            onToggleFullscreen: onToggleFullscreen ?? () {},
            onCopyAcceptanceReport: onCopyAcceptanceReport ?? () {},
            sourceOptions: sourceOptions,
            qualityOptions: qualityOptions,
            qualityUnavailableMessage: qualityUnavailableMessage,
            onSourceSelected: onSourceSelected,
            onQualitySelected: onQualitySelected,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('控制条展示播放状态、时间、倍速和下一集入口', (tester) async {
    await tester.pumpWidget(_buildControlBar());

    expect(find.text('01:05'), findsOneWidget);
    expect(find.text('24:00'), findsOneWidget);
    expect(find.text('1.25x'), findsOneWidget);
    expect(find.text('下一集'), findsOneWidget);
    expect(find.byTooltip('暂停'), findsOneWidget);
    expect(find.byTooltip('进入全屏'), findsOneWidget);
    final glow = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('player-progress-glow')),
    );
    final decoration = glow.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('控制条把桌面端操作转换为播放回调', (tester) async {
    var rewinds = 0;
    var toggles = 0;
    var forwards = 0;
    var nextEpisodes = 0;
    var fullscreenToggles = 0;
    var seekPosition = Duration.zero;
    var selectedVolume = 0.0;
    var selectedSpeed = 0.0;

    await tester.pumpWidget(
      _buildControlBar(
        onSeek: (value) => seekPosition = value,
        onRewind: () => rewinds++,
        onTogglePlay: () => toggles++,
        onForward: () => forwards++,
        onPlayNext: () => nextEpisodes++,
        onVolumeChanged: (value) => selectedVolume = value,
        onSpeedChanged: (value) => selectedSpeed = value,
        onToggleFullscreen: () => fullscreenToggles++,
      ),
    );

    await tester.tap(find.byTooltip('后退 5 秒'));
    await tester.tap(find.byTooltip('暂停'));
    await tester.tap(find.byTooltip('前进 5 秒'));
    await tester.tap(find.byTooltip('播放下一集'));
    await tester.tap(find.byTooltip('进入全屏'));

    final progressSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('player-progress-slider')),
    );
    progressSlider.onChanged!(0.5);

    final volumeSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('player-volume-slider')),
    );
    volumeSlider.onChanged!(35);

    await tester.tap(find.byTooltip('倍速'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').last);
    await tester.pumpAndSettle();

    expect(rewinds, 1);
    expect(toggles, 1);
    expect(forwards, 1);
    expect(nextEpisodes, 1);
    expect(fullscreenToggles, 1);
    expect(seekPosition, const Duration(minutes: 12));
    expect(selectedVolume, 35);
    expect(selectedSpeed, 1.5);
  });

  testWidgets('正常播放控制栏常驻安全验收报告入口', (tester) async {
    var copies = 0;

    await tester.pumpWidget(
      _buildControlBar(onCopyAcceptanceReport: () => copies++),
    );

    final action = find.byKey(
      const ValueKey('player-copy-acceptance-report'),
    );
    expect(action, findsOneWidget);
    expect(find.text('验收报告'), findsOneWidget);
    expect(find.byTooltip('复制安全验收报告'), findsOneWidget);

    await tester.tap(action);

    expect(copies, 1);
  });

  testWidgets('控制条安全处理零时长和越界状态', (tester) async {
    await tester.pumpWidget(
      _buildControlBar(
        position: const Duration(hours: 1),
        duration: Duration.zero,
        volume: 130,
        fullscreen: true,
        canPlayNext: false,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('下一集'), findsNothing);
    expect(find.byTooltip('播放下一集'), findsNothing);
    expect(find.byTooltip('退出全屏'), findsOneWidget);

    final progressSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('player-progress-slider')),
    );
    final volumeSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('player-volume-slider')),
    );
    expect(progressSlider.value, 0);
    expect(volumeSlider.value, 100);
  });

  testWidgets('控制条在窄窗口下保持可操作且不溢出', (tester) async {
    await tester.pumpWidget(
      _buildControlBar(
        width: 560,
        playing: false,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('播放'), findsOneWidget);
    expect(find.byTooltip('播放下一集'), findsOneWidget);
    expect(find.text('下一集'), findsNothing);
    expect(find.byKey(const ValueKey('player-volume-slider')), findsOneWidget);
  });

  testWidgets('播放状态图标使用短过渡且不循环脉冲', (tester) async {
    await tester.pumpWidget(_buildControlBar(playing: true));

    expect(
      find.byKey(const ValueKey('player-play-state-icon')),
      findsOneWidget,
    );
    expect(find.byType(AnimatedSwitcher), findsWidgets);

    await tester.pumpWidget(_buildControlBar(playing: false));
    await tester.pump(const Duration(milliseconds: 160));
    expect(find.byTooltip('播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('控制条在 960、1280、1600 宽度下保持稳定', (tester) async {
    for (final width in [960.0, 1280.0, 1600.0]) {
      await tester.pumpWidget(_buildControlBar(width: width));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('player-progress-slider')),
        findsOneWidget,
      );
    }
  });

  testWidgets('控制条在 360 窄屏宽度下无布局溢出', (tester) async {
    await tester.pumpWidget(_buildControlBar(
      width: 360,
      sourceOptions: const [
        PlayerControlMenuOption(
          id: 'auto',
          label: '自动',
          selected: true,
        ),
      ],
      qualityOptions: const [
        PlayerControlMenuOption(
          id: 'auto',
          label: '自动',
          selected: true,
        ),
      ],
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('player-progress-slider')),
      findsOneWidget,
    );
  });

  testWidgets('控制条展示线路和清晰度菜单并转发选择', (tester) async {
    String? selectedSource;
    String? selectedQuality;
    await tester.pumpWidget(
      _buildControlBar(
        sourceOptions: const [
          PlayerControlMenuOption(
            id: 'auto',
            label: '自动',
            selected: false,
          ),
          PlayerControlMenuOption(
            id: 'primary',
            label: '主线',
            selected: true,
          ),
          PlayerControlMenuOption(
            id: 'backup',
            label: '备用',
            selected: false,
            detail: '良好 · 首帧 1.8s',
          ),
        ],
        qualityOptions: const [
          PlayerControlMenuOption(
            id: 'auto',
            label: '自动',
            selected: false,
          ),
          PlayerControlMenuOption(
            id: '1080p',
            label: '1080P',
            selected: true,
          ),
          PlayerControlMenuOption(
            id: '720p',
            label: '720P',
            selected: false,
          ),
        ],
        onSourceSelected: (value) => selectedSource = value,
        onQualitySelected: (value) => selectedQuality = value,
      ),
    );

    expect(find.byTooltip('线路'), findsOneWidget);
    expect(find.byTooltip('清晰度'), findsOneWidget);

    await tester.tap(find.byTooltip('线路'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('良好 · 首帧 1.8s'), findsOneWidget);
    await tester.tap(find.text('备用').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('清晰度'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('720P').last);
    await tester.pumpAndSettle();

    expect(selectedSource, 'backup');
    expect(selectedQuality, '720p');
  });

  testWidgets('单一原始画质显示不可切换说明', (tester) async {
    await tester.pumpWidget(
      _buildControlBar(
        qualityUnavailableMessage: '当前线路未提供可切换清晰度',
      ),
    );

    await tester.tap(find.byTooltip('清晰度'));
    await tester.pumpAndSettle();

    expect(find.text('当前线路未提供可切换清晰度'), findsOneWidget);
    final entries = tester.widgetList<PopupMenuItem<String>>(
      find.byType(PopupMenuItem<String>),
    );
    expect(entries, isNotEmpty);
    expect(entries.every((entry) => !entry.enabled), isTrue);
  });
}
