import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beauty_salons/core/l10n/app_locale.dart';
import 'package:beauty_salons/core/services/app_preferences.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/theme/app_appearance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('сохранённые язык и тема восстанавливаются, изменения сохраняются', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark', 'language': 'uzCyrl'});
    await AppPreferences.restoreAndWatch();
    expect(AppAppearance.instance.mode, ThemeMode.dark);
    expect(AppLocale.instance.language, AppLanguage.uzCyrl);

    AppLocale.instance.setLanguage(AppLanguage.uz);
    AppAppearance.instance.setMode(ThemeMode.system);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('language'), 'uz');
    expect(prefs.getString('theme_mode'), 'system');

    AppLocale.instance.setLanguage(AppLanguage.ru);
    AppAppearance.instance.setMode(ThemeMode.light);
  });

  group('настройки приложения', () {
    final state = AppStateService();

    setUp(() => state.resetSession());

    tearDown(() {
      state.updateSettings(promo: true, news: true, location: true);
      state.resetSession();
    });

    test('геолокация и рассылки восстанавливаются после перезапуска', () async {
      SharedPreferences.setMockInitialValues({
        'use_location': false,
        'promo_notifications': false,
      });
      await AppPreferences.restoreAndWatch(settingsState: state);
      expect(state.useLocationEnabled, isFalse);
      expect(state.promoNotificationsEnabled, isFalse);
      expect(state.newsNotificationsEnabled, isTrue, reason: 'не сохранялась — остаётся значение по умолчанию');
    });

    test('изменение настроек сразу сохраняется', () async {
      SharedPreferences.setMockInitialValues({});
      await AppPreferences.restoreAndWatch(settingsState: state);
      state.updateSettings(location: false, news: false);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('use_location'), isFalse);
      expect(prefs.getBool('news_notifications'), isFalse);
    });

    test('выход из аккаунта: отказ от геолокации (настройка устройства) остаётся, рассылки возвращаются к умолчанию', () async {
      SharedPreferences.setMockInitialValues({});
      await AppPreferences.restoreAndWatch(settingsState: state);
      state.updateSettings(location: false, promo: false);
      state.resetSession();
      expect(state.useLocationEnabled, isFalse);
      expect(state.promoNotificationsEnabled, isTrue);
    });
  });
}
