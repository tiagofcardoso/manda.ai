import 'package:flutter/material.dart';

class ThemeService {
  // Singleton
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Notifier
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.dark);

  bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;
  ThemeMode get themeMode => themeModeNotifier.value;

  void toggleTheme() {
    themeModeNotifier.value = isDarkMode ? ThemeMode.light : ThemeMode.dark;
  }
}
