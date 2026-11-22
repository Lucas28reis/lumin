import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  static const Color background = Color(0xFFF5F8FA);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFE8EFF2);

  static const Color primary = Color(0xFFFDAC2F);
  static const Color primaryDark = Color(0xFF081B40);
  static const Color accent = Color(0xFFFDAC2F);

  static const Color warning = Color(0xFFE85D4A);
  static const Color freezeBlue = Color(0xFF38A3E0);

  static const Color textPrimary = Color(0xFF081B40);
  static const Color textSecondary = Color(0xFF354A70);

  static const Color onBackground = Color(0xFF233037);
  static const Color onBackgroundMuted = Color(0xFF526168);

  static const Color border = Color(0xFFCFDADE);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.textPrimary,
      secondary: AppColors.accent,
      onSecondary: AppColors.textPrimary,
      surface: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceAlt,
      surfaceContainerHighest: AppColors.surfaceAlt,
      onSurface: AppColors.textPrimary,
      error: AppColors.warning,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.onBackground,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppColors.onBackground,
          height: 1.2,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onBackground,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        // IMPORTANTE: TextField usa bodyLarge como cor do texto digitado!
        // Mantemos textPrimary (#081B40) para alto contraste dentro do input (#FBE8CF).
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.onBackgroundMuted,
          height: 1.4,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: AppColors.textSecondary.withValues(alpha: 0.65),
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.textPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
        ),
      ),
    );
  }
}
