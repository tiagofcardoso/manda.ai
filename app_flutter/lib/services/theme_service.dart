import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ThemeService {
  // Singleton
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Notifier - only for mobile apps
  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.light);

  bool get isDarkMode => themeModeNotifier.value == ThemeMode.dark;
  ThemeMode get themeMode => themeModeNotifier.value;

  /// Get the effective theme mode based on platform
  /// Web (admin panels): Always light mode
  /// Mobile: User-controlled via toggle
  ThemeMode getEffectiveThemeMode() {
    // If running on web, always use light mode (for admin panels)
    if (kIsWeb) {
      return ThemeMode.light;
    }

    // If running on mobile, respect user preference
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return themeModeNotifier.value;
      }
    } catch (_) {
      // Platform not available (e.g., on web), default to light
    }

    // Default to light for any other platform
    return ThemeMode.light;
  }

  /// Toggle theme (only works on mobile)
  void toggleTheme() {
    // Only allow toggle on mobile platforms
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          themeModeNotifier.value =
              isDarkMode ? ThemeMode.light : ThemeMode.dark;
        }
      } catch (_) {
        // Platform not available, ignore
      }
    }
  }

  /// Check if theme toggle should be visible
  bool get canToggleTheme {
    if (kIsWeb) return false;

    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }
}
