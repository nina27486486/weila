import 'package:flutter_test/flutter_test.dart';
import 'package:weila/utils/logger.dart';

void main() {
  test('Log.d 在调试模式安全输出', () {
    // 冒烟：调试分支真实执行且不抛异常。
    Log.d('Detail', '加载完成');
  });

  test('Log.e 输出错误与可选异常信息', () {
    Log.e('Player', '解析失败');
    Log.e('Player', '解析失败', StateError('bad state'));
  });
}
