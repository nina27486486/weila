import 'package:flutter_test/flutter_test.dart';
import 'package:weila/models/danmaku_item.dart';

void main() {
  test('parses DandanPlay time mode color and ignores user id', () {
    final item = DanmakuItem.tryParseDandanplay(
      '12.34,1,16711680,42',
      '红色滚动弹幕',
    );

    expect(item, isNotNull);
    expect(item!.time, 12.34);
    expect(item.type, 0);
    expect(item.color, 0xFFFF0000);
    expect(item.fontSize, 16);
  });

  test('maps bottom and top modes', () {
    final bottom = DanmakuItem.tryParseDandanplay('1,4,255,100', '底部');
    final top = DanmakuItem.tryParseDandanplay('2,5,65280,200', '顶部');

    expect(bottom!.type, 2);
    expect(bottom.color, 0xFF0000FF);
    expect(top!.type, 1);
    expect(top.color, 0xFF00FF00);
  });

  test('falls back to white for invalid or out-of-range colors', () {
    final invalid = DanmakuItem.tryParseDandanplay('1,1,bad,9', '无效颜色');
    final negative = DanmakuItem.tryParseDandanplay('1,1,-1,9', '负数颜色');
    final overflow =
        DanmakuItem.tryParseDandanplay('1,1,16777216,9', '越界颜色');

    expect(invalid!.color, 0xFFFFFFFF);
    expect(negative!.color, 0xFFFFFFFF);
    expect(overflow!.color, 0xFFFFFFFF);
  });

  test('rejects blank text invalid time and incomplete parameters', () {
    expect(DanmakuItem.tryParseDandanplay('1,1,255,9', '  '), isNull);
    expect(DanmakuItem.tryParseDandanplay('bad,1,255,9', '坏时间'), isNull);
    expect(DanmakuItem.tryParseDandanplay('1,1', '字段不足'), isNull);
  });
}
