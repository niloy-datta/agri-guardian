import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'component_theme.dart';
import 'typography.dart';

class DarkTheme {
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AgriColors.darkBackground,
      fontFamily: AppTypography.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AgriColors.neonGreen,
        brightness: Brightness.dark,
        primary: AgriColors.neonGreen,
        surface: AgriColors.darkCard,
      ),
      cardTheme: ComponentTheme.cardThemeDark,
      elevatedButtonTheme: ComponentTheme.elevatedButtonTheme,
    );
  }
}
