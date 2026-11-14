import 'package:flutter/material.dart';

class CyberColors {
  CyberColors._();

  static const appBackground = Color(0xFFF7F2F5);
  static const surface = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const elevatedCard = Color(0xFFFDF9FB);

  static const border = Color(0x1A8B1E3F);
  static const subtleBorder = Color(0x148B1E3F);

  static const primary = Color(0xFF8B1E3F);
  static const secondary = Color(0xFFA63A5C);
  static const deepBurgundy = Color(0xFF8B1E3F);
  static const brightCrimson = Color(0xFFC2284B);

  static const textPrimary = Color(0xFF1C1218);
  static const textSecondary = Color(0xFF6E5F68);
  static const textMuted = Color(0xFF9C8F97);

  static const success = Color(0xFF17A673);
  static const warning = Color(0xFFE8A200);
  static const error = Color(0xFFE91E4F);

  static const primaryButtonGradient = LinearGradient(
    colors: [primary, brightCrimson],
  );
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, brightCrimson],
  );
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF9EDEF), appBackground, Color(0xFFFBF7F9)],
  );
  static const cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surface, elevatedCard],
  );
}

class CyberTheme {
  CyberTheme._();

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: CyberColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: CyberColors.primary,
          onPrimary: CyberColors.surface,
          primaryContainer: const Color(0xFFF3DCE4),
          onPrimaryContainer: CyberColors.textPrimary,
          secondary: CyberColors.secondary,
          onSecondary: CyberColors.surface,
          secondaryContainer: const Color(0xFFF5E1E8),
          onSecondaryContainer: CyberColors.textPrimary,
          tertiary: CyberColors.warning,
          onTertiary: CyberColors.textPrimary,
          tertiaryContainer: const Color(0xFFFFF1D1),
          onTertiaryContainer: CyberColors.textPrimary,
          error: CyberColors.error,
          onError: CyberColors.surface,
          errorContainer: const Color(0xFFFCE1E8),
          onErrorContainer: CyberColors.textPrimary,
          surface: CyberColors.surface,
          onSurface: CyberColors.textPrimary,
          onSurfaceVariant: CyberColors.textSecondary,
          surfaceContainerHighest: CyberColors.elevatedCard,
          outline: CyberColors.textMuted,
          outlineVariant: CyberColors.border,
          inversePrimary: CyberColors.brightCrimson,
        );
    final baseTextTheme = ThemeData.light().textTheme.apply(
      bodyColor: CyberColors.textPrimary,
      displayColor: CyberColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: baseTextTheme,
      scaffoldBackgroundColor: CyberColors.appBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: CyberColors.appBackground,
        foregroundColor: CyberColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: CyberColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: CyberColors.border),
        ),
      ),
      iconTheme: const IconThemeData(color: CyberColors.primary),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CyberColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFF3DCE4),
        labelTextStyle: WidgetStatePropertyAll(
          baseTextTheme.labelMedium?.copyWith(
            color: CyberColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: CyberColors.primary,
          foregroundColor: CyberColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CyberColors.primary,
          side: const BorderSide(color: CyberColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CyberColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CyberColors.surface,
        labelStyle: const TextStyle(color: CyberColors.textSecondary),
        hintStyle: const TextStyle(color: CyberColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CyberColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CyberColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CyberColors.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: CyberColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: CyberColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: CyberColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dividerTheme: const DividerThemeData(
        color: CyberColors.subtleBorder,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: CyberColors.primary,
        linearTrackColor: CyberColors.subtleBorder,
        circularTrackColor: CyberColors.subtleBorder,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CyberColors.textPrimary,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
          color: CyberColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
