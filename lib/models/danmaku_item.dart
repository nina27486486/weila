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

  /// 从弹弹play API格式解析
  /// p="时间,模式,字号,颜色" 格式
  factory DanmakuItem.fromDandanPlay(String p, String text) {
    final parts = p.split(',');
    final time = double.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final mode = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
    final fontSize = int.tryParse(parts.length > 2 ? parts[2] : '25') ?? 25;
    final colorValue = int.tryParse(parts.length > 3 ? parts[3] : '16777215') ?? 16777215;

    // 弹弹play模式：1=滚动, 4=底部, 5=顶部
    int type = 0;
    if (mode == 4) type = 2; // 底部
    if (mode == 5) type = 1; // 顶部

    // 弹弹play颜色是十进制RGB，转为ARGB
    final color = 0xFF000000 | colorValue;

    return DanmakuItem(
      text: text,
      time: time,
      type: type,
      color: color,
      fontSize: fontSize > 30 ? 16 : fontSize, // 限制最大字号
    );
  }
}
