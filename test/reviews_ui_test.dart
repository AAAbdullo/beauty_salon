import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/review_store.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/features/my_bookings/leave_review_modal.dart';
import 'package:beauty_salons/features/my_bookings/my_bookings_screen.dart';
import 'package:beauty_salons/main.dart';

/// Экраны отзывов: рейтинги на открытых вкладках, профиль мастера, модалка отзыва, кабинет мастера.
/// Время: среда 11 ноября 2026, 10:00; визит b-002 (Sabina) — 9 ноября, окно отзыва открыто.
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

  Future<AppDependencies> pumpApp(WidgetTester tester) async {
    useBigPhone(tester);
    final deps = AppDependencies.mock(network: MockNetwork());
    await tester.pumpWidget(GozallikApp(dependencies: deps, themeOverride: ThemeData(fontFamily: 'Roboto')));
    await settle(tester);
    return deps;
  }

  Future<void> loginClient(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'client');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('Войти').first);
    await settle(tester, frames: 12);
  }

  testWidgets('рейтинг салона на главной обновляется сразу после нового отзыва', (tester) async {
    final deps = await pumpApp(tester);
    await loginClient(tester);
    int shown(String rating) => tester.widgetList(find.text(rating)).length;
    // Nur Beauty: 294 отзыва, среднее 4,87 → в карточке «4.9»
    final before49 = shown('4.9'), before48 = shown('4.8');
    expect(before49, greaterThan(0));

    expect(state.completeVisit('b-001').isSuccess, isTrue);
    for (final id in ['b-002', 'b-001']) {
      final result = await deps.reviews.submit(
        bookingId: id,
        rating: 1,
        tags: const ['Опоздание'],
        comment: '',
        idempotencyKey: 'k-$id',
      );
      expect(result.isSuccess, isTrue);
    }
    await settle(tester);

    // 296 отзывов, среднее 4,84 → «4.8»: карточка салона перечитана без перехода между экранами
    expect(shown('4.9'), lessThan(before49));
    expect(shown('4.8'), greaterThan(before48));
    await disposeTree(tester);
  });

  /// Главная → Nur Beauty → «Мастера» → Мадина Умарова → вкладка «Отзывы»
  Future<void> openMadinaReviews(WidgetTester tester) async {
    await tester.tap(find.text('Nur Beauty').first);
    await settle(tester, frames: 12);
    await tester.tap(find.text('Мастера').first);
    await settle(tester);
    await tester.tap(find.text('Мадина Умарова'));
    await settle(tester, frames: 12);
    await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text('Отзывы')));
    await settle(tester);
  }

  testWidgets('профиль мастера: сводка, отзыв с пометкой «Подтверждённый визит», свежие сверху', (tester) async {
    await pumpApp(tester);
    await loginClient(tester);
    await openMadinaReviews(tester);

    expect(find.text('78 отзывов'), findsOneWidget); // счётчик в сводке считает и «старые» отзывы вне списка
    expect(find.text('Елена П.'), findsOneWidget);
    expect(find.text('Подтверждённый визит'), findsWidgets);
    expect(find.textContaining('Кожа после процедуры сияет'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('профиль мастера без отзывов: «Отзывов пока нет»', (tester) async {
    await pumpApp(tester);
    state.reviews = ReviewStore.seed(masters: const [], bookings: const []);
    await loginClient(tester);
    await openMadinaReviews(tester);

    expect(find.text('Отзывов пока нет'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('отзывы мастера подгружаются страницами по 20 по кнопке «Показать ещё»', (tester) async {
    await pumpApp(tester);
    await loginClient(tester);
    final now = AppClock.now();
    for (var i = 0; i < 25; i++) {
      state.reviews.put(
        MasterReview(
          id: 'p-${i.toString().padLeft(2, '0')}',
          bookingId: '',
          masterId: 'm-004',
          salonId: 's-001',
          serviceName: 'Чистка',
          authorName: 'Клиент $i',
          rating: 5,
          comment: 'Комментарий номер $i',
          createdAt: now.subtract(Duration(hours: i)),
        ),
      );
    }
    await openMadinaReviews(tester);

    final list = find.byType(CustomScrollView);
    expect(find.text('Комментарий номер 0'), findsOneWidget);
    expect(find.text('Комментарий номер 24'), findsNothing);
    await tester.dragUntilVisible(find.text('Показать ещё'), list, const Offset(0, -300));
    await tester.tap(find.text('Показать ещё'));
    await settle(tester);
    await tester.dragUntilVisible(find.text('Комментарий номер 24'), list, const Offset(0, -300));
    expect(find.text('Комментарий номер 24'), findsOneWidget);
    expect(find.text('Показать ещё', skipOffstage: false), findsNothing);
    await disposeTree(tester);
  });

  /// «Мои записи» на вкладке «Прошедшие»
  Future<AppDependencies> pumpPastBookings(WidgetTester tester, {AppDependencies? deps}) async {
    useBigPhone(tester);
    final d = deps ?? AppDependencies.mock(network: MockNetwork());
    await tester.pumpWidget(
      AppScope(
        dependencies: d,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: MyBookingsScreen(onBookNew: () {}, initialTab: 1),
        ),
      ),
    );
    await settle(tester);
    return d;
  }

  /// Поиск внутри окна отзыва (за ним на экране карточки записей с такими же звёздами и тегами)
  Finder inModal(Finder f) => find.descendant(of: find.byType(LeaveReviewModal), matching: f);

  ElevatedButton sendButton(WidgetTester tester, String label) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, label));

  testWidgets('модалка отзыва: оценка не выбрана, «Отправить» неактивна; теги — о мастере и о салоне, ничего не выбрано заранее', (
    tester,
  ) async {
    await pumpPastBookings(tester);
    await tester.tap(find.text('Оставить отзыв о визите'));
    await settle(tester);

    expect(find.text('Оцените мастера'), findsOneWidget);
    expect(find.text('Выберите оценку'), findsOneWidget);
    expect(sendButton(tester, 'Отправить отзыв').onPressed, isNull);
    expect(find.text('О мастере'), findsNothing); // теги появляются после выбора оценки

    // 5 звёзд: положительные теги обеих групп
    await tester.tap(inModal(find.byIcon(Icons.star_outline_rounded)).last);
    await settle(tester);
    expect(sendButton(tester, 'Отправить отзыв').onPressed, isNotNull);
    expect(find.text('О мастере'), findsOneWidget);
    expect(find.text('О салоне'), findsOneWidget);
    expect(find.text('Аккуратная работа'), findsOneWidget);
    expect(inModal(find.text('Чистота')), findsOneWidget);
    expect(find.text('Опоздание'), findsNothing);

    // 2 звезды: проблемные теги, выбранные положительные сбрасываются
    await tester.tap(find.text('Аккуратная работа'));
    await tester.tap(inModal(find.byIcon(Icons.star_rounded)).at(1));
    await settle(tester);
    expect(find.text('Опоздание'), findsOneWidget);
    expect(find.text('Аккуратная работа'), findsNothing);
    expect(find.text('Выберите причину или опишите, что не понравилось'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('модалка отзыва: счётчик символов, отправка, затем правка в окне 7 дней', (tester) async {
    final deps = await pumpPastBookings(tester);
    await tester.tap(find.text('Оставить отзыв о визите'));
    await settle(tester);
    await tester.tap(inModal(find.byIcon(Icons.star_outline_rounded)).last);
    await settle(tester);
    await tester.tap(find.text('Пунктуальность'));
    await tester.enterText(find.byType(TextField), 'Очень довольна');
    await settle(tester);
    expect(find.text('14/500'), findsOneWidget);

    await tester.tap(find.text('Отправить отзыв'));
    await settle(tester, frames: 12);
    expect(state.bookingById('b-002')!.reviewRating, 5);
    expect(state.bookingById('b-002')!.reviewTags, ['Пунктуальность']);
    // у b-003 оценка 5 была и раньше, теперь такая же карточка у b-002
    expect(find.text('Ваша оценка: 5.0'), findsNWidgets(2));
    expect(find.text('Оставить отзыв о визите'), findsNothing);

    // правка: оценка и текст подставлены, после сохранения карточка обновилась
    await tester.tap(find.text('Изменить'));
    await settle(tester);
    expect(find.text('Изменить отзыв'), findsOneWidget);
    expect(find.text('Очень довольна'), findsOneWidget);
    await tester.tap(inModal(find.byIcon(Icons.star_rounded)).at(2)); // три звезды
    await settle(tester);
    await tester.tap(find.text('Сохранить'));
    await settle(tester, frames: 12);
    expect(find.text('Ваша оценка: 3.0'), findsOneWidget);
    expect((await deps.reviews.myReviewsAsMaster()).items.where((r) => r.editedAt != null), hasLength(1));

    // окно закрылось: кнопки «Изменить» больше нет
    clock.set(DateTime(2026, 11, 17, 10));
    await tester.pumpWidget(const SizedBox());
    await pumpPastBookings(tester, deps: deps);
    expect(find.text('Ваша оценка: 3.0'), findsOneWidget);
    expect(find.text('Изменить'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('модалка отзыва: сервер не принял отзыв — причина на экране, окно не закрывается', (tester) async {
    await pumpPastBookings(tester);
    await tester.tap(find.text('Оставить отзыв о визите'));
    await settle(tester);
    await tester.tap(inModal(find.byIcon(Icons.star_outline_rounded)).last);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Пишите @master_alena');
    await tester.tap(find.text('Отправить отзыв'));
    await settle(tester, frames: 12);

    expect(find.text('Уберите из отзыва контакты и ссылки.'), findsOneWidget);
    expect(state.bookingById('b-002')!.reviewId, isNull);
    await disposeTree(tester);
  });
}
