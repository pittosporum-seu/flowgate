import 'package:flutter/material.dart';

/// FlowGate 主题系统 - Material Design 3 暗色主题
class FlowGateTheme {
  static const _primaryColor = Color(0xFF3F51B5);
  static const _primaryDark = Color(0xFF1A237E);
  static const _surfaceDark = Color(0xFF121218);
  static const _cardDark = Color(0xFF1E1E2A);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: _primaryColor,
        primaryContainer: _primaryDark,
        secondary: const Color(0xFF7C4DFF),
        surface: _surfaceDark,
        surfaceContainerHighest: _cardDark,
        error: const Color(0xFFCF6679),
      ),
      scaffoldBackgroundColor: _surfaceDark,
      cardTheme: const CardTheme(
        color: _cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surfaceDark,
        indicatorColor: _primaryColor.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _surfaceDark,
        elevation: 0,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: _primaryColor,
        primaryContainer: _primaryDark,
        secondary: const Color(0xFF7C4DFF),
      ),
    );
  }
}
