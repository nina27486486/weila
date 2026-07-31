import 'package:flutter/material.dart';

import '../../../debug/fake_player.dart';
import '../../../services/danmaku/danmaku_diagnostics.dart';
import '../../../services/danmaku/danmaku_matcher.dart';
import '../../../widgets/danmaku_overlay.dart';

class DanmakuDebugStage extends StatelessWidget {
  const DanmakuDebugStage({
    super.key,
    required this.controller,
    required this.player,
    required this.onSeek,
  });

  final DanmakuController controller;
  final FakePlayer player;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF334155)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                children: [
                  const Positioned(
                    left: 18,
                    top: 16,
                    child: _StageBadge(),
                  ),
                  Positioned.fill(
                    child: DanmakuOverlay(controller: controller),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _TimelineControls(player: player, onSeek: onSeek),
        const SizedBox(height: 14),
        _RenderControls(controller: controller),
      ],
    );
  }
}

class _StageBadge extends StatelessWidget {
  const _StageBadge();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '本地时间轴测试舞台，不会请求视频',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xDD0F172A),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF38BDF8)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.science_outlined, size: 16, color: Color(0xFF7DD3FC)),
              SizedBox(width: 7),
              Text(
                'FakePlayer · 无视频请求',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineControls extends StatelessWidget {
  const _TimelineControls({
    required this.player,
    required this.onSeek,
  });

  final FakePlayer player;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final seconds = player.position.inMilliseconds / 1000.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            IconButton.filled(
              key: const ValueKey('danmaku-debug-play'),
              tooltip: player.playing ? '暂停本地时间轴' : '播放本地时间轴',
              onPressed: player.playing ? player.pause : player.play,
              icon: Icon(player.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
            ),
            IconButton(
              key: const ValueKey('danmaku-debug-reset'),
              tooltip: '重置到 0 秒并暂停',
              onPressed: player.reset,
              icon: const Icon(Icons.restart_alt_rounded),
            ),
            Expanded(
              child: Semantics(
                label: 'FakePlayer 时间轴',
                value: '${seconds.toStringAsFixed(1)} 秒',
                child: Slider(
                  min: 0,
                  max: player.duration.inMilliseconds / 1000.0,
                  value: seconds.clamp(0, 60),
                  onChanged: (value) => onSeek(
                    Duration(milliseconds: (value * 1000).round()),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 82,
              child: Text(
                '${seconds.toStringAsFixed(1)} / 60.0',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RenderControls extends StatelessWidget {
  const _RenderControls({required this.controller});

  final DanmakuController controller;

  @override
  Widget build(BuildContext context) {
    final diagnostics = controller.diagnostics;
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('弹幕启用'),
            Switch(
              key: const ValueKey('danmaku-debug-enabled'),
              value: diagnostics.danmakuEnabled,
              onChanged: controller.setVisible,
            ),
          ],
        ),
        _CompactSlider(
          label: '透明度',
          value: diagnostics.opacity,
          min: 0,
          max: 1,
          onChanged: controller.setOpacity,
        ),
        _CompactSlider(
          label: '显示区域',
          value: diagnostics.area,
          min: 0.25,
          max: 1,
          onChanged: controller.setArea,
        ),
      ],
    );
  }
}

class _CompactSlider extends StatelessWidget {
  const _CompactSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          SizedBox(width: 58, child: Text(label)),
          Expanded(
            child: Slider(
              min: min,
              max: max,
              value: value,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(value.toStringAsFixed(2), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class DanmakuDiagnosticsPanel extends StatelessWidget {
  const DanmakuDiagnosticsPanel({
    super.key,
    required this.snapshot,
    required this.loading,
    required this.safeMessage,
    required this.onCopy,
  });

  final DanmakuDebugSnapshot snapshot;
  final bool loading;
  final String? safeMessage;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, String)>[
      ('episodeId', snapshot.episodeId?.toString() ?? '—'),
      ('commentCount', snapshot.commentCount.toString()),
      ('parsedCount', snapshot.parsedCount.toString()),
      ('queuedCount', snapshot.queuedCount.toString()),
      ('currentTime', snapshot.currentTime.toStringAsFixed(1)),
      ('emittedCount', snapshot.emittedCount.toString()),
      ('renderedCount', snapshot.renderedCount.toString()),
      ('danmakuEnabled', snapshot.danmakuEnabled.toString()),
      ('opacity', snapshot.opacity.toStringAsFixed(2)),
      ('area', snapshot.area.toStringAsFixed(2)),
      ('errorStage', snapshot.errorStage.name),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '完整诊断快照',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  key: const ValueKey('danmaku-debug-copy'),
                  tooltip: '复制安全诊断',
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
              ],
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (safeMessage case final message?) ...[
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(color: Color(0xFFFBBF24))),
            ],
            const SizedBox(height: 12),
            for (final metric in metrics)
              _MetricRow(label: metric.$1, value: metric.$2),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF253247))),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: const TextStyle(color: Color(0xFF94A3B8))),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class DanmakuCandidateList extends StatelessWidget {
  const DanmakuCandidateList({
    super.key,
    required this.candidates,
    required this.onSelected,
  });

  final List<DanmakuMatchCandidate> candidates;
  final ValueChanged<DanmakuMatchCandidate> onSelected;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('匹配到多个剧集，请确认：',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final candidate in candidates)
              ListTile(
                title: Text(candidate.animeTitle),
                subtitle: Text(
                  '${candidate.episodeTitle} · episodeId ${candidate.episodeId}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onSelected(candidate),
              ),
          ],
        ),
      ),
    );
  }
}
