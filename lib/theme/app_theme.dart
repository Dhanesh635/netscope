import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF070B2B),

    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00BFFF),
      onPrimary: Colors.black,
      secondary: Color(0xFF00D9FF),
      surface: Color(0xFF131B47),
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF131B47),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0A0E2F),
        foregroundColor: const Color(0xFF00BFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF05081C),
      indicatorColor: const Color(0xFF00BFFF),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: Colors.white, fontSize: 12);
        }
        return const TextStyle(color: Colors.grey, fontSize: 12);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.black);
        }
        return const IconThemeData(color: Colors.grey);
      }),
    ),
  );
}
