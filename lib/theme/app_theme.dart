import 'package:flutter/material.dart';

/// 薇拉主题 - 深色主题 + 蓝色主调（参照"次元屋"设计）
class AppTheme {
  // 主色调
  static const Color primaryBlue = Color(0xFF4A90D9);
  static const Color primaryDark = Color(0xFF1A237E);
  static const Color accentBlue = Color(0xFF64B5F6);
  
  // 背景色
  static const Color bgDark = Color(0xFF0D1117);
  static const Color bgCard = Color(0xFF161B22);
  static const Color bgSidebar = Color(0xFF0D1117);
  static const Color bgSurface = Color(0xFF1C2333);
  static const Color bgHover = Color(0xFF21262D);
  
  // 文字色
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);
  
  // 评分色
  static const Color scoreGreen = Color(0xFF3FB950);
  static const Color scoreRed = Color(0xFF58A6FF);
  static const Color scoreOrange = Color(0xFFD29922);
  
  // 标签色
  static const Color tagBg = Color(0xFF30363D);
  static const Color tagHighlight = Color(0xFF1F6FEB);
  
  // 分割线
  static const Color divider = Color(0xFF21262D);
  
  // 追番状态色
  static const Color airing = Color(0xFF3FB950);
  static const Color updating = Color(0xFF58A6FF);
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentBlue,
        surface: bgSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
      ),
      cardTheme: const CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textSecondary),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: bgSidebar,
        selectedIconTheme: IconThemeData(color: primaryBlue),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: primaryBlue,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 12,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textMuted),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: textSecondary),
        labelSmall: TextStyle(color: textMuted),
      ),
      iconTheme: const IconThemeData(color: textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgSurface,
        hintStyle: const TextStyle(color: textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
