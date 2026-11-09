import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_locale.dart';
import '../theme/app_appearance.dart';
import 'app_state_service.dart';

/// Сохраняет выбранные язык и тему между запусками приложения.
class AppPreferences {
  static const _themeKey = 'theme_mode';
  static const _languageKey = 'language';
  static const _locationKey = 'use_location';
  static const _promoKey = 'promo_notifications';
  static const _newsKey = 'news_notifications';

  /// Читает сохранённые значения и дальше сохраняет каждое изменение. Ошибки хранилища не мешают запуску.
  ///
  /// [settingsState] — состояние, чьи настройки тоже сохраняются: геолокация (настройка устройства, не сбрасывается
  /// при выходе из аккаунта) и рассылки (настройки аккаунта; при выходе возвращаются к умолчанию, потом придут с сервера).
  static Future<void> restoreAndWatch({AppStateService? settingsState}) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final mode = ThemeMode.values.asNameMap()[prefs.getString(_themeKey)];
      if (mode != null) AppAppearance.instance.setMode(mode);
      final language = AppLanguage.values.asNameMap()[prefs.getString(_languageKey)];
      if (language != null) AppLocale.instance.setLanguage(language);
      settingsState?.updateSettings(
        location: prefs.getBool(_locationKey),
        promo: prefs.getBool(_promoKey),
        news: prefs.getBool(_newsKey),
      );
    } catch (_) {
      return; // хранилище недоступно — работаем с настройками по умолчанию
    }

    final store = prefs;
    AppAppearance.instance.addListener(() => _save(store, _themeKey, AppAppearance.instance.mode.name));
    AppLocale.instance.addListener(() => _save(store, _languageKey, AppLocale.instance.language.name));
    if (settingsState != null) _watchSettings(store, settingsState);
  }

  static void _save(SharedPreferences prefs, String key, String value) {
    prefs.setString(key, value).catchError((_) => false);
  }

  /// Сохраняет только изменившиеся настройки: состояние уведомляет слушателей и по другим поводам (записи, избранное)
  static void _watchSettings(SharedPreferences prefs, AppStateService state) {
    bool? location, promo, news;
    state.addListener(() {
      if (state.useLocationEnabled != location) {
        location = state.useLocationEnabled;
        prefs.setBool(_locationKey, location!).catchError((_) => false);
      }
      if (state.promoNotificationsEnabled != promo) {
        promo = state.promoNotificationsEnabled;
        prefs.setBool(_promoKey, promo!).catchError((_) => false);
      }
      if (state.newsNotificationsEnabled != news) {
        news = state.newsNotificationsEnabled;
        prefs.setBool(_newsKey, news!).catchError((_) => false);
      }
    });
  }
}
