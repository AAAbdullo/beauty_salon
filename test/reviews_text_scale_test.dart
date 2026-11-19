import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/features/master_cabinet/profile/master_account_screen.dart';
import 'package:beauty_salons/features/master_cabinet/portfolio/master_portfolio_screen.dart';
import 'package:beauty_salons/features/master_cabinet/reviews/master_reviews_screen.dart';
import 'package:beauty_salons/main.dart';

/// Отзывы и портфолио при самом крупном шрифте (2,0): экраны без переполнений.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  setUp(() {
    AppClock.current = FixedClock(DateTime(2026, 11, 11, 10));
    AppStateService().resetSession();
  });

  tearDown(() {
    AppClock.reset();
    AppStateService().resetSession();
  });

  Future<void> pumpApp(WidgetTester tester, String login) async {
    useBigPhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      GozallikApp(
        dependencies: AppDependencies.mock(network: MockNetwork()),
        themeOverride: ThemeData(fontFamily: 'Roboto'),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), login);
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('Войти').first);
    await settle(tester, frames: 12);
  }

  /// Тап по элементу, который может быть за краем экрана при крупном шрифте; переполнение сразу даёт сбой
  Future<void> tapVisible(WidgetTester tester, Finder f, {int frames = 8}) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    await settle(tester, frames: frames);
    expect(tester.takeException(), isNull);
  }

  testWidgets('клиент (2,0): профиль мастера — отзывы и портфолио', (tester) async {
    await pumpApp(tester, 'client');
    tester.view.physicalSize = const Size(390, 2400) * 3; // карточки мастеров целиком, без прокрутки
    await tapVisible(tester, find.text('Nur Beauty').first, frames: 12);
    await tapVisible(tester, find.text('Мастера').first);
    await tapVisible(tester, find.text('Мадина Умарова'), frames: 12);

    await tapVisible(tester, find.descendant(of: find.byType(TabBar), matching: find.text('Отзывы')));
    expect(find.text('Елена П.'), findsOneWidget);
    await tapVisible(tester, find.descendant(of: find.byType(TabBar), matching: find.text('Портфолио')));
    expect(find.text('Все'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('клиент (2,0): окно отзыва с тегами и счётчиком', (tester) async {
    await pumpApp(tester, 'client');
    tester.view.physicalSize = const Size(390, 2400) * 3;
    await tapVisible(tester, find.text('Записи').last);
    await tapVisible(tester, find.textContaining('Прошедшие'));
    await tapVisible(tester, find.text('Оставить отзыв о визите'));
    await tapVisible(tester, find.byIcon(Icons.star_outline_rounded).last);
    expect(find.text('О мастере'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('мастер (2,0): раздел «Отзывы» и лист ответа', (tester) async {
    await pumpApp(tester, 'master');
    await tapVisible(tester, find.text('Профиль').last);
    // при крупном шрифте плитка «Отзывы» ниже экрана и ещё не построена — прокручиваем список
    final accountList = find.descendant(of: find.byType(MasterAccountScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Отзывы'), 300, scrollable: accountList);
    await tester.drag(accountList, const Offset(0, -250)); // выше нижней панели, которая перекрывает край списка
    await settle(tester);
    await tapVisible(tester, find.text('Отзывы'), frames: 12);
    expect(find.byType(MasterReviewsScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ответить'),
      300,
      scrollable: find.descendant(of: find.byType(MasterReviewsScreen), matching: find.byType(Scrollable)).first,
    );
    await tapVisible(tester, find.text('Ответить'));
    expect(find.text('Ответ на отзыв'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('мастер (2,0): «Мои работы» и лист добавления работы', (tester) async {
    await pumpApp(tester, 'master');
    await tapVisible(tester, find.text('Профиль').last);
    final accountList = find.descendant(of: find.byType(MasterAccountScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Мои работы'), 300, scrollable: accountList);
    await tester.drag(accountList, const Offset(0, -250)); // выше нижней панели, которая перекрывает край списка
    await settle(tester);
    await tapVisible(tester, find.text('Мои работы'), frames: 12);
    expect(find.byType(MasterPortfolioScreen), findsOneWidget);
    await tapVisible(tester, find.text('+ Добавить работу'));
    expect(find.text('Выбрать из галереи'), findsOneWidget);
    await disposeTree(tester);
  });
}
