import 'package:flutter/material.dart';
import 'text_styles.dart';

class AppColors {
  static const Color primary = Color(0xFF128C7E);
  static const Color primaryDark = Color(0xFF0C5B52);
  static const Color secondary = Color(0xFF40C9A2);
  static const Color background = Color(0xFFF3F7F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEAF3EF);
  static const Color textPrimary = Color(0xFF16342E);
  static const Color textSecondary = Color(0xFF617670);
  static const Color border = Color(0xFFD8E4DE);
  static const Color successSoft = Color(0xFFE6F7EE);
  static const Color warningSoft = Color(0xFFFFF1DD);
  static const Color white = Colors.white;
  static const Color error = Color(0xFFC62828);
}

class AppThemeValues {
  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radius = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusExtraLarge = 24.0;

  // Borders
  static const double borderWidth = 1.0;
  static const double focusedBorderWidth = 1.2;

  // Spacing / Margins / Paddings
  static const double spacingTiny = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 12.0;
  static const double spacingLarge = 16.0;
  static const double spacingExtraLarge = 24.0;
  static const double spacingHuge = 32.0;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      textTheme: AppTextStyles.textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeValues.radius),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border, width: AppThemeValues.borderWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemeValues.radius),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeValues.radius),
          borderSide: const BorderSide(color: AppColors.border, width: AppThemeValues.borderWidth),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeValues.radius),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: AppThemeValues.focusedBorderWidth),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeValues.radius),
          borderSide: const BorderSide(color: AppColors.error, width: AppThemeValues.borderWidth),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppThemeValues.radius),
          borderSide: const BorderSide(color: AppColors.error, width: AppThemeValues.borderWidth),
        ),
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14.5,
          letterSpacing: -0.15,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14.5,
          letterSpacing: -0.15,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border, width: AppThemeValues.borderWidth),
          borderRadius: BorderRadius.circular(AppThemeValues.radius),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        disabledColor: AppColors.surfaceMuted,
        selectedColor: AppColors.textPrimary,
        secondarySelectedColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.surfaceMuted,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.textPrimary
                : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            fontSize: 13,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
