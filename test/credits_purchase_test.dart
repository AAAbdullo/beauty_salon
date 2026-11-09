import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/data/mock/mock_payments_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_subscription_repository.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/widgets/buttons/app_gradient_button.dart';
import 'package:beauty_salons/main.dart';

/// Покупка пакета кредитов: сначала оплата провайдером, потом выдача пакета по квитанции.
void main() {
  setUpAll(loadTestFonts);

  // В сумме неразрывные пробелы, поэтому ищем по началу текста
  final payButton = find.ancestor(of: find.textContaining('Оплатить'), matching: find.byType(AppGradientButton));

  late AppStateService state;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppClock.current = FixedClock(DateTime(2026, 11, 11, 10));
    state = AppStateService()..resetSession();
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  Future<void> openCredits(WidgetTester tester, AppDependencies deps) async {
    useBigPhone(tester);
    await tester.pumpWidget(GozallikApp(dependencies: deps, themeOverride: ThemeData(fontFamily: 'Roboto')));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'client');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('Войти').first);
    await settle(tester, frames: 12);
    await tester.tap(find.text('Кредиты').last);
    await settle(tester, frames: 12);
  }

  Future<void> startPurchaseOfLite(WidgetTester tester) async {
    expect(find.text('Lite'), findsWidgets, reason: 'пакеты пришли из репозитория');
    await tester.ensureVisible(find.text('Купить').first);
    await tester.tap(find.text('Купить').first);
    await settle(tester, frames: 12);
    expect(find.text('Способ оплаты'), findsOneWidget);
    await tester.tap(find.text('Payme'));
    await settle(tester);
  }

  testWidgets('покупка пакета: оплата выбранным провайдером, затем кредиты начислены', (tester) async {
    final deps = AppDependencies.mock(network: MockNetwork());
    await openCredits(tester, deps);
    final payments = deps.payments as MockPaymentsRepository;
    await startPurchaseOfLite(tester);

    await tester.tap(payButton);
    await settle(tester, frames: 14);

    expect(payments.receipts, hasLength(1), reason: 'без платежа пакет не выдают');
    expect(payments.receipts.single.amount, 249000);
    expect(payments.receipts.single.provider, 'Payme');
    expect(state.subscriptionPlan, 'Lite');
    expect(state.clientCredits, 110); // Premium 250 → перенос не больше 20% = 50, плюс 60
    expect(find.textContaining('Пакет «Lite» активирован'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('связь оборвалась после списания, окно закрыли — деньги возвращаются, кредитов нет', (tester) async {
    final base = AppDependencies.mock(network: MockNetwork());
    final subscriptionNet = MockNetwork();
    final payments = base.payments as MockPaymentsRepository;
    final deps = AppDependencies(
      auth: base.auth,
      catalog: base.catalog,
      slots: base.slots,
      bookings: base.bookings,
      payments: payments,
      subscription: MockSubscriptionRepository(network: subscriptionNet, payments: payments),
      visitQr: base.visitQr,
      masterCabinet: base.masterCabinet,
      appState: base.appState,
    );
    await openCredits(tester, deps);
    await startPurchaseOfLite(tester);

    subscriptionNet.failNext(); // оплата пройдёт, выдача пакета оборвётся
    await tester.tap(payButton);
    await settle(tester, frames: 14);
    expect(payments.receipts, hasLength(1));
    expect(state.clientCredits, 86, reason: 'пакет не выдан');
    expect(find.text('Способ оплаты'), findsOneWidget, reason: 'окно осталось: можно повторить');

    await tester.binding.handlePopRoute(); // закрыли окно, не повторив
    await settle(tester);
    expect(payments.wasRefunded(payments.receipts.single.id), isTrue);
    expect(state.clientCredits, 86);
    await disposeTree(tester);
  });

  testWidgets('повтор после обрыва не платит второй раз', (tester) async {
    final base = AppDependencies.mock(network: MockNetwork());
    final subscriptionNet = MockNetwork();
    final payments = base.payments as MockPaymentsRepository;
    final deps = AppDependencies(
      auth: base.auth,
      catalog: base.catalog,
      slots: base.slots,
      bookings: base.bookings,
      payments: payments,
      subscription: MockSubscriptionRepository(network: subscriptionNet, payments: payments),
      visitQr: base.visitQr,
      masterCabinet: base.masterCabinet,
      appState: base.appState,
    );
    await openCredits(tester, deps);
    await startPurchaseOfLite(tester);

    subscriptionNet.failNext();
    await tester.tap(payButton);
    await settle(tester, frames: 14);
    await tester.tap(payButton);
    await settle(tester, frames: 14);

    expect(payments.receipts, hasLength(1), reason: 'повторное нажатие использует ту же квитанцию');
    expect(state.subscriptionPlan, 'Lite');
    expect(payments.wasRefunded(payments.receipts.single.id), isFalse);
    await disposeTree(tester);
  });
}
