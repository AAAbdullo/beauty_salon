import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_locale.dart';
import '../theme/app_appearance.dart';

/// Сохраняет выбранные язык и тему между запусками приложения.
class AppPreferences {
  static const _themeKey = 'theme_mode';
  static const _languageKey = 'language';

  /// Читает сохранённые значения и дальше сохраняет каждое изменение. Ошибки хранилища не мешают запуску.
  static Future<void> restoreAndWatch() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final mode = ThemeMode.values.asNameMap()[prefs.getString(_themeKey)];
      if (mode != null) AppAppearance.instance.setMode(mode);
      final language = AppLanguage.values.asNameMap()[prefs.getString(_languageKey)];
      if (language != null) AppLocale.instance.setLanguage(language);
    } catch (_) {
      return; // хранилище недоступно — работаем с настройками по умолчанию
    }

    final store = prefs;
    AppAppearance.instance.addListener(() => _save(store, _themeKey, AppAppearance.instance.mode.name));
    AppLocale.instance.addListener(() => _save(store, _languageKey, AppLocale.instance.language.name));
  }

  static void _save(SharedPreferences prefs, String key, String value) {
    prefs.setString(key, value).catchError((_) => false);
  }
}
