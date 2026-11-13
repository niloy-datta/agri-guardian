import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'dark_theme.dart';
import 'component_theme.dart';
import 'typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AgriColors.backgroundIvory,
      fontFamily: AppTypography.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AgriColors.primaryGreen,
        primary: AgriColors.primaryGreen,
        surface: AgriColors.cardLight,
      ),
      cardTheme: ComponentTheme.cardThemeLight,
      elevatedButtonTheme: ComponentTheme.elevatedButtonTheme,
    );
  }

  static ThemeData get darkTheme => DarkTheme.themeData;
}
