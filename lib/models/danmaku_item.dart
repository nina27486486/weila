import 'package:hive_ce/hive.dart';

part 'danmaku_item.g.dart';

/// 弹幕类型
/// 0=滚动(左→右), 1=顶部, 2=底部
@HiveType(typeId: 7)
class DanmakuItem extends HiveObject {
  /// 弹幕文本
  @HiveField(0)
  String text;

  /// 出现时间（秒）
  @HiveField(1)
  double time;

  /// 弹幕类型：0=滚动, 1=顶部, 2=底部
  @HiveField(2)
  int type;

  /// 颜色（ARGB int）
  @HiveField(3)
  int color;

  /// 字号（默认16）
  @HiveField(4)
  int fontSize;

  DanmakuItem({
    required this.text,
    required this.time,
    this.type = 0,
    this.color = 0xFFFFFFFF,
    this.fontSize = 16,
  });

  /// 从弹弹play API格式解析。
  /// p="时间,模式,颜色,用户ID"。
  static DanmakuItem? tryParseDandanplay(String p, String text) {
    final parts = p.split(',');
    final normalizedText = text.trim();
    if (parts.length < 4 || normalizedText.isEmpty) return null;
    final time = double.tryParse(parts[0]);
    if (time == null || !time.isFinite || time < 0) return null;
    final mode = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    final parsedColor = int.tryParse(parts[2]);
    final colorValue = parsedColor != null &&
            parsedColor >= 0 &&
            parsedColor <= 0xFFFFFF
        ? parsedColor
        : 0xFFFFFF;

    // 弹弹play模式：1=滚动, 4=底部, 5=顶部
    int type = 0;
    if (mode == 4) type = 2; // 底部
    if (mode == 5) type = 1; // 顶部

    // 弹弹play颜色是十进制RGB，转为ARGB
    final color = 0xFF000000 | colorValue;

    return DanmakuItem(
      text: normalizedText,
      time: time,
      type: type,
      color: color,
      fontSize: 16,
    );
  }

  factory DanmakuItem.fromDandanPlay(String p, String text) {
    return tryParseDandanplay(p, text) ??
        DanmakuItem(text: text.trim(), time: 0);
  }
}
