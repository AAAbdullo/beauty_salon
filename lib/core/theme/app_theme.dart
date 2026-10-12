import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Токены дизайна Go'zallik. Источник: gozallik_design_spec.md.
/// Цвета светлой темы измерены по присланным экранам; тёмная тема предложена.
class AppColors {
  // Бренд
  static const primary = Color(0xFFE4178C);
  static const primaryBright = Color(0xFFED1785);
  static const primaryDeep = Color(0xFFC5238A);
  static const primaryText = Color(0xFFC61A70);
  static const primaryTint = Color(0xFFFCEAF4);

  // Поверхности и текст
  static const background = Color(0xFFFBF6FA);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0C0C10);
  static const muted = Color(0xFF8F8E96);

  // Статусы
  static const successBg = Color(0xFFDFF9F2);
  static const successText = Color(0xFF247659);
  static const success = Color(0xFF1AAA4C);
  static const gold = Color(0xFFF7BF52);

  // Тёмная тема (предложено, не измерено)
  static const darkBackground = Color(0xFF14101A);
  static const darkSurface = Color(0xFF211A2B);
  static const darkLine = Color(0xFF3A3045);
  static const darkInk = Color(0xFFF1EBF7);
  static const darkMuted = Color(0xFFB3A8C0);
  static const darkPrimaryTint = Color(0xFF3A2A4D);
  static const darkSuccessBg = Color(0xFF123D2E);
  static const darkSuccessText = Color(0xFF6FD9AE);
}

class AppSizes {
  static const screenPadding = 16.0;
  static const buttonHeight = 48.0;
  static const cardRadius = 20.0;
  static const chipRadius = 20.0;
  static const slotWidth = 83.0;
  static const slotHeight = 37.0;
  static const dateWidth = 48.0;
  static const dateHeight = 60.0;
  static const iconTile = 47.0;
  static const backButton = 44.0;
}

class AppGradients {
  /// Кнопка действия (слева направо).
  static const cta = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryDeep],
  );

  /// Фон экрана: мягкий розовый сверху, почти белый внизу.
  static const page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBEFF4), Color(0xFFFEFAFD)],
  );
}

TextTheme _textTheme(Color ink, Color muted) {
  final base = GoogleFonts.manropeTextTheme();
  return base.copyWith(
    headlineLarge: base.headlineLarge?.copyWith(fontSize: 26, fontWeight: FontWeight.w800, color: ink),
    headlineMedium: base.headlineMedium?.copyWith(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
    titleLarge: base.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
    titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: ink),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: ink),
    bodySmall: base.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: muted),
    labelLarge: base.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
    labelMedium: base.labelMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
    labelSmall: base.labelSmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
  );
}

ThemeData _build({
  required Brightness brightness,
  required Color background,
  required Color surface,
  required Color ink,
  required Color muted,
  required Color tint,
  required Color line,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.primaryDeep,
    surface: surface,
    onSurface: ink,
    onSurfaceVariant: muted,
    primaryContainer: tint,
    outlineVariant: line,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    textTheme: _textTheme(ink, muted),
    dividerColor: line,
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.cardRadius)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        shape: const StadiumBorder(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: AppColors.primary,
      side: BorderSide(color: line),
      shape: const StadiumBorder(),
      labelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: ink),
      secondaryLabelStyle: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      hintStyle: TextStyle(color: muted),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: tint,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.primary : line,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
    ),
  );
}

final ThemeData lightTheme = _build(
  brightness: Brightness.light,
  background: AppColors.background,
  surface: AppColors.surface,
  ink: AppColors.ink,
  muted: AppColors.muted,
  tint: AppColors.primaryTint,
  line: const Color(0xFFF3DCE8), // оценка, не измерено
);

final ThemeData darkTheme = _build(
  brightness: Brightness.dark,
  background: AppColors.darkBackground,
  surface: AppColors.darkSurface,
  ink: AppColors.darkInk,
  muted: AppColors.darkMuted,
  tint: AppColors.darkPrimaryTint,
  line: AppColors.darkLine,
);
