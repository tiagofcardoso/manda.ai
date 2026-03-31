import 'package:flutter/material.dart';

class AdminTheme {
  static const primaryColor = Color(0xFF2697FF);
  static const secondaryColor = Color(0xFF2A2D3E);
  static const bgColor = Color(0xFF212332);

  static const defaultPadding = 16.0;
  
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgColor,
      canvasColor: secondaryColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        surface: secondaryColor,
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'Inter', // Or Outfit depending on style
      ),
      cardColor: secondaryColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
      ),
    );
  }
}
