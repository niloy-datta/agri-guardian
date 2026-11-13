import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class ComponentTheme {
  static CardThemeData cardThemeLight = CardThemeData(
    color: AgriColors.cardLight,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppSpacing.radiusLg,
      side: const BorderSide(color: AgriColors.borderLight),
    ),
  );

  static CardThemeData cardThemeDark = CardThemeData(
    color: AgriColors.darkCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppSpacing.radiusLg,
      side: const BorderSide(color: AgriColors.darkCardBorder),
    ),
  );

  static ElevatedButtonThemeData elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AgriColors.primaryGreen,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.radiusFull,
      ),
    ),
  );
}
