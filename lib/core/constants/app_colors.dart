import 'package:flutter/material.dart';

/// App Color Palette for AgriGuardian
/// Supports:
/// 1. Ivory Light Theme (দিনের বেলা মাঠের জন্য পরিষ্কার দৃশ্যমানতা)
/// 2. Deep Emerald Dark Mode (রাতের বেলা বা OLED স্ক্রিনে ব্যাটারি সাশ্রয়ী)
abstract final class AgriColors {
  // Light Palette (Primary)
  static const primaryGreen = Color(0xFF087A43);
  static const deepGreen = Color(0xFF06452E);
  static const forestGreen = Color(0xFF0D5E3A);
  static const brightGreen = Color(0xFF25C863);
  static const softGreen = Color(0xFFEAF7E9);
  static const lightGreenBg = Color(0xFFE4F4E4);
  static const backgroundIvory = Color(0xFFF4F7EE);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardLightSecondary = Color(0xFFF9FAF6);

  // Dark / Emerald Palette
  static const darkBackground = Color(0xFF06120C);
  static const darkSurface = Color(0xFF0C1D14);
  static const darkCard = Color(0xFF10261A);
  static const darkCardBorder = Color(0xFF1D3B2A);
  static const neonGreen = Color(0xFF00E676);
  static const glowingGreen = Color(0xFF22C55E);

  // Status & Risk Colors
  static const amberRisk = Color(0xFFF59E0B);
  static const orangeWarning = Color(0xFFEA580C);
  static const redAlert = Color(0xFFEF4444);
  static const blueWater = Color(0xFF0284C7);
  static const purpleSatellite = Color(0xFF8B5CF6);

  // Text & Neutral Colors
  static const textDark = Color(0xFF1E293B);
  static const textMuted = Color(0xFF64748B);
  static const textLight = Color(0xFFF8FAFC);
  static const textMutedDark = Color(0xFF94A3B8);
  static const borderLight = Color(0xFFE2E8F0);
  static const dividerLight = Color(0xFFEDF2E8);
}
