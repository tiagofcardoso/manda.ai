import 'package:flutter/material.dart';

class LocaleService {
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal();

  final ValueNotifier<Locale> localeNotifier =
      ValueNotifier(const Locale('en'));

  void setLocale(Locale locale) {
    if (localeNotifier.value != locale) {
      localeNotifier.value = locale;
    }
  }

  void toggleLocale() {
    if (localeNotifier.value.languageCode == 'en') {
      localeNotifier.value = const Locale('pt');
    } else {
      localeNotifier.value = const Locale('en');
    }
  }
}
