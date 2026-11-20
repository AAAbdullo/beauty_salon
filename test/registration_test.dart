import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/widgets/buttons/app_gradient_button.dart';
import 'package:beauty_salons/main.dart';

/// Регистрация клиента по SMS: код проверяет «сервер», новый клиент получает пустой профиль.
void main() {
  setUpAll(loadTestFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppClock.current = FixedClock(DateTime(2026, 11, 11, 10));
    AppStateService().resetSession();
  });

  tearDown(() {
    AppClock.reset();
    AppStateService().resetSession();
  });

  testWidgets('телефон → неверный код отклоняется → верный код → анкета → главная с пустым профилем', (tester) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      GozallikApp(
        dependencies: AppDependencies.mock(network: MockNetwork()),
        themeOverride: ThemeData(fontFamily: 'Roboto'),
      ),
    );
    await settle(tester);

    await tester.tap(find.textContaining('Зарегистрироваться', findRichText: true));
    await settle(tester);
    await tester.tap(find.widgetWithText(AppGradientButton, 'Получить код'));
    await settle(tester, frames: 12);
    expect(find.text('Код подтверждения'), findsOneWidget);
    expect(find.textContaining('код из SMS — 1234'), findsOneWidget, reason: 'в моке код показан тестировщику');

    // Любые четыре цифры больше не подходят: код проверяет сервер
    await tester.enterText(find.byType(TextField).first, '0000');
    await settle(tester, frames: 12);
    expect(find.text('Неверный код. Осталось попыток: 4.'), findsOneWidget);
    expect(find.text('Код подтверждения'), findsOneWidget, reason: 'на анкету не пустили');

    await tester.enterText(find.byType(TextField).first, '1234');
    await settle(tester, frames: 12);
    expect(find.text('Завершить регистрацию'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(AppGradientButton, 'Завершить регистрацию'));
    await tester.tap(find.widgetWithText(AppGradientButton, 'Завершить регистрацию'));
    await settle(tester, frames: 14);

    final state = AppStateService();
    expect(state.clientName, 'Азиза Каримова');
    expect(state.clientCredits, 0, reason: 'новый клиент не наследует 86 кредитов демо-клиента');
    expect(state.bookings, isEmpty);
    expect(find.text('Главная'), findsWidgets);
    await disposeTree(tester);
  });
}
