import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class BrandColors {
  BrandColors._();

  static const red = Color(0xFFE87722);
  static const redDark = Color(0xFFC0611A);
  static const redLight = Color(0xFFFDF1E8);

  static const blue = Color(0xFF003DA5);
  static const blueDark = Color(0xFF002B82);
  static const blueLight = Color(0xFFE6EEF9);

  static const navy = Color(0xFF0C1F3F);
  static const navyLight = Color(0xFF1A2E52);

  static const gold = Color(0xFFFFB81C);
  static const goldLight = Color(0xFFFFF4DC);

  static const emerald = Color(0xFF00A651);
  static const emeraldLight = Color(0xFFE6F9EF);

  static const surface = Color(0xFFF8F9FB);
  static const surfaceDark = Color(0xFF0E1825);
  static const cardDark = Color(0xFF162031);

  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textDark = Color(0xFFF1F5F9);
  static const textSecondaryDark = Color(0xFF94A3B8);

  static const border = Color(0xFFE2E8F0);
  static const borderDark = Color(0xFF1E293B);
}

class BrandTheme {
  BrandTheme._();

  static ShadThemeData light() {
    final colorScheme = ShadColorScheme.fromName(
      'blue',
      brightness: Brightness.light,
    ).copyWith(
      primary: BrandColors.blue,
      primaryForeground: Colors.white,
      secondary: BrandColors.blueLight,
      secondaryForeground: BrandColors.blue,
      destructive: BrandColors.red,
      destructiveForeground: Colors.white,
      background: BrandColors.surface,
      foreground: BrandColors.textPrimary,
      card: Colors.white,
      cardForeground: BrandColors.textPrimary,
      muted: BrandColors.blueLight,
      mutedForeground: BrandColors.textSecondary,
      border: BrandColors.border,
      ring: BrandColors.blue,
      selection: BrandColors.blueLight,
    );

    return ShadThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
      radius: const BorderRadius.all(Radius.circular(12)),
      cardTheme: ShadCardTheme(
        radius: BorderRadius.circular(16),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  static ShadThemeData dark() {
    final colorScheme = ShadColorScheme.fromName(
      'blue',
      brightness: Brightness.dark,
    ).copyWith(
      primary: BrandColors.blue,
      primaryForeground: Colors.white,
      secondary: BrandColors.navyLight,
      secondaryForeground: BrandColors.blueLight,
      destructive: BrandColors.red,
      destructiveForeground: Colors.white,
      background: BrandColors.surfaceDark,
      foreground: BrandColors.textDark,
      card: BrandColors.cardDark,
      cardForeground: BrandColors.textDark,
      muted: BrandColors.navyLight,
      mutedForeground: BrandColors.textSecondaryDark,
      border: BrandColors.borderDark,
      ring: BrandColors.blue,
      selection: BrandColors.navyLight,
    );

    return ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
      radius: const BorderRadius.all(Radius.circular(12)),
      cardTheme: ShadCardTheme(
        radius: BorderRadius.circular(16),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}
