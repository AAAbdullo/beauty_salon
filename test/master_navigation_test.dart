import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/main.dart';

/// Кабинет мастера: профиль клиента из уведомления и списка клиентов месяца, рабочие плитки главной,
/// возврат в «Профиль» из его пунктов и жест «назад» от края экрана (iPhone).
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

  Future<void> pumpMaster(WidgetTester tester) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      GozallikApp(
        dependencies: AppDependencies.mock(network: MockNetwork()),
        themeOverride: ThemeData(fontFamily: 'Roboto'),
      ),
    );
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'master');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('Войти').first);
    await settle(tester, frames: 12);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('уведомление о записи открывает профиль клиента, «Назад» возвращает на главную', (tester) async {
    await pumpMaster(tester);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await settle(tester);
    expect(find.text('Уведомления'), findsOneWidget);

    await tester.tap(find.textContaining('Дилноза Юсупова'));
    await settle(tester);
    expect(find.text('Профиль клиента'), findsWidgets);
    expect(find.text('Дилноза Юсупова'), findsOneWidget);
    expect(find.text('Предстоящие записи'), findsOneWidget);
    expect(find.text('Ламинирование ресниц с ботоксом'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.text('Профиль клиента'), findsNothing);
    expect(find.text('Ближайший клиент'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('плитки главной работают: «Записи завтра» переключает день, «Клиенты» открывают список и профиль', (
    tester,
  ) async {
    await pumpMaster(tester);
    expect(find.text('Сегодняшние записи'), findsOneWidget);

    await tester.tap(find.text('Записи\nзавтра'));
    await settle(tester);
    expect(find.text('Записи на завтра'), findsOneWidget);

    // После нажатия экран прокручен к списку записей: плитки возвращаем в видимую область
    await tester.ensureVisible(find.text('Записи\nсегодня'));
    await tester.tap(find.text('Записи\nсегодня'));
    await settle(tester);
    expect(find.text('Сегодняшние записи'), findsOneWidget);

    await tester.ensureVisible(find.text('Клиенты\nв этом месяце'));
    await tester.tap(find.text('Клиенты\nв этом месяце'));
    await settle(tester);
    expect(find.text('Клиенты в этом месяце'), findsOneWidget);
    await tester.tap(find.text('Сабина М.'));
    await settle(tester);
    expect(find.text('Профиль клиента'), findsWidgets);
    expect(find.text('Сабина М.'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('пункты профиля мастера возвращают «Назад» в профиль, а не на главную', (tester) async {
    await pumpMaster(tester);

    await tester.tap(find.text('Профиль').last);
    await settle(tester);
    await tester.tap(find.text('Рабочий график'));
    await settle(tester);
    expect(find.text('Рабочий график'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await settle(tester);
    expect(find.text('Доход и выплаты'), findsOneWidget); // профиль мастера
    expect(find.text('Ближайший клиент'), findsNothing);

    await tester.tap(find.text('Доход и выплаты'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.text('Сканер визитов'), findsOneWidget); // снова профиль
    await dispose(tester);
  });

  testWidgets('жест «назад» от левого края (iPhone) возвращает из профиля клиента', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpMaster(tester);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await settle(tester);
    await tester.tap(find.textContaining('Камила Ахмедова'));
    await settle(tester);
    expect(find.text('Профиль клиента'), findsWidgets);

    await tester.dragFrom(const Offset(4, 400), const Offset(220, 0));
    await settle(tester);
    expect(find.text('Профиль клиента'), findsNothing);
    expect(find.text('Ближайший клиент'), findsOneWidget);

    // На корневом экране полосы жеста нет: свайп ничего не ломает
    await tester.dragFrom(const Offset(4, 400), const Offset(220, 0));
    await settle(tester);
    expect(find.text('Ближайший клиент'), findsOneWidget);
    await dispose(tester);
    debugDefaultTargetPlatformOverride = null; // переопределение нужно сбросить до конца теста
  });
}
