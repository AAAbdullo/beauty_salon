import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/main.dart';

/// Кабинет мастера: раздел «Отзывы» (сводка, список, ответ) и уведомление о новом отзыве.
/// Мастер демо-кабинета — Sabina (m-002): 92 отзыва, среднее 4,8; визит b-002 клиента подтверждён 9 ноября.
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

  Future<AppDependencies> pumpMaster(WidgetTester tester) async {
    useBigPhone(tester);
    final deps = AppDependencies.mock(network: MockNetwork());
    await tester.pumpWidget(GozallikApp(dependencies: deps, themeOverride: ThemeData(fontFamily: 'Roboto')));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), 'master');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('Войти').first);
    await settle(tester, frames: 12);
    return deps;
  }

  Future<void> openReviews(WidgetTester tester) async {
    await tester.tap(find.text('Профиль').last); // нижняя панель
    await settle(tester);
    await tester.ensureVisible(find.text('Отзывы'));
    await tester.tap(find.text('Отзывы'));
    await settle(tester, frames: 12);
  }

  testWidgets('«Профиль» → «Отзывы»: сводка и отзывы о мастере, «Назад» возвращает в профиль', (tester) async {
    await pumpMaster(tester);
    await openReviews(tester);

    expect(find.text('92 отзыва'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Зарина Т.'), findsOneWidget);
    expect(find.text('Ответить'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await settle(tester);
    expect(find.text('Профиль мастера'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('ответ мастера: контакты отклоняются, затем ответ виден под отзывом и его можно изменить', (tester) async {
    final deps = await pumpMaster(tester);
    await openReviews(tester);

    await tester.tap(find.text('Ответить'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Звоните +998 90 123 45 67');
    await tester.tap(find.text('Отправить'));
    await settle(tester, frames: 12);
    expect(find.text('Уберите из ответа контакты и ссылки.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Спасибо, что выбрали нас!');
    await tester.tap(find.text('Отправить'));
    await settle(tester, frames: 12);
    expect(find.text('Ответ мастера'), findsOneWidget);
    expect(find.text('Спасибо, что выбрали нас!'), findsOneWidget);
    expect(find.text('Изменить ответ'), findsOneWidget);

    // клиенты видят ответ в списке отзывов мастера
    final page = await deps.reviews.masterReviews('m-002');
    expect(page.items.firstWhere((r) => r.reply != null).reply!.text, 'Спасибо, что выбрали нас!');

    await tester.tap(find.text('Изменить ответ'));
    await settle(tester);
    expect(find.text('Спасибо, что выбрали нас!'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'Будем рады видеть вас снова');
    await tester.tap(find.text('Отправить'));
    await settle(tester, frames: 12);
    expect(find.text('Будем рады видеть вас снова'), findsOneWidget);
    expect(find.text('Спасибо, что выбрали нас!'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('новый отзыв приходит мастеру уведомлением «Новый отзыв: 5 ★»', (tester) async {
    final deps = await pumpMaster(tester);
    expect(
      (await deps.reviews.submit(
        bookingId: 'b-002',
        rating: 5,
        tags: const [],
        comment: 'Отлично',
        idempotencyKey: 'n-1',
      )).isSuccess,
      isTrue,
    );
    await settle(tester);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await settle(tester);
    expect(find.text('Новый отзыв: 5 ★'), findsOneWidget);
    expect(find.textContaining('Автор: Wazow'), findsOneWidget);
    await disposeTree(tester);
  });
}
