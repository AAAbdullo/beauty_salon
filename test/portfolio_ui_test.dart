import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/masters_repository.dart';
import 'package:beauty_salons/core/services/portfolio_store.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/utils/formatters.dart';
import 'package:beauty_salons/features/booking/booking_screen.dart';
import 'package:beauty_salons/main.dart';

/// Портфолио в приложении клиента: превью на странице салона, вкладка мастера с фильтрами, просмотр фото
/// с услугой, ценой и кнопкой записи.
void main() {
  setUpAll(loadTestFonts);

  late AppStateService state;

  setUp(() {
    AppClock.current = FixedClock(DateTime(2026, 11, 11, 10));
    state = AppStateService()..resetSession();
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  Future<void> pumpClient(WidgetTester tester) async {
    useBigPhone(tester);
    // Высокий экран: карточки мастеров с миниатюрами работ помещаются целиком, без прокрутки
    tester.view.physicalSize = const Size(390, 1600) * 3;
    await tester.pumpWidget(
      GozallikApp(
        dependencies: AppDependencies.mock(network: MockNetwork()),
        themeOverride: ThemeData(fontFamily: 'Roboto'),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'client');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('Войти').first);
    await settle(tester, frames: 12);
  }

  /// Главная → Nur Beauty → «Мастера»
  Future<void> openSalonMasters(WidgetTester tester) async {
    await tester.tap(find.text('Nur Beauty').first);
    await settle(tester, frames: 12);
    await tester.tap(find.text('Мастера').first);
    await settle(tester);
  }

  /// … → мастер → вкладка «Портфолио»
  Future<void> openPortfolio(WidgetTester tester, String masterName) async {
    await openSalonMasters(tester);
    await tester.tap(find.text(masterName));
    await settle(tester, frames: 12);
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Портфолио')));
    await settle(tester);
  }

  final chipList = find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal);

  Finder thumbnails() => find.byWidgetPredicate((w) => w is Image && w.width == 56 && w.height == 56);

  testWidgets('страница салона: у мастера до 3 миниатюр работ', (tester) async {
    await pumpClient(tester);
    await openSalonMasters(tester);
    // Alena — 3 работы, Sabina — 2, Madina — 1
    expect(thumbnails(), findsNWidgets(6));
    await disposeTree(tester);
  });

  testWidgets('страница салона: если у мастера есть закреплённые работы, в превью только они', (tester) async {
    await pumpClient(tester);
    expect(state.portfolio.update('m-001', 'w-m-001-2', pinned: true).isSuccess, isTrue);
    await openSalonMasters(tester);
    expect(thumbnails(), findsNWidgets(4)); // Alena — одна закреплённая, остальные 2 + 1
    await disposeTree(tester);
  });

  testWidgets('вкладка «Портфолио»: чипы-фильтры по услугам из работ', (tester) async {
    await pumpClient(tester);
    expect(state.portfolio.update('m-001', 'w-m-001-2', serviceId: 'm-001-s4').isSuccess, isTrue);
    await openPortfolio(tester, 'Алена Смирнова');

    expect(find.text('Все'), findsOneWidget);
    // название услуги: чип + подпись на двух работах с этой услугой
    expect(find.text('Комбинированный маникюр + гель-лак'), findsNWidgets(3));
    expect(find.text('Френч / Кастомный дизайн ногтей'), findsNWidgets(2)); // чип + подпись на одной работе

    // чипы идут в горизонтальном списке: третий за краем экрана
    await tester.drag(chipList, const Offset(-300, 0));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Френч / Кастомный дизайн ногтей'));
    await settle(tester);
    expect(find.text('Комбинированный маникюр + гель-лак'), findsOneWidget); // остался только чип

    await tester.drag(chipList, const Offset(300, 0));
    await settle(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Все'));
    await settle(tester);
    expect(find.text('Комбинированный маникюр + гель-лак'), findsNWidgets(3));
    await disposeTree(tester);
  });

  testWidgets('просмотр работы: услуга, цена и «Записаться на эту услугу» открывает запись с этой услугой', (tester) async {
    await pumpClient(tester);
    await openPortfolio(tester, 'Мадина Умарова');
    await tester.tap(find.byType(Image).last);
    await settle(tester);

    expect(find.text('Комбинированная чистка лица'), findsWidgets);
    expect(find.text('45 кр. · ${Formatters.formatSum(200000)}'), findsOneWidget);
    await tester.tap(find.text('Записаться на эту услугу'));
    await settle(tester, frames: 14);

    expect(find.byType(BookingScreen), findsOneWidget);
    expect(find.text('Комбинированная чистка лица'), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('работа без услуги: подпись «Услуга больше не оказывается», кнопки записи нет', (tester) async {
    await pumpClient(tester);
    state.portfolio = PortfolioStore.seed(
      masters: MastersRepository().getMasters(),
      serviceIdsOf: (_) => const {},
    );
    await openPortfolio(tester, 'Мадина Умарова');
    await tester.tap(find.byType(Image).last);
    await settle(tester);

    expect(find.text('Услуга больше не оказывается'), findsOneWidget);
    expect(find.text('Записаться на эту услугу'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('подпись работы видна в просмотре', (tester) async {
    await pumpClient(tester);
    final work = state.portfolio.works('m-004').single;
    expect(state.portfolio.update('m-004', work.id, caption: 'Свежая кожа после чистки').isSuccess, isTrue);
    await openPortfolio(tester, 'Мадина Умарова');
    await tester.tap(find.byType(Image).last);
    await settle(tester);
    expect(find.text('Свежая кожа после чистки'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('пустое портфолио у клиента: «Мастер ещё не добавил работы»', (tester) async {
    await pumpClient(tester);
    state.portfolio = PortfolioStore.seed(masters: const []);
    await openPortfolio(tester, 'Мадина Умарова');
    expect(find.text('Мастер ещё не добавил работы'), findsOneWidget);
    await disposeTree(tester);
  });
}
