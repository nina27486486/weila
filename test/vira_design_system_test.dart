import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weila/theme/app_theme.dart';
import 'package:weila/theme/vira_colors.dart';

void main() {
  test('明亮天空主题暴露完整的编辑式语义色', () {
    const colors = ViraColors.light;

    expect(colors.bgDark, const Color(0xFFF7FBFE));
    expect(colors.paper, const Color(0xFFFFFEFC));
    expect(colors.bgSurface, const Color(0xFFEEF6FB));
    expect(colors.textPrimary, const Color(0xFF172235));
    expect(colors.sky, const Color(0xFF3699DB));
    expect(colors.skyLight, const Color(0xFFDDF2FF));
    expect(colors.sakura, const Color(0xFFEFA7BA));
    expect(colors.sakuraLight, const Color(0xFFFBE6EC));
    expect(colors.divider, const Color(0xFFDCE8EF));
    expect(colors.success, const Color(0xFF4D9F84));
    expect(colors.warning, const Color(0xFFC98543));
    expect(colors.danger, const Color(0xFFD66575));
  });

  test('夜空特刊主题保持蓝色层次而不是纯黑后台', () {
    const colors = ViraColors.dark;

    expect(colors.bgDark, const Color(0xFF0D1624));
    expect(colors.paper, const Color(0xFF131F31));
    expect(colors.bgSurface, const Color(0xFF19283B));
    expect(colors.textPrimary, const Color(0xFFEFF7FD));
    expect(colors.sky, const Color(0xFF69BDF2));
    expect(colors.sakura, const Color(0xFFF0A8BD));
    expect(colors.divider, const Color(0xFF2B4156));
  });

  test('主题提供编辑标题字体与统一色彩扩展', () {
    final theme = AppTheme.lightTheme;

    expect(theme.extension<ViraColors>(), ViraColors.light);
    expect(AppTheme.editorialFontFamily, isNotEmpty);
    expect(AppTheme.primaryBlue, ViraColors.light.sky);
  });
}
