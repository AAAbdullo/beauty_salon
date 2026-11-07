import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beauty_salons/core/l10n/app_locale.dart';
import 'package:beauty_salons/core/services/app_preferences.dart';
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
}
