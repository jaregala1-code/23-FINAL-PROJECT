import 'package:flutter/material.dart';

class AppColors {
  static const Color green = Color(0xFF4d8b31);
  static const Color orange = Color(0xFFff8427);
  static const Color yellow = Color(0xFFffc800);
  static const Color white = Color(0xFFffffff);
  static const Color black = Color(0xFF1a1a1a);
  static const Color darkBg = Color(0xFF111111);
  static const Color cardBg = Color(0xFF1e1e1e);
  static const Color cardBg2 = Color(0xFF252525);
  static const Color mutedText = Color(0xFF888888);
  static const Color border = Color(0xFF2e2e2e);
  static const Color inputBg = Color(0xFF1a1a1a);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.green,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.green,
        secondary: AppColors.yellow,
        surface: AppColors.cardBg,
        error: Color(0xFFcf6679),
      ),
      fontFamily: 'Sora',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        displayMedium: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.white),
        bodyMedium: TextStyle(color: AppColors.mutedText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.yellow, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFcf6679)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFcf6679), width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.mutedText),
        hintStyle: const TextStyle(color: AppColors.mutedText),
        prefixIconColor: AppColors.mutedText,
        suffixIconColor: AppColors.mutedText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.white),
        titleTextStyle: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}
