import 'package:flutter/material.dart';

/// 页面只通过该扩展读取语义颜色，避免深浅主题出现局部硬编码。
@immutable
class ViraColors extends ThemeExtension<ViraColors> {
  final Color bgDark;
  final Color bgCard;
  final Color paper;
  final Color bgSidebar;
  final Color bgSurface;
  final Color bgHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color tagBg;
  final Color divider;
  final Color sky;
  final Color skyLight;
  final Color sakura;
  final Color sakuraLight;
  final Color success;
  final Color warning;
  final Color danger;

  const ViraColors({
    required this.bgDark,
    required this.bgCard,
    required this.paper,
    required this.bgSidebar,
    required this.bgSurface,
    required this.bgHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.tagBg,
    required this.divider,
    required this.sky,
    required this.skyLight,
    required this.sakura,
    required this.sakuraLight,
    required this.success,
    required this.warning,
    required this.danger,
  });

  static const dark = ViraColors(
    bgDark: Color(0xFF0D1624),
    bgCard: Color(0xFF131F31),
    paper: Color(0xFF131F31),
    bgSidebar: Color(0xFF101B2A),
    bgSurface: Color(0xFF19283B),
    bgHover: Color(0xFF20354D),
    textPrimary: Color(0xFFEFF7FD),
    textSecondary: Color(0xFFABC1D2),
    textMuted: Color(0xFF718AA0),
    tagBg: Color(0xFF203F57),
    divider: Color(0xFF2B4156),
    sky: Color(0xFF69BDF2),
    skyLight: Color(0xFF203F57),
    sakura: Color(0xFFF0A8BD),
    sakuraLight: Color(0xFF492F40),
    success: Color(0xFF72BBA3),
    warning: Color(0xFFD7A064),
    danger: Color(0xFFE57B8A),
  );

  static const light = ViraColors(
    bgDark: Color(0xFFF7FBFE),
    bgCard: Color(0xFFFFFEFC),
    paper: Color(0xFFFFFEFC),
    bgSidebar: Color(0xFFFFFEFC),
    bgSurface: Color(0xFFEEF6FB),
    bgHover: Color(0xFFE4F2FB),
    textPrimary: Color(0xFF172235),
    textSecondary: Color(0xFF526476),
    textMuted: Color(0xFF7B8B9A),
    tagBg: Color(0xFFDDF2FF),
    divider: Color(0xFFDCE8EF),
    sky: Color(0xFF3699DB),
    skyLight: Color(0xFFDDF2FF),
    sakura: Color(0xFFEFA7BA),
    sakuraLight: Color(0xFFFBE6EC),
    success: Color(0xFF4D9F84),
    warning: Color(0xFFC98543),
    danger: Color(0xFFD66575),
  );

  @override
  ViraColors copyWith({
    Color? bgDark,
    Color? bgCard,
    Color? paper,
    Color? bgSidebar,
    Color? bgSurface,
    Color? bgHover,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? tagBg,
    Color? divider,
    Color? sky,
    Color? skyLight,
    Color? sakura,
    Color? sakuraLight,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return ViraColors(
      bgDark: bgDark ?? this.bgDark,
      bgCard: bgCard ?? this.bgCard,
      paper: paper ?? this.paper,
      bgSidebar: bgSidebar ?? this.bgSidebar,
      bgSurface: bgSurface ?? this.bgSurface,
      bgHover: bgHover ?? this.bgHover,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      tagBg: tagBg ?? this.tagBg,
      divider: divider ?? this.divider,
      sky: sky ?? this.sky,
      skyLight: skyLight ?? this.skyLight,
      sakura: sakura ?? this.sakura,
      sakuraLight: sakuraLight ?? this.sakuraLight,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  ViraColors lerp(covariant ViraColors? other, double t) {
    if (other == null) return this;
    return ViraColors(
      bgDark: Color.lerp(bgDark, other.bgDark, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      bgSidebar: Color.lerp(bgSidebar, other.bgSidebar, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgHover: Color.lerp(bgHover, other.bgHover, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      tagBg: Color.lerp(tagBg, other.tagBg, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      skyLight: Color.lerp(skyLight, other.skyLight, t)!,
      sakura: Color.lerp(sakura, other.sakura, t)!,
      sakuraLight: Color.lerp(sakuraLight, other.sakuraLight, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension ViraTheme on BuildContext {
  ViraColors get colors => Theme.of(this).extension<ViraColors>()!;
}
