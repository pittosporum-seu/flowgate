import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// FlowGate 主题系统 - 现代简约亮色主题
class FlowGateTheme {
  // 品牌色
  static const primary = Color(0xFF4F6BFF);
  static const primarySoft = Color(0xFFE6EAFF);
  static const secondary = Color(0xFF7C5CFF);
  static const success = Color(0xFF31B7A7);
  static const successSoft = Color(0xFFDDF8F3);
  static const warning = Color(0xFFB56A00);
  static const danger = Color(0xFFD84A5F);

  // 中性色
  static const bg = Color(0xFFF4F7FB);
  static const surface = Color(0xFFFDFEFF);
  static const surfaceAlt = Color(0xFFEEF3FA);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF5F6878);
  static const textTertiary = Color(0xFF8792A4);
  static const line = Color(0xFFDDE4EE);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primarySoft,
        onPrimaryContainer: Color(0xFF13205F),
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFEEE8FF),
        tertiary: success,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceAlt,
        onSurfaceVariant: textSecondary,
        error: danger,
        outline: Color(0xFF8F99AA),
        outlineVariant: line,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // 亮色主题用深色状态栏图标，避免白字看不见
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: line, width: 0.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 64,
        indicatorColor: primarySoft,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(color: textTertiary, size: 24);
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: primarySoft,
        selectedIconTheme: const IconThemeData(color: primary),
        unselectedIconTheme: const IconThemeData(color: textTertiary),
        selectedLabelTextStyle: const TextStyle(
          color: primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: textTertiary,
          fontSize: 12,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: const TextStyle(color: textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
