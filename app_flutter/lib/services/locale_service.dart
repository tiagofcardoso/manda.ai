import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal();

  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier(const Locale('en'));

  /// Initialize: Load saved language or check location
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language_code');

    if (savedLanguage != null) {
      debugPrint('Loaded saved language: $savedLanguage');
      localeNotifier.value = Locale(savedLanguage);
    } else {
      debugPrint('No saved language, checking location...');
      await initLocationBasedLanguage();
    }
  }

  Future<void> initLocationBasedLanguage() async {
    try {
      // 1. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return; // Permissions are denied
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return; // Permissions are denied forever
      }

      // 2. Get Current Position
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10)));

      // 3. Get Placemark (Country)
      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final countryCode = placemarks.first.isoCountryCode?.toUpperCase();
        debugPrint('Detected Country: $countryCode');

        // List of Lusophone (Portuguese-speaking) countries
        const portugueseSpeakingCountries = [
          'PT',
          'BR',
          'AO',
          'MZ',
          'CV',
          'GW',
          'ST',
          'TL'
        ];

        if (countryCode != null &&
            portugueseSpeakingCountries.contains(countryCode)) {
          setLocale(const Locale('pt'));
        } else {
          setLocale(const Locale('en'));
        }
      }
    } catch (e) {
      debugPrint('Error getting location for language: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (localeNotifier.value != locale) {
      localeNotifier.value = locale;
      // Persist choice
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', locale.languageCode);
      debugPrint('Saved language: ${locale.languageCode}');
    }
  }

  Future<void> toggleLocale() async {
    final newLocale = localeNotifier.value.languageCode == 'en'
        ? const Locale('pt')
        : const Locale('en');
    await setLocale(newLocale);
  }
}
