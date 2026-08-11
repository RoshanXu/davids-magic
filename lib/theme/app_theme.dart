import 'package:flutter/material.dart';

/// 应用主题管理 — 浅色/深色主题，大字体适配老年人
class AppTheme {
  // 字号规范（符合 PRD 老年人友好要求）
  static const double fontSizeTitle = 22;
  static const double fontSizeButton = 18;
  static const double fontSizeList = 16;
  static const double fontSizeLabel = 14;
  static const double fontSizeSmall = 12;

  // 圆角
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;

  // 间距
  static const double spacingSmall = 8;
  static const double spacingMedium = 16;
  static const double spacingLarge = 24;

  static const Color primaryColor = Color(0xFF4A90D9);
  static const Color accentColor = Color(0xFF67B26F);
  static const Color warnColor = Color(0xFFE8855A);
  static const Color dangerColor = Color(0xFFD94A4A);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF5F6FA),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF2D3436),
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D3436),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(120, 52),
        textStyle: const TextStyle(
          fontSize: fontSizeButton,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(120, 52),
        textStyle: const TextStyle(
          fontSize: fontSizeButton,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF0F2F5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMedium,
        vertical: spacingMedium,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: const TextStyle(fontSize: fontSizeLabel),
      hintStyle: TextStyle(
        fontSize: fontSizeLabel,
        color: Colors.grey.shade500,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        fontSize: fontSizeButton,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: fontSizeList),
      bodyMedium: TextStyle(fontSize: fontSizeLabel),
      bodySmall: TextStyle(fontSize: fontSizeSmall),
    ),
    dividerTheme: const DividerThemeData(
      space: 1,
      thickness: 1,
      color: Color(0xFFEEEEEE),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF1A1D23),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Color(0xFF252830),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF252830),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(120, 52),
        textStyle: const TextStyle(
          fontSize: fontSizeButton,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(120, 52),
        textStyle: const TextStyle(
          fontSize: fontSizeButton,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2E3138),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMedium,
        vertical: spacingMedium,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: const TextStyle(fontSize: fontSizeLabel),
      hintStyle: TextStyle(
        fontSize: fontSizeLabel,
        color: Colors.grey.shade600,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: fontSizeTitle,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        fontSize: fontSizeButton,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: fontSizeList),
      bodyMedium: TextStyle(fontSize: fontSizeLabel),
      bodySmall: TextStyle(fontSize: fontSizeSmall),
    ),
    dividerTheme: const DividerThemeData(
      space: 1,
      thickness: 1,
      color: Color(0xFF3A3D44),
    ),
  );
}
