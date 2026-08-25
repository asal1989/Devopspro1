import 'package:flutter/material.dart';

/// Central color palette. One strong accent color, kept consistent
/// across light and dark themes.
class AppColors {
  AppColors._();

  static const Color accent = Color(0xFF2F6FED); // primary brand blue
  static const Color accentDark = Color(0xFF5B8DEF);

  static const Color success = Color(0xFF23A26D);
  static const Color warning = Color(0xFFE0A429);
  static const Color danger = Color(0xFFE0473E);

  // Light theme
  static const Color lightBackground = Color(0xFFF6F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE7E9F1);
  static const Color lightTextPrimary = Color(0xFF14161C);
  static const Color lightTextSecondary = Color(0xFF6B7080);

  // Dark theme
  static const Color darkBackground = Color(0xFF101114);
  static const Color darkSurface = Color(0xFF1B1D22);
  static const Color darkBorder = Color(0xFF2B2E36);
  static const Color darkTextPrimary = Color(0xFFF3F4F7);
  static const Color darkTextSecondary = Color(0xFFA0A4B2);
}
