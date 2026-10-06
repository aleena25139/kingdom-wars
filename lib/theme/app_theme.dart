// Central ThemeData for the whole app. Screens should pull colors/text
// styles from here (via Theme.of(context)) rather than hardcoding, so a
// future re-skin only touches this file.
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String titleFontFamily = 'Cinzel';

  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.royalGold,
        secondary: AppColors.emeraldGood,
        surface: AppColors.surface,
        error: AppColors.crimsonEvil,
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontFamily: titleFontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.royalGold,
          fontSize: 42,
          letterSpacing: 2,
          shadows: [
            Shadow(color: AppColors.lightGold, blurRadius: 18),
            Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        titleLarge: const TextStyle(
          fontFamily: titleFontFamily,
          fontWeight: FontWeight.bold,
          color: AppColors.textGold,
          fontSize: 22,
        ),
        bodyMedium: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonPrimary,
          foregroundColor: AppColors.lightGold,
          disabledBackgroundColor: AppColors.buttonPrimary.withValues(alpha: 0.4),
          side: const BorderSide(color: AppColors.royalGold, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(
            fontFamily: titleFontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(AppColors.buttonPrimaryPressed),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepPurple,
        titleTextStyle: TextStyle(
          fontFamily: titleFontFamily,
          color: AppColors.textGold,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
