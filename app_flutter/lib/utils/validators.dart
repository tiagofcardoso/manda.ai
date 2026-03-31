import 'package:flutter/material.dart';
import '../services/app_translations.dart';

class Validators {
  static String? validatePassword(String? value, BuildContext context) {
    if (value == null || value.isEmpty) {
      return AppTranslations.of(context, 'passwordRequired') == 'passwordRequired' 
          ? 'A senha é obrigatória' 
          : AppTranslations.of(context, 'passwordRequired');
    }
    if (value.length < 8) {
      return AppTranslations.of(context, 'passwordMinLength') == 'passwordMinLength'
          ? 'Mínimo de 8 caracteres'
          : AppTranslations.of(context, 'passwordMinLength');
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return AppTranslations.of(context, 'passwordUppercase') == 'passwordUppercase'
          ? 'Pelo menos uma letra maiúscula'
          : AppTranslations.of(context, 'passwordUppercase');
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return AppTranslations.of(context, 'passwordLowercase') == 'passwordLowercase'
          ? 'Pelo menos uma letra minúscula'
          : AppTranslations.of(context, 'passwordLowercase');
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return AppTranslations.of(context, 'passwordNumber') == 'passwordNumber'
          ? 'Pelo menos um número'
          : AppTranslations.of(context, 'passwordNumber');
    }
    if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>~]'))) {
      return AppTranslations.of(context, 'passwordSpecial') == 'passwordSpecial'
          ? 'Pelo menos um caractere especial (!@#\$...)'
          : AppTranslations.of(context, 'passwordSpecial');
    }
    return null;
  }
}
