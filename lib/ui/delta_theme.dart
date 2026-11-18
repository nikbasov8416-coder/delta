import 'package:material_ui/material_ui.dart';

const familyColor = Color(0xffa07a2e);
const personalColor = Color(0xff00766f);

ThemeData deltaTheme(Brightness brightness) {
  final colors =
      ColorScheme.fromSeed(
        seedColor: personalColor,
        brightness: brightness,
      ).copyWith(
        primaryContainer: brightness == Brightness.light
            ? const Color(0xffcce8e2)
            : null,
        surface: brightness == Brightness.light
            ? const Color(0xfff2f8f6)
            : const Color(0xff101c1a),
      );
  return ThemeData(
    colorScheme: colors,
    useMaterial3: true,
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
    ),
    cardTheme: CardThemeData(
      color: colors.surfaceContainerLow,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
