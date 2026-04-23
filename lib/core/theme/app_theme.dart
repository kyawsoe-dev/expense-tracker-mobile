import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primaryDark;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color successSoft;
  final Color shadow;
  final Color border;
  final Color heroStart;
  final Color heroEnd;
  final Color accentStart;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryDark,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.shadow,
    required this.border,
    required this.heroStart,
    required this.heroEnd,
    required this.accentStart,
  });

  static const light = AppPalette(
    background: Color(0xFFF6F4FB),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF1EDFA),
    surfaceSoft: Color(0xFFFBF9FF),
    textPrimary: Color(0xFF241B3A),
    textSecondary: Color(0xFF6F6885),
    textMuted: Color(0xFF9A93AE),
    primary: Color(0xFF7C5CFA),
    primaryDark: Color(0xFF5630D4),
    accent: Color(0xFFFF7A45),
    accentSoft: Color(0xFFFFEEE5),
    success: Color(0xFF1FA56A),
    successSoft: Color(0xFFE8F8F0),
    shadow: Color(0x140E0A1F),
    border: Color(0xFFE6E1F2),
    heroStart: Color(0xFF231942),
    heroEnd: Color(0xFF3A2F71),
    accentStart: Color(0xFFFF985F),
  );

  static const dark = AppPalette(
    background: Color(0xFF120F1D),
    surface: Color(0xFF1A1628),
    surfaceMuted: Color(0xFF241D39),
    surfaceSoft: Color(0xFF201A32),
    textPrimary: Color(0xFFF5F1FF),
    textSecondary: Color(0xFFC1BAD8),
    textMuted: Color(0xFF968EB2),
    primary: Color(0xFFA991FF),
    primaryDark: Color(0xFF7B5CFA),
    accent: Color(0xFFFF9B6B),
    accentSoft: Color(0xFF3A241D),
    success: Color(0xFF4DD89A),
    successSoft: Color(0xFF123126),
    shadow: Color(0x40000000),
    border: Color(0xFF342C4A),
    heroStart: Color(0xFF31235F),
    heroEnd: Color(0xFF171226),
    accentStart: Color(0xFFFFB07E),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? primaryDark,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? successSoft,
    Color? shadow,
    Color? border,
    Color? heroStart,
    Color? heroEnd,
    Color? accentStart,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      shadow: shadow ?? this.shadow,
      border: border ?? this.border,
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      accentStart: accentStart ?? this.accentStart,
    );
  }

  @override
  ThemeExtension<AppPalette> lerp(
    covariant ThemeExtension<AppPalette>? other,
    double t,
  ) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      border: Color.lerp(border, other.border, t)!,
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      accentStart: Color.lerp(accentStart, other.accentStart, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;

  LinearGradient get heroGradient => LinearGradient(
        colors: [palette.heroStart, palette.heroEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get primaryGradient => LinearGradient(
        colors: [palette.primary, palette.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get accentGradient => LinearGradient(
        colors: [palette.accentStart, palette.accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  BoxDecoration appCardDecoration({
    Color? color,
    double radius = 24,
  }) {
    return BoxDecoration(
      color: color ?? palette.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: palette.shadow,
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
      border: Border.all(color: palette.border),
    );
  }
}

class AppTheme {
  static ThemeData light() => _buildTheme(
        brightness: Brightness.light,
        palette: AppPalette.light,
      );

  static ThemeData dark() => _buildTheme(
        brightness: Brightness.dark,
        palette: AppPalette.dark,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppPalette palette,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      primary: palette.primary,
      secondary: palette.accent,
      surface: palette.surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontSize: 30,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: palette.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: palette.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: palette.textMuted,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceSoft,
        selectedColor: palette.primary,
        disabledColor: palette.surfaceMuted,
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: palette.textSecondary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: palette.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSoft,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(
          color: palette.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: palette.textMuted),
        prefixIconColor: palette.textSecondary,
        suffixIconColor: palette.textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: palette.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: palette.textPrimary,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerColor: palette.border,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.primary,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
