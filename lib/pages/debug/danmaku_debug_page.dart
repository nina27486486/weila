import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../debug/danmaku_debug_session.dart';
import '../../debug/fake_player.dart';
import '../../services/danmaku/danmaku_service.dart';
import '../../widgets/danmaku_overlay.dart';
import 'widgets/danmaku_debug_components.dart';

class DanmakuDebugPage extends StatefulWidget {
  const DanmakuDebugPage({
    super.key,
    this.session,
    this.autoLoad = true,
  });

  final DanmakuDebugSession? session;
  final bool autoLoad;

  @override
  State<DanmakuDebugPage> createState() => _DanmakuDebugPageState();
}

class _DanmakuDebugPageState extends State<DanmakuDebugPage> {
  final _formKey = GlobalKey<FormState>();
  final _animeController = TextEditingController(text: '弱弱老师');
  final _episodeController = TextEditingController(text: '1');
  late final DanmakuDebugSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session ??
        DanmakuDebugSession(
          source: DanmakuServiceDebugSource(DanmakuService()),
          player: FakePlayer(),
          controller: DanmakuController(),
        );
    _session.addListener(_handleSessionChange);
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _session.removeListener(_handleSessionChange);
    _session.dispose();
    _animeController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

  void _handleSessionChange() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool refresh = false}) async {
    if (!_formKey.currentState!.validate()) return;
    await _session.load(
      anime: _animeController.text,
      episode: int.parse(_episodeController.text),
      refresh: refresh,
    );
  }

  Future<void> _copyDiagnostics() async {
    await Clipboard.setData(
        ClipboardData(text: _session.snapshot.toSafeText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('安全诊断已复制，不含凭证与弹幕正文')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: const Color(0xFFF8FAFC),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Danmaku Debug Mode'),
            Text(
              '真实弹弹play数据 × 固定本地时间轴',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;
            return SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 28 : 18),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildQueryForm(),
                      DanmakuCandidateList(
                        candidates: _session.candidates,
                        onSelected: (candidate) =>
                            unawaited(_session.choose(candidate)),
                      ),
                      const SizedBox(height: 20),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildStage()),
                            const SizedBox(width: 20),
                            SizedBox(width: 390, child: _buildDiagnostics()),
                          ],
                        )
                      else ...[
                        _buildStage(),
                        const SizedBox(height: 20),
                        _buildDiagnostics(),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQueryForm() {
    return Form(
      key: _formKey,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextFormField(
                  controller: _animeController,
                  decoration: const InputDecoration(
                    labelText: '动画名称',
                    prefixIcon: Icon(Icons.movie_filter_outlined),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请输入动画名称' : null,
                ),
              ),
              SizedBox(
                width: 150,
                child: TextFormField(
                  controller: _episodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '集数',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                  validator: (value) {
                    final episode = int.tryParse(value ?? '');
                    return episode == null || episode < 1 ? '集数需大于 0' : null;
                  },
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('danmaku-debug-load'),
                onPressed: _session.loading ? null : () => unawaited(_load()),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('加载真实弹幕'),
              ),
              OutlinedButton.icon(
                onPressed: _session.loading
                    ? null
                    : () => unawaited(_load(refresh: true)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('强制刷新'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage() => DanmakuDebugStage(
        controller: _session.controller,
        player: _session.player,
      );

  Widget _buildDiagnostics() => DanmakuDiagnosticsPanel(
        snapshot: _session.snapshot,
        loading: _session.loading,
        safeMessage: _session.safeMessage,
        onCopy: () => unawaited(_copyDiagnostics()),
      );
}
