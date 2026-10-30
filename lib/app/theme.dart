import 'package:flutter/material.dart';

/// FamBoard's look: a calm, warm "kitchen board". Deep teal for actions,
/// marigold for highlights, soft paper background, generous touch targets.
abstract final class FamTheme {
  static const teal = Color(0xFF1F6F6B);
  static const marigold = Color(0xFFE8A33D);
  static const paper = Color(0xFFFAF7F2);
  static const ink = Color(0xFF1E2725);
  static const overdue = Color(0xFFC62828);
  static const success = Color(0xFF2E7D32);

  static ThemeData light({bool large = false}) => _build(
        ColorScheme.fromSeed(
          seedColor: teal,
          primary: teal,
          secondary: marigold,
          surface: paper,
          brightness: Brightness.light,
        ),
        large: large,
      );

  static ThemeData dark({bool large = false}) => _build(
        ColorScheme.fromSeed(
          seedColor: teal,
          secondary: marigold,
          brightness: Brightness.dark,
        ),
        large: large,
      );

  static ThemeData _build(ColorScheme scheme, {required bool large}) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: large ? VisualDensity.comfortable : VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
