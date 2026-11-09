import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_bookings_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/data/mock/mock_payments_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_slots_repository.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/widgets/buttons/app_gradient_button.dart';
import 'package:beauty_salons/features/client_qr/client_qr_modal.dart';
import 'package:beauty_salons/main.dart';

/// Навигация (Фаза 4): стек страниц с живыми слоями, «Назад» с оплаты, блокировка «Назад» во время платежа,
/// вкладки с сохранением состояния, защита кнопки, QR-окно. Время: среда 11 ноября 2026, 10:00.
void main() {
  setUpAll(loadTestFonts);

  late FixedClock clock;
  late AppStateService state;

  setUp(() {
    clock = FixedClock(DateTime(2026, 11, 11, 10));
    AppClock.current = clock;
    state = AppStateService()..resetSession();
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  Future<void> pumpApp(
    WidgetTester tester,
    AppDependencies deps, {
    Duration step = const Duration(milliseconds: 50),
  }) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      GozallikApp(
        dependencies: deps,
        themeOverride: ThemeData(fontFamily: 'Roboto'),
      ),
    );
    await settle(tester, step: step);
  }

  Future<void> loginClient(WidgetTester tester, {Duration step = const Duration(milliseconds: 50)}) async {
    await tester.enterText(find.byType(TextField).at(0), 'client');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('Войти').first);
    await settle(tester, frames: 12, step: step);
  }

  /// Главная → салон Nur Beauty → «Записаться» → слот 14:00 (12:00 пересекается с записью клиента b-001) → оплата «Онлайн» → «К оплате»
  Future<void> goToPayment(WidgetTester tester, {Duration step = const Duration(milliseconds: 50)}) async {
    await tester.tap(find.text('Nur Beauty').first);
    await settle(tester, frames: 12, step: step);
    await tester.tap(find.widgetWithText(AppGradientButton, 'Записаться'));
    await settle(tester, frames: 14, step: step);

    await tester.ensureVisible(find.text('14:00'));
    await tester.tap(find.text('14:00'));
    await settle(tester, frames: 12, step: step);

    await tester.ensureVisible(find.text('Онлайн'));
    await tester.tap(find.text('Онлайн'));
    await settle(tester, step: step);

    final pay = find.textContaining('К оплате');
    await tester.ensureVisible(pay);
    await tester.tap(pay);
    await settle(tester, frames: 12, step: step);
  }

  group('Назад и оплата', () {
    testWidgets('назад с оплаты возвращает на экран записи с выбранным временем и закреплённым слотом', (tester) async {
      await pumpApp(tester, AppDependencies.mock(network: MockNetwork()));
      await loginClient(tester);
      await goToPayment(tester);
      expect(find.text('Оплата'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back).last);
      await settle(tester);

      expect(find.text('Оплата'), findsNothing);
      expect(find.text('Выбрано: 14:00'), findsOneWidget); // выбор не потерян
      expect(find.textContaining('Слот закреплён за вами'), findsOneWidget); // удержание живо
      await disposeTree(tester);
    });

    testWidgets('системная «Назад» поднимается по стеку: оплата → запись → салон → главная', (tester) async {
      await pumpApp(tester, AppDependencies.mock(network: MockNetwork()));
      await loginClient(tester);
      await goToPayment(tester);

      await tester.binding.handlePopRoute(); // с оплаты на запись
      await settle(tester);
      expect(find.text('Оплата'), findsNothing);
      expect(find.text('Запись на услугу'), findsOneWidget);

      await tester.binding.handlePopRoute(); // с записи на салон
      await settle(tester);
      expect(find.text('Запись на услугу'), findsNothing);
      expect(find.widgetWithText(AppGradientButton, 'Записаться'), findsOneWidget);

      await tester.binding.handlePopRoute(); // с салона на главную
      await settle(tester);
      expect(find.widgetWithText(AppGradientButton, 'Записаться'), findsNothing);
      expect(find.text('Салоны (9)'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('пока идёт платёж, «Назад» не закрывает оплату; после платежа запись создана', (tester) async {
      const step = Duration(milliseconds: 100);
      final deps = AppDependencies.mock(network: MockNetwork(latency: const Duration(milliseconds: 100)));
      await pumpApp(tester, deps, step: step);
      await loginClient(tester, step: step);
      await goToPayment(tester, step: step);
      expect(find.text('Оплата'), findsOneWidget);
      final before = state.bookings.length;

      final pay = find.ancestor(of: find.textContaining('Оплатить'), matching: find.byType(AppGradientButton));
      await tester.ensureVisible(pay.last);
      await tester.tap(pay.last);
      await tester.pump(const Duration(milliseconds: 20)); // платёж ещё идёт

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Оплата'), findsOneWidget); // экран не закрылся
      expect(find.textContaining('Идёт оплата'), findsOneWidget);

      await settle(tester, frames: 20, step: step);
      expect(state.bookings.length, before + 1); // платёж прошёл — запись создана
      expect(find.text('Мои записи'), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('Оплата прошла, а записи нет', () {
    /// Сеть записи отдельная: её сбой попадает точно на создание записи, а не на оплату
    ({AppDependencies deps, MockNetwork bookingNet}) depsWithFlakyBookings() {
      final base = AppDependencies.mock(network: MockNetwork());
      final bookingNet = MockNetwork();
      final deps = AppDependencies(
        auth: base.auth,
        catalog: base.catalog,
        slots: base.slots,
        bookings: MockBookingsRepository(slots: base.slots as MockSlotsRepository, network: bookingNet),
        payments: base.payments,
        subscription: base.subscription,
        visitQr: base.visitQr,
        masterCabinet: base.masterCabinet,
        appState: base.appState,
      );
      return (deps: deps, bookingNet: bookingNet);
    }

    Future<void> payAndFailToCreate(WidgetTester tester, MockNetwork bookingNet) async {
      await goToPayment(tester);
      bookingNet.failNext(); // оплата пройдёт, а создание записи оборвётся
      final pay = find.ancestor(of: find.textContaining('Оплатить'), matching: find.byType(AppGradientButton));
      await tester.ensureVisible(pay.last);
      await tester.tap(pay.last);
      await settle(tester, frames: 12);
    }

    testWidgets('«Назад» предлагает вернуть платёж, и возврат выполняется', (tester) async {
      final (:deps, :bookingNet) = depsWithFlakyBookings();
      await pumpApp(tester, deps);
      await loginClient(tester);
      final before = state.bookings.length;
      await payAndFailToCreate(tester, bookingNet);

      final payments = deps.payments as MockPaymentsRepository;
      expect(payments.receipts, hasLength(1), reason: 'деньги списаны');
      expect(state.bookings.length, before, reason: 'записи нет');
      expect(find.text('Оплата'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Вернуть платёж'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);

      await tester.tap(find.text('Вернуть платёж'));
      await settle(tester, frames: 12);
      expect(payments.wasRefunded(payments.receipts.single.id), isTrue);
      expect(find.text('Оплата'), findsNothing, reason: 'экран оплаты закрыт');
      expect(state.bookings.length, before);
      await disposeTree(tester);
    });

    testWidgets('«Повторить» создаёт запись по той же квитанции, возврата нет', (tester) async {
      final (:deps, :bookingNet) = depsWithFlakyBookings();
      await pumpApp(tester, deps);
      await loginClient(tester);
      final before = state.bookings.length;
      await payAndFailToCreate(tester, bookingNet);

      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.text('Повторить'));
      await settle(tester, frames: 14);

      final payments = deps.payments as MockPaymentsRepository;
      expect(payments.receipts, hasLength(1), reason: 'повторной оплаты нет');
      expect(payments.wasRefunded(payments.receipts.single.id), isFalse);
      expect(state.bookings.length, before + 1);
      expect(find.text('Мои записи'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('без неудавшейся записи «Назад» с оплаты закрывает экран без вопросов', (tester) async {
      await pumpApp(tester, AppDependencies.mock(network: MockNetwork()));
      await loginClient(tester);
      await goToPayment(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Вернуть платёж'), findsNothing);
      expect(find.text('Оплата'), findsNothing);
      await disposeTree(tester);
    });
  });

  group('Вкладки', () {
    testWidgets('вкладка хранит состояние: фильтр главной не сбрасывается при переходе на другую вкладку', (
      tester,
    ) async {
      await pumpApp(tester, AppDependencies.mock(network: MockNetwork()));
      await loginClient(tester);

      await tester.scrollUntilVisible(find.text('Брови'), -300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Брови'));
      await settle(tester);
      expect(find.text('Салоны (2)'), findsOneWidget);

      await tester.tap(find.text('Профиль').last);
      await settle(tester);
      expect(find.text('Салоны (2)'), findsNothing); // главная скрыта, но не уничтожена

      await tester.tap(find.text('Главная').last);
      await settle(tester);
      expect(find.text('Салоны (2)'), findsOneWidget); // фильтр на месте
      await disposeTree(tester);
    });

    testWidgets('«Назад» на другой вкладке ведёт на первую, а не закрывает приложение', (tester) async {
      await pumpApp(tester, AppDependencies.mock(network: MockNetwork()));
      await loginClient(tester);

      await tester.tap(find.text('Кредиты').last);
      await settle(tester);
      expect(find.text('Кредиты и Абонемент'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Кредиты и Абонемент'), findsNothing);
      expect(find.text('Салоны (9)'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('пункты профиля возвращают «Назад» в профиль, а из нижней панели кнопки «Назад» нет', (tester) async {
      await pumpApp(tester, AppDependencies.mock(network: MockNetwork()));
      await loginClient(tester);

      // Из пункта профиля: есть кнопка «Назад», она ведёт в профиль
      await tester.tap(find.text('Профиль').last);
      await settle(tester);
      await tester.tap(find.text('Кредиты и оплата'));
      await settle(tester);
      expect(find.text('Кредиты и Абонемент'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      expect(find.text('Кредиты и Абонемент'), findsNothing);
      expect(find.text('Ваш тариф'), findsOneWidget);

      // Системная «Назад» с «Мои записи» тоже возвращает в профиль, а не на главную
      await tester.tap(find.text('Мои записи'));
      await settle(tester);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Ваш тариф'), findsOneWidget);

      // Из нижней панели: кнопки «Назад» нет
      await tester.tap(find.text('Кредиты').last);
      await settle(tester);
      expect(find.text('Кредиты и Абонемент'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      await disposeTree(tester);
    });
  });

  group('Кнопка и QR-окно', () {
    testWidgets('AppGradientButton: пока async-обработчик не завершён, повторный тап не запускает его', (tester) async {
      var calls = 0;
      final gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppGradientButton(
              text: 'Отправить',
              onPressed: () {
                calls++;
                return gate.future;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Отправить'));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget); // идёт действие

      await tester.tap(find.byType(AppGradientButton), warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);

      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Отправить'), findsOneWidget);

      await tester.tap(find.text('Отправить'));
      await tester.pump();
      expect(calls, 2); // после завершения кнопка снова работает
    });

    testWidgets('QR-окно закрывается, когда запись отменена', (tester) async {
      useBigPhone(tester);
      await tester.pumpWidget(
        AppScope(
          dependencies: AppDependencies.mock(network: MockNetwork()),
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => ClientQrModal.show(context, booking: state.bookingById('b-005')!),
                  child: const Text('Открыть QR'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Открыть QR'));
      await settle(tester);
      expect(find.text('Ваш QR-код для визита'), findsOneWidget);

      state.cancelBooking('b-005');
      await settle(tester);
      expect(find.text('Ваш QR-код для визита'), findsNothing);
      expect(find.textContaining('QR-код больше не действует'), findsOneWidget);
      await disposeTree(tester);
    });
  });
}
