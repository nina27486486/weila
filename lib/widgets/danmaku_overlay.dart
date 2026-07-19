import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/danmaku_item.dart';

/// 弹幕控制器 — 管理弹幕状态和渲染
class DanmakuController extends ChangeNotifier {
  List<DanmakuItem> _allDanmaku = [];
  int _nextSpawnIndex = 0; // 下一个待发射的弹幕索引
  final List<_RunningDanmaku> _running = [];
  final List<_StaticDanmaku> _topStatic = [];
  final List<_StaticDanmaku> _bottomStatic = [];

  double _currentTime = 0;
  bool _visible = true;
  double _opacity = 1.0;
  double _fontSize = 1.0; // 缩放因子
  double _speed = 1.0;
  double _area = 1.0; // 显示区域（0.5=上半屏, 1.0=全屏）

  // 碰撞检测用的轨道
  final List<double> _trackOccupiedUntil = [];
  static const double _trackHeight = 28.0;

  bool get visible => _visible;
  double get opacity => _opacity;
  List<DanmakuItem> get allDanmaku => _allDanmaku;
  int get runningCount =>
      _running.length + _topStatic.length + _bottomStatic.length;

  /// 加载弹幕数据
  void loadDanmaku(List<DanmakuItem> items) {
    _allDanmaku = items;
    _allDanmaku.sort((a, b) => a.time.compareTo(b.time));
    _nextSpawnIndex = 0;
    _running.clear();
    _topStatic.clear();
    _bottomStatic.clear();
    _trackOccupiedUntil.clear();
    notifyListeners();
  }

  /// 更新当前播放时间
  void updatePosition(double seconds) {
    // 如果 seek 回退了，重置弹幕索引
    if (seconds < _currentTime - 1) {
      _nextSpawnIndex = 0;
      _running.clear();
      _topStatic.clear();
      _bottomStatic.clear();
    }
    _currentTime = seconds;
  }

  /// 设置弹幕可见性
  void setVisible(bool v) {
    _visible = v;
    notifyListeners();
  }

  /// 设置透明度
  void setOpacity(double v) {
    _opacity = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// 设置字号缩放
  void setFontSizeScale(double v) {
    _fontSize = v.clamp(0.5, 2.0);
    notifyListeners();
  }

  /// 设置速度
  void setSpeed(double v) {
    _speed = v.clamp(0.5, 3.0);
    notifyListeners();
  }

  /// 设置显示区域
  void setArea(double v) {
    _area = v.clamp(0.25, 1.0);
    notifyListeners();
  }

  /// 获取当前时间点应该显示的弹幕
  List<_DanmakuRenderInfo> _getVisibleDanmaku(Size canvasSize, double dt) {
    if (!_visible || _allDanmaku.isEmpty) return [];

    // 触发新弹幕
    _spawnDanmaku(canvasSize);

    // 更新运行中的弹幕位置
    _updateRunning(canvasSize, dt);

    // 清理过期弹幕
    _cleanup(canvasSize);

    // 构建渲染列表
    final result = <_DanmakuRenderInfo>[];

    // 滚动弹幕
    for (final d in _running) {
      result.add(_DanmakuRenderInfo(
        text: d.item.text,
        x: d.x,
        y: d.y,
        color: Color(d.item.color).withValues(alpha: _opacity),
        fontSize: d.item.fontSize * _fontSize,
        type: 0,
      ));
    }

    // 顶部弹幕
    for (final d in _topStatic) {
      result.add(_DanmakuRenderInfo(
        text: d.item.text,
        x: (canvasSize.width -
                d.item.text.length * d.item.fontSize * _fontSize) /
            2,
        y: d.y,
        color: Color(d.item.color).withValues(alpha: _opacity),
        fontSize: d.item.fontSize * _fontSize,
        type: 1,
      ));
    }

    // 底部弹幕
    for (final d in _bottomStatic) {
      result.add(_DanmakuRenderInfo(
        text: d.item.text,
        x: (canvasSize.width -
                d.item.text.length * d.item.fontSize * _fontSize) /
            2,
        y: canvasSize.height - d.y - 30,
        color: Color(d.item.color).withValues(alpha: _opacity),
        fontSize: d.item.fontSize * _fontSize,
        type: 2,
      ));
    }

    return result;
  }

  /// 触发新弹幕（用索引遍历，不销毁原始数据）
  void _spawnDanmaku(Size canvasSize) {
    final maxHeight = canvasSize.height * _area;

    while (_nextSpawnIndex < _allDanmaku.length) {
      final item = _allDanmaku[_nextSpawnIndex];
      if (item.time > _currentTime + 0.1) break; // 还没到时间

      _nextSpawnIndex++;

      switch (item.type) {
        case 1: // 顶部
          _topStatic.add(_StaticDanmaku(
              item: item, y: _findTopSlot(maxHeight), spawnTime: _currentTime));
          break;
        case 2: // 底部
          _bottomStatic.add(_StaticDanmaku(
              item: item,
              y: _findBottomSlot(maxHeight),
              spawnTime: _currentTime));
          break;
        default: // 滚动
          final track = _findTrack(maxHeight);
          final textWidth = item.text.length * item.fontSize * _fontSize;
          _running.add(_RunningDanmaku(
            item: item,
            x: canvasSize.width,
            y: track * _trackHeight,
            track: track,
            textWidth: textWidth,
          ));
      }
    }
  }

  /// 更新滚动弹幕位置
  void _updateRunning(Size canvasSize, double dt) {
    final speed = 120.0 * _speed * (canvasSize.width / 800); // 自适应速度
    for (final d in _running) {
      d.x -= speed * dt;
    }
  }

  /// 清理过期弹幕
  void _cleanup(Size canvasSize) {
    _running.removeWhere((d) => d.x + d.textWidth < -50);
    _topStatic.removeWhere((d) => _currentTime - d.spawnTime > 5);
    _bottomStatic.removeWhere((d) => _currentTime - d.spawnTime > 5);
  }

  /// 查找可用轨道（碰撞检测）
  int _findTrack(double maxHeight) {
    final maxTracks = (maxHeight / _trackHeight).floor();
    for (int i = 0; i < maxTracks; i++) {
      if (i >= _trackOccupiedUntil.length) {
        _trackOccupiedUntil.add(0);
      }
      if (_trackOccupiedUntil[i] <= _currentTime) {
        _trackOccupiedUntil[i] = _currentTime + 3; // 占用3秒
        return i;
      }
    }
    return Random().nextInt(maxTracks.clamp(1, 20));
  }

  double _findTopSlot(double maxHeight) {
    final maxSlots = (maxHeight / _trackHeight).floor();
    return (Random().nextInt(maxSlots.clamp(1, 10))) * _trackHeight;
  }

  double _findBottomSlot(double maxHeight) {
    final maxSlots = (maxHeight / _trackHeight).floor();
    return (Random().nextInt(maxSlots.clamp(1, 10))) * _trackHeight;
  }
}

/// 运行中的滚动弹幕
class _RunningDanmaku {
  final DanmakuItem item;
  double x;
  final double y;
  final int track;
  final double textWidth;

  _RunningDanmaku({
    required this.item,
    required this.x,
    required this.y,
    required this.track,
    required this.textWidth,
  });
}

/// 静态弹幕（顶部/底部）
class _StaticDanmaku {
  final DanmakuItem item;
  final double y;
  final double spawnTime;

  _StaticDanmaku(
      {required this.item, required this.y, required this.spawnTime});
}

/// 弹幕渲染信息
class _DanmakuRenderInfo {
  final String text;
  final double x;
  final double y;
  final Color color;
  final double fontSize;
  final int type; // 0=滚动, 1=顶部, 2=底部

  _DanmakuRenderInfo({
    required this.text,
    required this.x,
    required this.y,
    required this.color,
    required this.fontSize,
    required this.type,
  });
}

/// 弹幕渲染 Widget
class DanmakuOverlay extends StatefulWidget {
  final DanmakuController controller;

  const DanmakuOverlay({super.key, required this.controller});

  @override
  State<DanmakuOverlay> createState() => _DanmakuOverlayState();
}

class _DanmakuOverlayState extends State<DanmakuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  DateTime _lastFrameTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..addListener(_onTick);
    _animController.repeat();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _animController.dispose();
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onTick() {
    final now = DateTime.now();
    _lastFrameTime = now;
    if (mounted) setState(() {});
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _DanmakuPainter(
          controller: widget.controller,
          lastFrameTime: _lastFrameTime,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  final DanmakuController controller;
  final DateTime lastFrameTime;

  _DanmakuPainter({required this.controller, required this.lastFrameTime});

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final dt = now.difference(lastFrameTime).inMilliseconds / 1000.0;
    final clampedDt = dt.clamp(0.001, 0.1); // 防止极端值
    final items = controller._getVisibleDanmaku(size, clampedDt);

    for (final item in items) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: TextStyle(
            color: item.color,
            fontSize: item.fontSize,
            fontWeight: FontWeight.w500,
            shadows: const [
              Shadow(
                  color: Colors.black54, blurRadius: 2, offset: Offset(1, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      painter.paint(canvas, Offset(item.x, item.y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
