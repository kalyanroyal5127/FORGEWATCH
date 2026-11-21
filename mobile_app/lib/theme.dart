import 'package:flutter/material.dart';

abstract final class ForgeColors {
  static const background = Color(0xff080e16);
  static const sidebar = Color(0xff0b131e);
  static const card = Color(0xff111c28);
  static const elevated = Color(0xff152434);
  static const border = Color(0xff26394b);
  static const cyan = Color(0xff45d9ed);
  static const blue = Color(0xff4388ff);
  static const green = Color(0xff4ce0a2);
  static const warning = Color(0xffffba57);
  static const danger = Color(0xffff647e);
  static const muted = Color(0xff91a5b9);
  static const text = Color(0xffe8f1f8);
}

abstract final class ForgeTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: ForgeColors.background,
        colorScheme: const ColorScheme.dark(
          primary: ForgeColors.cyan,
          secondary: ForgeColors.blue,
          surface: ForgeColors.card,
          error: ForgeColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ForgeColors.background,
          foregroundColor: ForgeColors.text,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: ForgeColors.card,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ForgeColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ForgeColors.background,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ForgeColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ForgeColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: ForgeColors.cyan)),
        ),
      );
}
