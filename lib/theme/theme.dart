import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const primaryLight = Color(0xFFE8F5E9);
  static const accent = Color(0xFF1565C0);
  static const income = Color(0xFF2E7D32);
  static const expense = Color(0xFFD32F2F);
  static const transfer = Color(0xFF1565C0);
  static const background = Color(0xFFF5F6F8);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1C1E);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
  static const white = Color(0xFFFFFFFF);

  static const darkBackground = Color(0xFF121212);
  static const darkCard = Color(0xFF1E1E1E);
  static const darkText = Color(0xFFE0E0E0);
  static const darkTextSecondary = Color(0xFF9E9E9E);
  static const darkBorder = Color(0xFF333333);
  static const darkAppBar = Color(0xFF1E1E1E);
  static const darkBottomBar = Color(0xFF1E1E1E);

  static Color backgroundFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : background;

  static Color cardFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : card;

  static Color textFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkText : text;

  static Color textSecondaryFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;

  static Color borderFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : border;
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 4,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.primary,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: false,
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.primary,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: AppColors.darkCard,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkAppBar,
      foregroundColor: AppColors.darkText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.darkText),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.darkCard,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.darkBorder, thickness: 1, space: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkBottomBar,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 4,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.darkTextSecondary,
      indicatorColor: AppColors.primary,
    ),
  );
}
