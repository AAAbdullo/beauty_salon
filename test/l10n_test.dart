import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/l10n/app_locale.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/widgets/buttons/app_gradient_button.dart';
import 'package:beauty_salons/main.dart';

/// Узбекский язык: словарь, шаблоны и отсутствие русского текста на основных экранах.
void main() {
  setUpAll(loadTestFonts);

  setUp(() => AppClock.current = FixedClock(DateTime(2026, 11, 11, 10)));

  tearDown(() {
    AppLocale.instance.setLanguage(AppLanguage.ru);
    AppClock.reset();
    AppStateService().resetSession();
  });

  group('tr()', () {
    test('русский остаётся как есть', () {
      expect(tr('Главная'), 'Главная');
    });

    test('точные фразы, шаблоны и составные тексты', () {
      AppLocale.instance.setLanguage(AppLanguage.uz);
      expect(tr('Главная'), 'Bosh sahifa');
      expect(tr('Салоны (10)'), 'Salonlar (10)');
      expect(tr('34 кр.'), '34 kr.');
      expect(tr('1 240 000 сум'), "1 240 000 so'm");
      expect(tr('3 мин'), isNot('3 мин')); // не падает на неизвестном
      expect(tr('Маникюр · Педикюр · Брови'), 'Manikyur · Pedikyur · Qosh');
      expect(tr('126 отзывов'), '126 ta sharh');
      expect(tr('Сегодня, 12 ноя'), startsWith('Bugun'));
      expect(tr('12 ноября 2026'), '12 noyabr 2026');
      expect(tr('Неизвестная русская фраза'), 'Неизвестная русская фраза');
    });

    test('после возврата на русский тексты не переводятся', () {
      AppLocale.instance.setLanguage(AppLanguage.uz);
      expect(tr('Главная'), 'Bosh sahifa');
      AppLocale.instance.setLanguage(AppLanguage.ru);
      expect(tr('Главная'), 'Главная');
    });
  });

  group('Экраны на узбекском', () {
    final cyrillic = RegExp(r'[А-Яа-яЁё]');
    // названия языков и служебные поля остаются на своём языке
    const allowed = {'Русский', 'Ўзбекча (кирилл)'};

    List<String> russianLeft(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .where((t) => cyrillic.hasMatch(t) && !allowed.contains(t))
        .toSet()
        .toList();

    testWidgets('вход, главная, записи, кредиты, профиль, настройки — без русских надписей', (tester) async {
      useBigPhone(tester);
      AppLocale.instance.setLanguage(AppLanguage.uz);
      await tester.pumpWidget(
        GozallikApp(
          dependencies: AppDependencies.mock(network: MockNetwork()),
          themeOverride: ThemeData(fontFamily: 'Roboto'),
        ),
      );
      await settle(tester);
      expect(russianLeft(tester), isEmpty, reason: 'экран входа');

      await tester.enterText(find.byType(TextField).at(0), 'client');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.tap(find.text('Kirish').first);
      await settle(tester, frames: 12);
      expect(russianLeft(tester), isEmpty, reason: 'главная');

      for (final tab in ['Yozuvlar', 'Kreditlar', 'Profil']) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
        expect(russianLeft(tester), isEmpty, reason: tab);
      }
      await disposeTree(tester);
    });

    testWidgets('кабинет мастера — без русских надписей', (tester) async {
      useBigPhone(tester);
      AppLocale.instance.setLanguage(AppLanguage.uz);
      await tester.pumpWidget(
        GozallikApp(
          dependencies: AppDependencies.mock(network: MockNetwork()),
          themeOverride: ThemeData(fontFamily: 'Roboto'),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'master');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.tap(find.text('Kirish').first);
      await settle(tester, frames: 12);
      expect(russianLeft(tester), isEmpty, reason: 'сегодня');

      for (final tab in ['Vaqt', 'Daromad', 'Profil']) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
        expect(russianLeft(tester), isEmpty, reason: tab);
      }
      await disposeTree(tester);
    });

    testWidgets('салон, запись, оплата, настройки, фильтры — без русских надписей', (tester) async {
      useBigPhone(tester);
      AppLocale.instance.setLanguage(AppLanguage.uz);
      await tester.pumpWidget(
        GozallikApp(
          dependencies: AppDependencies.mock(network: MockNetwork()),
          themeOverride: ThemeData(fontFamily: 'Roboto'),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'client');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.tap(find.text('Kirish').first);
      await settle(tester, frames: 12);

      await tester.tap(find.text('Nur Beauty').first);
      await settle(tester, frames: 12);
      expect(russianLeft(tester), isEmpty, reason: 'салон');

      await tester.tap(find.widgetWithText(AppGradientButton, 'Yozilish'));
      await settle(tester, frames: 14);
      expect(russianLeft(tester), isEmpty, reason: 'запись');

      await tester.ensureVisible(find.text('14:00'));
      await tester.tap(find.text('14:00'));
      await settle(tester, frames: 12);
      await tester.ensureVisible(find.text('Onlayn'));
      await tester.tap(find.text('Onlayn'));
      await settle(tester);
      expect(russianLeft(tester), isEmpty, reason: 'запись, слот выбран');

      final pay = find.textContaining("To'lovga");
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await settle(tester, frames: 12);
      expect(russianLeft(tester), isEmpty, reason: 'оплата');
      await disposeTree(tester);
    });

    testWidgets('профиль → настройки, фильтры главной — без русских надписей', (tester) async {
      useBigPhone(tester);
      AppLocale.instance.setLanguage(AppLanguage.uz);
      await tester.pumpWidget(
        GozallikApp(
          dependencies: AppDependencies.mock(network: MockNetwork()),
          themeOverride: ThemeData(fontFamily: 'Roboto'),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextField).at(0), 'client');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.tap(find.text('Kirish').first);
      await settle(tester, frames: 12);

      await tester.tap(find.byIcon(Icons.tune).first);
      await settle(tester, frames: 12);
      expect(russianLeft(tester), isEmpty, reason: 'фильтры');
      await tester.binding.handlePopRoute();
      await settle(tester);

      await tester.tap(find.text('Profil').last);
      await settle(tester);
      await tester.tap(find.text('Sozlamalar').first);
      await settle(tester, frames: 12);
      expect(russianLeft(tester), isEmpty, reason: 'настройки');
      await disposeTree(tester);
    });

    testWidgets('переключение языка на лету перестраивает открытый экран', (tester) async {
      useBigPhone(tester);
      await tester.pumpWidget(
        GozallikApp(
          dependencies: AppDependencies.mock(network: MockNetwork()),
          themeOverride: ThemeData(fontFamily: 'Roboto'),
        ),
      );
      await settle(tester);
      expect(find.text('Войти'), findsWidgets);

      AppLocale.instance.setLanguage(AppLanguage.uz);
      await settle(tester);
      expect(find.text('Войти'), findsNothing);
      expect(find.text('Kirish'), findsWidgets);

      AppLocale.instance.setLanguage(AppLanguage.ru);
      await settle(tester);
      expect(find.text('Войти'), findsWidgets);
      await disposeTree(tester);
    });
  });
}
