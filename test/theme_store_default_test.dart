import 'package:flutter_test/flutter_test.dart';
import 'package:weila/stores/theme_store.dart';

void main() {
  test('新设备默认使用天空日记浅色主题', () {
    expect(ThemeStore().isDarkMode, isFalse);
  });

  test('主题加载与 Modular 注入共享同一个实例', () {
    expect(identical(ThemeStore(), ThemeStore()), isTrue);
  });
}
