import 'package:flutter/material.dart';

import 'vira_colors.dart';

/// 薇拉的视觉基线：编辑感、低饱和、以内容图片作为主要色彩来源。
class AppTheme {
  static const Color primaryBlue = Color(0xFF3699DB);
  static const Color primaryDark = Color(0xFF277FAF);
  static const Color accentBlue = Color(0xFF69BDF2);

  static const Color bgDark = Color(0xFF0D1624);
  static const Color bgCard = Color(0xFF131F31);
  static const Color bgSidebar = Color(0xFF101B2A);
  static const Color bgSurface = Color(0xFF19283B);
  static const Color bgHover = Color(0xFF20354D);

  static const Color textPrimary = Color(0xFFEFF7FD);
  static const Color textSecondary = Color(0xFFABC1D2);
  static const Color textMuted = Color(0xFF718AA0);

  static const Color scoreGreen = Color(0xFF4D9F84);
  static const Color scoreRed = Color(0xFFD66575);
  static const Color scoreOrange = Color(0xFFC98543);

  static const Color tagBg = Color(0xFF203F57);
  static const Color tagHighlight = primaryBlue;
  static const Color divider = Color(0xFF2B4156);

  static const Color airing = scoreGreen;
  static const Color updating = primaryBlue;

  static const double radiusSmall = 6;
  static const double radiusMedium = 8;
  static const double radiusLarge = 12;

  static const String _fontFamily = 'Microsoft YaHei UI';
  static const List<String> _fontFallback = [
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Segoe UI',
  ];
  static const String editorialFontFamily = 'Noto Serif CJK SC';
  static const List<String> editorialFontFallback = [
    'Source Han Serif SC',
    'SimSun',
    'Microsoft YaHei UI',
  ];

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        colors: ViraColors.dark,
        canvas: bgDark,
        card: bgCard,
        surface: bgSurface,
        primaryText: textPrimary,
        secondaryText: textSecondary,
        mutedText: textMuted,
      );

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        colors: ViraColors.light,
        canvas: const Color(0xFFF7FBFE),
        card: const Color(0xFFFFFEFC),
        surface: const Color(0xFFEEF6FB),
        primaryText: const Color(0xFF172235),
        secondaryText: const Color(0xFF526476),
        mutedText: const Color(0xFF7B8B9A),
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required ViraColors colors,
    required Color canvas,
    required Color card,
    required Color surface,
    required Color primaryText,
    required Color secondaryText,
    required Color mutedText,
  }) {
    final dark = brightness == Brightness.dark;
    final border = colors.divider;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFallback,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: canvas,
      colorScheme: dark
          ? const ColorScheme.dark(
              primary: primaryBlue,
              secondary: accentBlue,
              surface: bgSurface,
              onPrimary: Colors.white,
              onSecondary: Color(0xFF07121C),
              onSurface: textPrimary,
              error: scoreRed,
            )
          : const ColorScheme.light(
              primary: primaryBlue,
              secondary: primaryDark,
              surface: Color(0xFFFFFDFC),
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: Color(0xFF172235),
              error: scoreRed,
            ),
      extensions: [colors],
    );

    final textTheme = base.textTheme.copyWith(
      headlineLarge: TextStyle(
          color: primaryText,
          fontFamily: editorialFontFamily,
          fontFamilyFallback: editorialFontFallback,
          fontSize: 36,
          height: 1.28,
          fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(
          color: primaryText,
          fontFamily: editorialFontFamily,
          fontFamilyFallback: editorialFontFallback,
          fontSize: 26,
          height: 1.3,
          fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(
          color: primaryText,
          fontFamily: editorialFontFamily,
          fontFamilyFallback: editorialFontFallback,
          fontSize: 21,
          height: 1.35,
          fontWeight: FontWeight.w600),
      titleLarge: TextStyle(
          color: primaryText,
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w700),
      titleMedium: TextStyle(
          color: primaryText,
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w600),
      titleSmall: TextStyle(
          color: primaryText,
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(
          color: primaryText,
          fontSize: 14,
          height: 1.55,
          fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(
          color: secondaryText,
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w400),
      bodySmall: TextStyle(
          color: mutedText,
          fontSize: 11,
          height: 1.45,
          fontWeight: FontWeight.w400),
      labelLarge: TextStyle(
          color: primaryText, fontSize: 13, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(
          color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
      labelSmall: TextStyle(
          color: mutedText, fontSize: 10, fontWeight: FontWeight.w600),
    );

    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: secondaryText, size: 21),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: secondaryText, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: mutedText),
        labelStyle: textTheme.bodyMedium,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: const BorderSide(color: primaryBlue, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 15, vertical: 9)),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
          mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primaryBlue.withValues(alpha: dark ? 0.18 : 0.12),
        disabledColor: surface,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle:
            textTheme.labelMedium?.copyWith(color: primaryBlue),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        showCheckmark: false,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: border),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF25303B) : const Color(0xFF27313A),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
        waitDuration: const Duration(milliseconds: 450),
      ),
    );
  }
}
