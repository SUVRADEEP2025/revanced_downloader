import 'package:flutter/material.dart';

/// Builds the app [ThemeData] on top of a [ColorScheme].
///
/// Single source of truth for Material 3 styling: app bars, cards,
/// buttons, inputs, and snack bars.
ThemeData buildAppTheme(ColorScheme colorScheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: colorScheme.surfaceContainer,
      foregroundColor: colorScheme.onSurface,
    ),
    scaffoldBackgroundColor: colorScheme.surface,
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: colorScheme.surfaceContainer,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// Resolves the light/dark schemes from the system dynamic color
/// (Android 12+ wallpaper palette), falling back to a seeded green scheme.
({ColorScheme light, ColorScheme dark}) resolveAppSchemes(
  ColorScheme? lightDynamic,
  ColorScheme? darkDynamic,
) {
  final light = lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.green);
  final dark =
      darkDynamic ??
      ColorScheme.fromSeed(
        seedColor: ThemeData.dark().colorScheme.primary,
        brightness: ThemeData.dark().brightness,
      );
  return (light: light, dark: dark);
}
