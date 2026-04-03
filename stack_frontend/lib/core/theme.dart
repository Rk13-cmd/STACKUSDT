import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color backgroundPrimary = Color(0xFF0D0D0F);
  static const Color backgroundSecondary = Color(0xFF1A1A1F);
  static const Color backgroundTertiary = Color(0xFF252530);

  static const Color amber = Color(0xFFFFB800);
  static const Color amberLight = Color(0xFFFFD54F);
  static const Color amberDark = Color(0xFFCC9400);

  static const Color cyan = Color(0xFF00E5FF);
  static const Color cyanDark = Color(0xFF00B8D4);
  static const Color cyanGlow = Color(0x4000E5FF);

  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonRed = Color(0xFFFF073A);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textMuted = Color(0xFF6B6B6B);

  static const Color goldGradientStart = Color(0xFFFFD700);
  static const Color goldGradientEnd = Color(0xFFB8860B);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundPrimary,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyan,
        secondary: AppColors.amber,
        surface: AppColors.backgroundSecondary,
        error: AppColors.neonRed,
        onPrimary: AppColors.backgroundPrimary,
        onSecondary: AppColors.backgroundPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
      ),
      textTheme: _buildTextTheme(),
      cardTheme: CardThemeData(
        color: AppColors.backgroundSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.backgroundTertiary, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.backgroundPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cyan,
          side: const BorderSide(color: AppColors.cyan, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.rajdhani(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.cyan;
          }
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.cyanGlow;
          }
          return AppColors.backgroundTertiary;
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.backgroundTertiary,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.cyan),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.orbitron(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: 2,
      ),
      displayMedium: GoogleFonts.orbitron(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: 1.5,
      ),
      displaySmall: GoogleFonts.orbitron(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: 1,
      ),
      headlineLarge: GoogleFonts.rajdhani(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.rajdhani(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.rajdhani(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.rajdhani(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: 1,
      ),
      labelMedium: GoogleFonts.rajdhani(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelSmall: GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class NeonBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double width;
  final BorderRadius? borderRadius;

  const NeonBorder({
    super.key,
    required this.child,
    this.color = AppColors.cyan,
    this.width = 2,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(color: color, width: width),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final BorderRadius? borderRadius;

  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor = AppColors.cyanGlow,
    this.blurRadius = 20,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: blurRadius, spreadRadius: 0),
        ],
      ),
      child: child,
    );
  }
}
