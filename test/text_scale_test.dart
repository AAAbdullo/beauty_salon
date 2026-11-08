import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/main.dart';

/// Крупный системный шрифт: масштаб ограничен до [maxTextScale], а основные экраны при нём не переполняются.
/// Время: среда 11 ноября 2026, 10:00.
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

  Future<void> pumpApp(WidgetTester tester, {required double scale, required String login}) async {
    useBigPhone(tester);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
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

  Future<void> visit(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab).last);
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'переполнение на вкладке «$tab»');
  }

  testWidgets('масштаб текста ограничен: запрошенные 2,0 дают не больше $maxTextScale', (tester) async {
    await pumpApp(tester, scale: 2.0, login: 'client');
    final context = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.textScalerOf(context).scale(10), closeTo(10 * maxTextScale, 0.001));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('клиент, крупный шрифт (2,0): вкладки без переполнений', (tester) async {
    await pumpApp(tester, scale: 2.0, login: 'client');
    expect(tester.takeException(), isNull);
    for (final tab in ['Записи', 'Кредиты', 'Профиль', 'Главная']) {
      await visit(tester, tab);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('мастер, крупный шрифт (2,0): вкладки без переполнений', (tester) async {
    await pumpApp(tester, scale: 2.0, login: 'master');
    expect(tester.takeException(), isNull);
    for (final tab in ['Время', 'Доход', 'Профиль', 'Сегодня']) {
      await visit(tester, tab);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
