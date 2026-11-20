import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/l10n/app_locale.dart';
import 'package:beauty_salons/core/l10n/uz_strings.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/utils/formatters.dart';
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

    test('экраны мастера: профиль клиента и клиенты месяца есть в словарях', () {
      // Одно слово с заглавной буквы («История») и фразы вида «… записи» не остаются русскими, а попадают
      // в запасную транслитерацию имён или в шаблон «{0} записи» и выглядят как узбекские, но неверны.
      // Поэтому проверяем наличие точных записей в обоих словарях, а не отсутствие русских букв.
      const phrases = [
        'Профиль клиента',
        'Визитов у вас',
        'Предстоящих',
        'Отмен',
        'Предстоящие записи',
        'История',
        'Предстоящих записей нет',
        'Прошлых записей пока нет',
        'Клиент не найден. Возможно, у вас нет записей этого клиента.',
        'Подтверждено',
        'Завершено',
        'Отменено',
        'Клиенты в этом месяце',
        'Нажмите на клиента, чтобы открыть его профиль',
        'В этом месяце ещё нет подтверждённых визитов',
      ];
      expect(phrases.where((p) => !uzExact.containsKey(p)).toList(), isEmpty, reason: 'латиница');
      expect(phrases.where((p) => !uzCyrlExact.containsKey(p)).toList(), isEmpty, reason: 'кириллица');

      // Склонения «визит / визита / визитов» — по шаблонам
      for (final n in [1, 2, 5, 11, 21, 24]) {
        final text = Formatters.plural(n, 'визит', 'визита', 'визитов');
        AppLocale.instance.setLanguage(AppLanguage.uz);
        expect(tr(text), '$n ta tashrif');
        AppLocale.instance.setLanguage(AppLanguage.uzCyrl);
        expect(tr(text), '$n та ташриф');
      }
    });

    test('отмена онлайн-записи: текст окна с точной суммой и подтверждение переведены', () {
      AppLocale.instance.setLanguage(AppLanguage.uz);
      expect(tr('Оплата 22 000 сум вернётся на карту полностью.'), "To'lov 22 000 so'm kartaga to'liq qaytariladi.");
      expect(tr('Запись отменена. Оплата возвращается на карту.'), "Yozuv bekor qilindi. To'lov kartaga qaytarilmoqda.");
      AppLocale.instance.setLanguage(AppLanguage.uzCyrl);
      expect(tr('Оплата 22 000 сум вернётся на карту полностью.'), 'Тўлов 22 000 сўм картага тўлиқ қайтарилади.');
    });

    test('регистрация по SMS: сообщения сервера и подсказка переведены', () {
      AppLocale.instance.setLanguage(AppLanguage.uz);
      expect(tr('Неверный код. Осталось попыток: 4.'), "Noto'g'ri kod. Qolgan urinishlar: 4.");
      expect(tr('Повторно отправить код можно через 30 с.'), 'Kodni qayta yuborish 30 soniyadan keyin mumkin.');
      expect(tr('Слишком много попыток. Запросите новый код.'), "Juda ko'p urinish. Yangi kod so'rang.");
      expect(tr('Демо-режим: код из SMS — 1234'), 'Demo rejim: SMS dagi kod — 1234');
      AppLocale.instance.setLanguage(AppLanguage.uzCyrl);
      expect(tr('Неверный код. Осталось попыток: 4.'), 'Нотўғри код. Қолган уринишлар: 4.');
    });

    test('покупка пакета: сообщения сервера переведены, склейка с «Платёж будет возвращён.» работает', () {
      AppLocale.instance.setLanguage(AppLanguage.uz);
      expect(
        tr('Платёж не найден или не совпадает с ценой пакета. Платёж будет возвращён.'),
        "To'lov topilmadi yoki paket narxiga mos kelmaydi. To'lov qaytariladi.",
      );
      expect(isFullyTranslated('Не удалось загрузить пакеты'), isTrue);
      // Цена за кредит считается по модели и форматируется с неразрывным пробелом — переводится шаблоном
      expect(tr('${Formatters.formatSum(4150)}/кр.'), contains("so'm/kr."));
    });

    test('после возврата на русский тексты не переводятся', () {
      AppLocale.instance.setLanguage(AppLanguage.uz);
      expect(tr('Главная'), 'Bosh sahifa');
      AppLocale.instance.setLanguage(AppLanguage.ru);
      expect(tr('Главная'), 'Главная');
    });
  });

  group('Узбекская кириллица', () {
    setUp(() => AppLocale.instance.setLanguage(AppLanguage.uzCyrl));

    test('фразы, шаблоны, бренды и имена', () {
      expect(tr('Главная'), 'Бош саҳифа');
      expect(tr('Салоны (10)'), 'Салонлар (10)');
      expect(
        tr('• Платежи обрабатывают Click, Payme и Uzum — данные карт приложение не хранит.'),
        contains('Click, Payme ва Uzum'),
      );
      expect(tr('Алена'), 'Алена'); // имена остаются как есть
      expect(tr('12 ноября 2026'), '12 ноябр 2026');
      expect(tr('126 отзывов'), '126 та шарҳ');
    });

    testWidgets('экраны входа и главной — без русских слов', (tester) async {
      useBigPhone(tester);
      await tester.pumpWidget(
        GozallikApp(
          dependencies: AppDependencies.mock(network: MockNetwork()),
          themeOverride: ThemeData(fontFamily: 'Roboto'),
        ),
      );
      await settle(tester);
      expect(find.text('Кириш'), findsWidgets);
      expect(find.text('Войти'), findsNothing);

      await tester.enterText(find.byType(TextField).at(0), 'client');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.tap(find.text('Кириш').first);
      await settle(tester, frames: 12);
      final russianOnly = RegExp(r'[ыщь]');
      final left = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((t) => russianOnly.hasMatch(t) && t != 'Русский')
          .toSet();
      expect(left, isEmpty);
      await disposeTree(tester);
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

    testWidgets('мастер: клиенты месяца и профиль клиента — без русских надписей', (tester) async {
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

      await tester.ensureVisible(find.byIcon(Icons.people_outline));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.people_outline));
      await settle(tester, frames: 12);
      expect(find.byType(ListTile), findsWidgets, reason: 'в моке у мастера есть клиенты месяца');
      expect(russianLeft(tester), isEmpty, reason: 'окно «клиенты в этом месяце»');

      await tester.tap(find.byType(ListTile).first);
      await settle(tester, frames: 12);
      expect(russianLeft(tester), isEmpty, reason: 'профиль клиента');
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
