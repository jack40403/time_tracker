import 'package:flutter/material.dart';

class AppTheme {
  final String id;
  final String displayName;

  // Background
  final Color bgColor1;
  final Color bgColor2;
  final Color bgColor3;
  final bool bgIsGradient;
  final AlignmentGeometry bgBegin;
  final AlignmentGeometry bgEnd;

  // Surface
  final Color surface;
  final Color surfaceAlt;

  // Text
  final Color ink;
  final Color mute;

  // Accent / action
  final Color accent;
  final Color accentSoft;
  final Color action;
  final Color actionInk;
  final Color active;

  // Chip
  final Color chipInk;
  final Color chipInkSel;
  final Color chipBg;

  // Border / shadow
  final Color border;
  final double borderW;
  final Color shadowColor;
  final Offset shadowOffset;

  // Shape
  final double cardRadius;
  final double chipRadius;

  // Fonts (GoogleFonts names)
  final String fontDisplay;
  final String fontBody;
  final String fontTimer;

  // Nav
  final Color navBg;
  final Color navInk;
  final Color navBorder;
  final Color appBarInk;

  // Timer labels
  final String timerLabel;
  final String runningLabel;
  final bool timerHaloOn;

  // Background decoration style
  final String bubbleStyle; // 'cartoon' | 'cartoon-dark' | 'pixel' | 'pastel' | 'none'

  const AppTheme({
    required this.id,
    required this.displayName,
    required this.bgColor1,
    this.bgColor2 = const Color(0xFF000000),
    this.bgColor3 = const Color(0xFF000000),
    this.bgIsGradient = false,
    this.bgBegin = Alignment.topLeft,
    this.bgEnd = Alignment.bottomRight,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.mute,
    required this.accent,
    required this.accentSoft,
    required this.action,
    required this.actionInk,
    required this.active,
    required this.chipInk,
    required this.chipInkSel,
    required this.chipBg,
    required this.border,
    this.borderW = 0,
    required this.shadowColor,
    this.shadowOffset = Offset.zero,
    required this.cardRadius,
    required this.chipRadius,
    required this.fontDisplay,
    required this.fontBody,
    required this.fontTimer,
    required this.navBg,
    required this.navInk,
    required this.navBorder,
    required this.appBarInk,
    required this.timerLabel,
    required this.runningLabel,
    this.timerHaloOn = false,
    required this.bubbleStyle,
  });

  Decoration get backgroundDecoration {
    if (bgIsGradient) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: bgBegin,
          end: bgEnd,
          colors: bgColor3 != const Color(0xFF000000) && bgColor3 != bgColor1
              ? [bgColor1, bgColor2, bgColor3]
              : [bgColor1, bgColor2],
        ),
      );
    }
    return BoxDecoration(color: bgColor1);
  }
}

// ─── Helper decorators ──────────────────────────────────────────────────────

BoxDecoration cardDecoration(AppTheme t, {Color? color}) {
  return BoxDecoration(
    color: color ?? t.surface,
    borderRadius: BorderRadius.circular(t.cardRadius),
    border: t.borderW > 0
        ? Border.all(color: t.border, width: t.borderW)
        : null,
    boxShadow: t.shadowOffset != Offset.zero
        ? [
            BoxShadow(
              color: t.shadowColor,
              offset: t.shadowOffset,
              blurRadius: 0,
            )
          ]
        : (t.id == 'pastel'
            ? [BoxShadow(color: t.shadowColor, offset: const Offset(0, 12), blurRadius: 24)]
            : null),
  );
}

BoxDecoration buttonDecoration(AppTheme t) {
  final isCircle = t.cardRadius >= 28;
  return BoxDecoration(
    color: t.action,
    shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
    borderRadius: isCircle ? null : BorderRadius.circular(t.chipRadius),
    border: t.borderW > 0 ? Border.all(color: t.border, width: t.borderW) : null,
    boxShadow: t.shadowOffset != Offset.zero
        ? [BoxShadow(color: t.shadowColor, offset: t.shadowOffset, blurRadius: 0)]
        : null,
  );
}

BoxDecoration chipDecoration(AppTheme t, {required bool selected}) {
  return BoxDecoration(
    color: selected ? t.active : t.chipBg,
    borderRadius: BorderRadius.circular(t.chipRadius),
    border: t.borderW > 0 ? Border.all(color: t.border, width: t.borderW) : null,
    boxShadow: selected && t.shadowOffset != Offset.zero
        ? [BoxShadow(color: t.shadowColor, offset: const Offset(3, 3), blurRadius: 0)]
        : null,
  );
}

// ─── Theme definitions ───────────────────────────────────────────────────────

const AppTheme cartoonTheme = AppTheme(
  id: 'cartoon',
  displayName: '卡通原版',
  bgColor1: Color(0xFF48CAE4),
  bgColor2: Color(0xFF0077B6),
  bgIsGradient: true,
  bgBegin: Alignment.topLeft,
  bgEnd: Alignment.bottomRight,
  surface: Color(0xFFFFFDE7),
  surfaceAlt: Color(0xFFF5F3D8),
  ink: Color(0xFF1A1A2E),
  mute: Color(0x99FFFFFF),
  accent: Color(0xFFFF8F00),
  accentSoft: Color(0x80FFB300),
  action: Color(0xFFFFD60A),
  actionInk: Color(0xFF1A1A2E),
  active: Color(0xFFFFD60A),
  chipInk: Color(0xFF1A1A2E),
  chipInkSel: Color(0xFF1A1A2E), // 黃底用深色字，避免白字黃底對比不足
  chipBg: Color(0xE6FFFFFF),
  border: Color(0xFF1A1A2E),
  borderW: 3.5,
  shadowColor: Color(0xFF1A1A2E),
  shadowOffset: Offset(5, 5),
  cardRadius: 28,
  chipRadius: 14,
  fontDisplay: 'Fredoka',
  fontBody: 'Outfit',
  fontTimer: 'Fredoka',
  navBg: Color(0xFFFFFDE7),
  navInk: Color(0xFF1A1A2E),
  navBorder: Color(0xFF1A1A2E),
  appBarInk: Color(0xEAFFFFFF),
  timerLabel: 'ME TIME ⏱',
  runningLabel: 'GO GO GO! 🎯',
  timerHaloOn: false,
  bubbleStyle: 'cartoon',
);

const AppTheme darkTheme = AppTheme(
  id: 'dark',
  displayName: '深色卡通',
  bgColor1: Color(0xFF0B1020),
  bgColor2: Color(0xFF1A1A2E),
  bgColor3: Color(0xFF06070D),
  bgIsGradient: true,
  bgBegin: Alignment.topLeft,
  bgEnd: Alignment.bottomRight,
  surface: Color(0xFF1E1F36),
  surfaceAlt: Color(0x0FFFFFFF),
  ink: Color(0xFFF4F2E7),
  mute: Color(0x99F4F2E7),
  accent: Color(0xFFFFD166),
  accentSoft: Color(0x73FFD166),
  action: Color(0xFFFFD166),
  actionInk: Color(0xFF1A1A2E),
  active: Color(0xFFFFD166),
  chipInk: Color(0xFFF4F2E7),
  chipInkSel: Color(0xFF1A1A2E),
  chipBg: Color(0x14FFFFFF),
  border: Color(0xFFF4F2E7),
  borderW: 3,
  shadowColor: Color(0xFF48CAE4),
  shadowOffset: Offset(5, 5),
  cardRadius: 28,
  chipRadius: 14,
  fontDisplay: 'Fredoka',
  fontBody: 'Outfit',
  fontTimer: 'Fredoka',
  navBg: Color(0xFF0B1020),
  navInk: Color(0xFFF4F2E7),
  navBorder: Color(0xFF48CAE4),
  appBarInk: Color(0xFFF4F2E7),
  timerLabel: 'ME TIME ⏱',
  runningLabel: 'GO GO GO! 🌙',
  timerHaloOn: true,
  bubbleStyle: 'cartoon-dark',
);

const AppTheme retroTheme = AppTheme(
  id: 'retro',
  displayName: '復古卡其',
  bgColor1: Color(0xFFD4C4A0),
  bgIsGradient: false,
  surface: Color(0xFFEADFC4),
  surfaceAlt: Color(0xFFC9B687),
  ink: Color(0xFF3D2F1F),
  mute: Color(0xFF7A6647),
  accent: Color(0xFF8B4513),
  accentSoft: Color(0x408B4513),
  action: Color(0xFFA0522D),
  actionInk: Color(0xFFF5EDD8),
  active: Color(0xFF8B6F3A),
  chipInk: Color(0xFF3D2F1F),
  chipInkSel: Color(0xFFF5EDD8),
  chipBg: Color(0xFFEADFC4),
  border: Color(0xFF3D2F1F),
  borderW: 3,
  shadowColor: Color(0xFF3D2F1F),
  shadowOffset: Offset(4, 4),
  cardRadius: 4,
  chipRadius: 2,
  fontDisplay: 'Press Start 2P',
  fontBody: 'VT323',
  fontTimer: 'Press Start 2P',
  navBg: Color(0xFF8B6F3A),
  navInk: Color(0xFFF5EDD8),
  navBorder: Color(0xFF3D2F1F),
  appBarInk: Color(0xFF3D2F1F),
  timerLabel: 'ME TIME',
  runningLabel: 'GO! GO! GO!',
  timerHaloOn: false,
  bubbleStyle: 'pixel',
);

const AppTheme pastelTheme = AppTheme(
  id: 'pastel',
  displayName: '馬卡龍',
  bgColor1: Color(0xFFFFE5EC),
  bgColor2: Color(0xFFFFC9DE),
  bgColor3: Color(0xFFC8B6FF),
  bgIsGradient: true,
  bgBegin: Alignment.topLeft,
  bgEnd: Alignment.bottomRight,
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFFFE5EC),
  ink: Color(0xFF6B3F61),
  mute: Color(0x8C6B3F61),
  accent: Color(0xFFFF8FA3),
  accentSoft: Color(0x59FF8FA3),
  action: Color(0xFFFFB3C6),
  actionInk: Color(0xFF6B3F61),
  active: Color(0xFFC8B6FF),
  chipInk: Color(0xFF6B3F61),
  chipInkSel: Color(0xFF6B3F61), // 淡紫底用深紫字，避免白字淡紫底對比不足
  chipBg: Color(0xFFFFFFFF),
  border: Color(0xFFFFB3C6),
  borderW: 0,
  shadowColor: Color(0x59C896B4),
  shadowOffset: Offset(0, 12),
  cardRadius: 32,
  chipRadius: 22,
  fontDisplay: 'Quicksand',
  fontBody: 'Quicksand',
  fontTimer: 'Quicksand',
  navBg: Color(0xB3FFFFFF),
  navInk: Color(0xFF6B3F61),
  navBorder: Color(0x66FF8FA3),
  appBarInk: Color(0xFF6B3F61),
  timerLabel: 'me time',
  runningLabel: 'focus mode',
  timerHaloOn: false,
  bubbleStyle: 'pastel',
);

const AppTheme minimalTheme = AppTheme(
  id: 'minimal',
  displayName: '極簡',
  bgColor1: Color(0xFFFAFAF7),
  bgIsGradient: false,
  surface: Color(0xFFFFFFFF),
  surfaceAlt: Color(0xFFF1F0EB),
  ink: Color(0xFF111111),
  mute: Color(0xFF9A9A95),
  accent: Color(0xFF111111),
  accentSoft: Color(0x14000000),
  action: Color(0xFF111111),
  actionInk: Color(0xFFFFFFFF),
  active: Color(0xFF111111),
  chipInk: Color(0xFF666666),
  chipInkSel: Colors.white,
  chipBg: Color(0xFFF1F0EB),
  border: Colors.transparent,
  borderW: 0,
  shadowColor: Colors.transparent,
  shadowOffset: Offset.zero,
  cardRadius: 16,
  chipRadius: 10,
  fontDisplay: 'Inter',
  fontBody: 'Inter',
  fontTimer: 'JetBrains Mono',
  navBg: Color(0xFFFFFFFF),
  navInk: Color(0xFF111111),
  navBorder: Color(0xFFEEEEEA),
  appBarInk: Color(0xFF111111),
  timerLabel: 'me time',
  runningLabel: 'focus',
  timerHaloOn: false,
  bubbleStyle: 'none',
);

const Map<String, AppTheme> kAppThemes = {
  'cartoon': cartoonTheme,
  'dark': darkTheme,
  'retro': retroTheme,
  'pastel': pastelTheme,
  'minimal': minimalTheme,
};

const List<String> kThemeOrder = ['cartoon', 'dark', 'retro', 'pastel', 'minimal'];
