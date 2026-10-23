import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppColors – Brand palette
//
// Primary   : #00994D  (emerald green)
// Secondary : #0A6C3B  (deep forest green)
// Accent    : #F5A623  (amber / gold – split-complementary to green)
//
// All neutrals are green-tinted to keep the UI cohesive with the brand.
// ---------------------------------------------------------------------------
class AppColors {
  AppColors._();

  // ── Brand greens ──────────────────────────────────────────────────────────
  static const Color primary          = Color(0xFF00994D);
  static const Color primaryDark      = Color(0xFF0A6C3B);
  static const Color primaryLight     = Color(0xFF33B87D);
  static const Color primaryContainer = Color(0xFFE6F7EE);
  static const Color onPrimary        = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF1C2B23);

  static const Color secondary       = Color(0xFF0A6C3B);
  static const Color onSecondary     = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD4EDDE);
  static const Color onSecondaryContainer = Color(0xFF0A6C3B);

  // ── Accent (amber / gold) ──────────────────────────────────────────────────
  static const Color accent           = Color(0xFFF5A623);
  static const Color accentText       = Color(0xFFB45309);
  static const Color accentContainer  = Color(0xFFFFF3D4);
  static const Color onAccent         = Color(0xFFFFFFFF);
  static const Color onAccentContainer = Color(0xFFB45309);

  // ── Neutrals (green-tinted) ───────────────────────────────────────────────
  static const Color background       = Color(0xFFFFFFFF);
  static const Color surface          = Color(0xFFF4F8F6);
  static const Color surfaceVariant   = Color(0xFFE0E6E3);
  static const Color textPrimary      = Color(0xFF1C2B23);
  static const Color textSecondary    = Color(0xFF5E6E66);
  static const Color disabled         = Color(0xFFB8C4BE);
  static const Color outline          = Color(0xFFB8C4BE);

  // ── Semantic / status ─────────────────────────────────────────────────────
  static const Color error           = Color(0xFFDC2626);
  static const Color onError         = Color(0xFFFFFFFF);
  static const Color errorContainer  = Color(0xFFFEF2F2);
  static const Color onErrorContainer = Color(0xFFDC2626);

  static const Color info            = Color(0xFF1E40AF);
  static const Color onInfo          = Color(0xFFFFFFFF);
  static const Color infoContainer   = Color(0xFFEFF6FF);
  static const Color onInfoContainer = Color(0xFF1E40AF);

  // ── Dark-mode variants ────────────────────────────────────────────────────
  static const Color darkBackground       = Color(0xFF0B1612);
  static const Color darkSurface          = Color(0xFF15221C);
  static const Color darkSurfaceVariant   = Color(0xFF1E2F27);
  static const Color darkTextPrimary      = Color(0xFFE8F5EE);
  static const Color darkTextSecondary    = Color(0xFF9AB5A7);
  static const Color darkOutline          = Color(0xFF2E3F37);

  static const Color darkPrimary          = Color(0xFF22C55E);
  static const Color darkOnPrimary        = Color(0xFF0B1612);
  static const Color darkPrimaryContainer = Color(0xFF0F3D24);
  static const Color darkOnPrimaryContainer = Color(0xFFD4F5E3);

  static const Color darkSecondary        = Color(0xFF34D399);
  static const Color darkOnSecondary      = Color(0xFF0B1612);
  static const Color darkSecondaryContainer = Color(0xFF1A3D2E);
  static const Color darkOnSecondaryContainer = Color(0xFFD4F5E3);

  static const Color darkAccent           = Color(0xFFFBBF24);
  static const Color darkOnAccent         = Color(0xFF2A1B00);
  static const Color darkAccentContainer  = Color(0xFF4A3200);
  static const Color darkOnAccentContainer = Color(0xFFFDE68A);

  static const Color darkError            = Color(0xFFF87171);
  static const Color darkOnError          = Color(0xFF450A0A);
  static const Color darkErrorContainer   = Color(0xFF7F1D1D);
  static const Color darkOnErrorContainer = Color(0xFFFEF2F2);
}

// ---------------------------------------------------------------------------
// AppFonts – Brand typography
//
// Montserrat is the major (primary) face, Lato the supporting face.
// Both families are registered in `pubspec.yaml`.
// ---------------------------------------------------------------------------
class AppFonts {
  AppFonts._();

  /// Major / primary font — used for all text by default.
  static const String primary = 'Montserrat';

  /// Supporting font — registered as the fallback for [primary].
  static const String supporting = 'Lato';
}

// ---------------------------------------------------------------------------
// AppTheme – Ready-to-use ThemeData for light and dark modes
//
// Usage:
//   MaterialApp(
//     theme: AppTheme.light,
//     darkTheme: AppTheme.dark,
//     themeMode: ThemeMode.system,
//   )
// ---------------------------------------------------------------------------
class AppTheme {
  AppTheme._();

  // ── ColorSchemes ──────────────────────────────────────────────────────────

  static ColorScheme get lightScheme => ColorScheme(
        brightness: Brightness.light,
        primary:              AppColors.primary,
        onPrimary:            AppColors.onPrimary,
        primaryContainer:     AppColors.primaryContainer,
        onPrimaryContainer:   AppColors.onPrimaryContainer,

        secondary:            AppColors.secondary,
        onSecondary:          AppColors.onSecondary,
        secondaryContainer:   AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,

        tertiary:             AppColors.accent,
        onTertiary:           AppColors.onAccent,
        tertiaryContainer:    AppColors.accentContainer,
        onTertiaryContainer:  AppColors.onAccentContainer,

        surface:              AppColors.surface,
        onSurface:            AppColors.textPrimary,
        surfaceContainerLow:  const Color(0xFFFAFCFB),
        surfaceContainer:     AppColors.surface,
        surfaceContainerHigh: AppColors.surfaceVariant,
        onSurfaceVariant:     AppColors.textSecondary,

        error:                AppColors.error,
        onError:              AppColors.onError,
        errorContainer:       AppColors.errorContainer,
        onErrorContainer:     AppColors.onErrorContainer,

        outline:              AppColors.outline,
        outlineVariant:       AppColors.disabled,
        shadow:               const Color(0xFF000000),
        surfaceTint:          AppColors.primary,
      );

  static ColorScheme get darkScheme => ColorScheme(
        brightness: Brightness.dark,
        primary:              AppColors.darkPrimary,
        onPrimary:            AppColors.darkOnPrimary,
        primaryContainer:     AppColors.darkPrimaryContainer,
        onPrimaryContainer:   AppColors.darkOnPrimaryContainer,

        secondary:            AppColors.darkSecondary,
        onSecondary:          AppColors.darkOnSecondary,
        secondaryContainer:   AppColors.darkSecondaryContainer,
        onSecondaryContainer: AppColors.darkOnSecondaryContainer,

        tertiary:             AppColors.darkAccent,
        onTertiary:           AppColors.darkOnAccent,
        tertiaryContainer:    AppColors.darkAccentContainer,
        onTertiaryContainer:  AppColors.darkOnAccentContainer,

        surface:              AppColors.darkSurface,
        onSurface:            AppColors.darkTextPrimary,
        surfaceContainerLow:  const Color(0xFF111E18),
        surfaceContainer:     AppColors.darkSurface,
        surfaceContainerHigh: AppColors.darkSurfaceVariant,
        onSurfaceVariant:     AppColors.darkTextSecondary,

        error:                AppColors.darkError,
        onError:              AppColors.darkOnError,
        errorContainer:       AppColors.darkErrorContainer,
        onErrorContainer:     AppColors.darkOnErrorContainer,

        outline:              AppColors.darkOutline,
        outlineVariant:       const Color(0xFF25352E),
        shadow:               const Color(0xFF000000),
        surfaceTint:          AppColors.darkPrimary,
      );

  // ── Public ThemeData getters ──────────────────────────────────────────────

  static ThemeData get light => _buildTheme(lightScheme, true);
  static ThemeData get dark  => _buildTheme(darkScheme, false);

  // ── Internal builder ──────────────────────────────────────────────────────

  static ThemeData _buildTheme(ColorScheme scheme, bool isLight) {
    final Color primary          = isLight ? AppColors.primary       : AppColors.darkPrimary;
    final Color onPrimary        = isLight ? AppColors.onPrimary     : AppColors.darkOnPrimary;
    final Color primaryContainer = isLight ? AppColors.primaryContainer : AppColors.darkPrimaryContainer;
    final Color onPrimaryContainer = isLight ? AppColors.onPrimaryContainer : AppColors.darkOnPrimaryContainer;
    final Color surface          = isLight ? AppColors.surface       : AppColors.darkSurface;
    final Color surfaceVariant   = isLight ? AppColors.surfaceVariant : AppColors.darkOutline;
    final Color textPrimary      = isLight ? AppColors.textPrimary   : AppColors.darkTextPrimary;
    final Color textSecondary    = isLight ? AppColors.textSecondary : AppColors.darkTextSecondary;
    final Color disabled         = isLight ? AppColors.disabled      : AppColors.darkOutline;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? AppColors.background : AppColors.darkBackground,
      // Brand typography: Montserrat is the major face, Lato the supporting
      // (fallback) face.
      fontFamily: AppFonts.primary,
      fontFamilyFallback: const [AppFonts.supporting],

      // ── AppBar ───────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          fontFamily: AppFonts.primary,
        ),
        iconTheme: IconThemeData(color: onPrimary),
        actionsIconTheme: IconThemeData(color: onPrimary),
      ),

      // ── Buttons ──────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: disabled),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(48, 40),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: surfaceVariant),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Text fields ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: disabled),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: disabled),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
      ),

      // ── Chips ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: primaryContainer,
        selectedColor: primary,
        side: BorderSide(color: primary),
        labelStyle: TextStyle(
          color: onPrimaryContainer,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── SnackBar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: TextStyle(
          color: isLight ? AppColors.background : AppColors.darkTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        actionTextColor: AppColors.accent,
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: surfaceVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Progress ─────────────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primaryContainer,
      ),

      // ── Switch ───────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? onPrimary : disabled),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : surfaceVariant),
      ),

      // ── Radio ────────────────────────────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : disabled),
      ),

      // ── Checkbox ─────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : Colors.transparent),
        checkColor: WidgetStateProperty.resolveWith((_) => onPrimary),
        side: BorderSide(color: disabled, width: 2),
      ),

      // ── Search bar ───────────────────────────────────────────────────────
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStateProperty.resolveWith((_) => surface),
        elevation: WidgetStateProperty.resolveWith((_) => 0.0),
        shadowColor: WidgetStateProperty.resolveWith((_) => Colors.black26),
        hintStyle: WidgetStateProperty.resolveWith((_) => TextStyle(color: textSecondary, fontSize: 14)),
        padding: WidgetStateProperty.resolveWith((_) => const EdgeInsets.symmetric(horizontal: 16)),
        shape: WidgetStateProperty.resolveWith((_) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),

      // ── Tabs ─────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),

      // ── Text selection ───────────────────────────────────────────────────
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primaryContainer,
        selectionHandleColor: primary,
      ),

      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

