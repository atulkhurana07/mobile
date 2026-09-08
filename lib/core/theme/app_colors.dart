import 'package:flutter/material.dart';

class AppColors {
  // Brand & Surfaces (Safety Dark & Crisp Light)
  static const Color primary = Color(0xFF0284C7); // Electric Cyan/Blue
  static const Color primaryDark = Color(0xFF0369A1);
  static const Color primaryLight = Color(0xFF38BDF8);

  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B);    // Slate 800
  static const Color cardDark = Color(0xFF334155);       // Slate 700
  static const Color borderDark = Color(0xFF475569);

  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Status & Telemetry Colors
  static const Color success = Color(0xFF10B981); // Emerald (Charging / Optimal)
  static const Color warning = Color(0xFFF59E0B); // Amber (Warning / Medium Battery)
  static const Color error = Color(0xFFEF4444);   // Crimson (Critical / Low Battery)
  static const Color info = Color(0xFF3B82F6);    // Sky (Moving / Info)
  static const Color offline = Color(0xFF64748B); // Slate (Offline / Stale)

  // Battery Level Colors
  static Color batteryColor(double socPct) {
    if (socPct > 40) return success;
    if (socPct >= 20) return warning;
    return error;
  }
}
