import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_auth_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/data/mock/mock_payments_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_slots_repository.dart';
import 'package:beauty_salons/core/data/repositories/auth_repository.dart';
import 'package:beauty_salons/core/models/booking_draft.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/widgets/buttons/app_gradient_button.dart';
import 'package:beauty_salons/features/auth/auth_screen.dart';
import 'package:beauty_salons/features/booking/booking_screen.dart';
import 'package:beauty_salons/features/booking/payment_screen.dart';
import 'package:beauty_salons/features/profile_settings/profile_sheets.dart';
import 'package:beauty_salons/features/client_home/client_home_screen.dart';
import 'package:beauty_salons/features/salon_detail/salon_detail_screen.dart';
import 'package:beauty_salons/main.dart';

/// Сценарии на экранах (Фаза 3): состояния загрузки и ошибки, удержание слота, защита от двойного
/// нажатия, вход по токену. Время фиксировано: среда 11 ноября 2026, 10:00.
void main() {
  setUpAll(loadTestFonts);

  late FixedClock clock;
  late MockNetwork network;
  late AppDependencies deps;
  late AppStateService state;

  setUp(() {
    clock = FixedClock(DateTime(2026, 11, 11, 10));
    AppClock.current = clock;
    state = AppStateService()..resetSession();
    network = MockNetwork();
    deps = AppDependencies.mock(network: network);
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  void useBigPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Несколько коротких кадров: цепочка загрузок (экран → каталог → слоты) укладывается в них
  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen, {AppDependencies? dependencies}) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      AppScope(
        dependencies: dependencies ?? deps,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: screen,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  group('Загрузка и ошибки', () {
    testWidgets('страница салона: загрузка → данные', (tester) async {
      await pumpScreen(
        tester,
        SalonDetailScreen(
          salonId: 's-001',
          onBack: () {},
          onBook: ({masterId, service}) {},
          onMasterTap: (_) {},
          onShowOnMap: (_) {},
        ),
      );
      expect(find.text('Nur Beauty'), findsWidgets);
      expect(find.text('Повторить'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('сбой сети показывает ошибку, «Повторить» загружает данные', (tester) async {
      network.failNext();
      await pumpScreen(
        tester,
        SalonDetailScreen(
          salonId: 's-001',
          onBack: () {},
          onBook: ({masterId, service}) {},
          onMasterTap: (_) {},
          onShowOnMap: (_) {},
        ),
      );
      expect(find.textContaining('Нет соединения'), findsOneWidget);
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.text('Nur Beauty'), findsNothing);

      await tester.tap(find.text('Повторить'));
      await settle(tester);
      expect(find.text('Повторить'), findsNothing);
      expect(find.text('Nur Beauty'), findsWidgets);
      await disposeTree(tester);
    });

    testWidgets('несуществующий салон: «не найдено», а не чужой салон', (tester) async {
      await pumpScreen(
        tester,
        SalonDetailScreen(
          salonId: 's-unknown',
          onBack: () {},
          onBook: ({masterId, service}) {},
          onMasterTap: (_) {},
          onShowOnMap: (_) {},
        ),
      );
      expect(find.textContaining('Салон не найден'), findsOneWidget);
      expect(find.text('Nur Beauty'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('главная: салоны грузятся, ошибка повторяется, фильтр перезагружает список', (tester) async {
      network.failNext(2); // салоны и мастера
      await pumpScreen(
        tester,
        ClientHomeScreen(
          onOpenMap: () {},
          onSalonTap: (_) {},
          onMasterTap: (_) {},
          onOpenFavorites: () {},
          onOpenNotifications: () {},
          onOpenCredits: () {},
          onOpenProfile: () {},
        ),
      );
      await tester.scrollUntilVisible(find.text('Повторить'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Повторить'), findsOneWidget);

      await tester.tap(find.text('Повторить'));
      await settle(tester);
      expect(find.text('Салоны (10)'), findsOneWidget);

      // Категория «Брови» — другой список салонов
      await tester.scrollUntilVisible(find.text('Брови'), -300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Брови'));
      await settle(tester);
      expect(find.text('Салоны (10)'), findsNothing);
      expect(find.text('Салоны (2)'), findsOneWidget); // «Брови» есть у двух салонов
      await disposeTree(tester);
    });
  });

  group('Экран записи: удержание слота и двойное нажатие', () {
    Future<void> pumpBooking(
      WidgetTester tester, {
      Future<bool> Function(BookingDraft, String)? onConfirm,
      String salonId = 's-001',
    }) => pumpScreen(
      tester,
      BookingScreen(salonId: salonId, onBack: () {}, onConfirm: onConfirm ?? (_, _) async => true),
    );

    testWidgets('выбор слота закрепляет его на 10 минут, смена мастера освобождает', (tester) async {
      final slots = deps.slots as MockSlotsRepository;
      await pumpBooking(tester);
      expect(slots.activeHoldsCount, 0);
      expect(find.text('Выберите время'), findsOneWidget);

      await tester.ensureVisible(find.text('12:00'));
      await tester.tap(find.text('12:00'));
      await settle(tester);

      expect(slots.activeHoldsCount, 1);
      expect(find.textContaining('Слот закреплён за вами'), findsOneWidget);
      expect(find.textContaining('10:00'), findsWidgets); // таймер: 10:00 от серверного срока

      // Выбрали другой слот — прежнее удержание заменилось, а не накопилось
      await tester.ensureVisible(find.text('13:00'));
      await tester.tap(find.text('13:00'));
      await settle(tester);
      expect(slots.activeHoldsCount, 1);
      await disposeTree(tester);
    });

    testWidgets('таймер идёт до серверного срока; по истечении слот сбрасывается', (tester) async {
      await pumpBooking(tester);
      await tester.ensureVisible(find.text('12:00'));
      await tester.tap(find.text('12:00'));
      await settle(tester);
      expect(find.textContaining('Слот закреплён за вами'), findsOneWidget);

      clock.advance(const Duration(minutes: 10, seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('Время брони истекло'), findsOneWidget);
      await tester.tap(find.text('Выбрать время'));
      await settle(tester);
      expect(find.textContaining('Слот закреплён за вами'), findsNothing);
      expect(find.text('Выберите время'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('уход с экрана без записи освобождает удержание', (tester) async {
      final slots = deps.slots as MockSlotsRepository;
      await pumpBooking(tester);
      await tester.ensureVisible(find.text('12:00'));
      await tester.tap(find.text('12:00'));
      await settle(tester);
      expect(slots.activeHoldsCount, 1);

      await disposeTree(tester);
      expect(slots.activeHoldsCount, 0);
    });

    testWidgets('двойной тап «Записаться» вызывает оформление один раз', (tester) async {
      var calls = 0;
      BookingDraft? draft;
      await pumpBooking(
        tester,
        onConfirm: (d, _) async {
          calls++;
          draft = d;
          await Future<void>.delayed(const Duration(milliseconds: 200)); // запись создаётся не мгновенно
          return true;
        },
      );
      await tester.ensureVisible(find.text('12:00'));
      await tester.tap(find.text('12:00'));
      await settle(tester);

      // Два нажатия в один и тот же момент (до перерисовки кнопки)
      final onPressed = tester.widget<AppGradientButton>(find.byType(AppGradientButton).last).onPressed!;
      onPressed();
      onPressed();
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls, 1);
      expect(draft!.holdId, isNotEmpty);
      expect(draft!.idempotencyKey, isNotEmpty);
      await disposeTree(tester);
    });

    testWidgets('экран владеет удержанием, пока жив: после закрытия слот возвращается в продажу', (tester) async {
      final slots = deps.slots as MockSlotsRepository;
      await pumpBooking(tester, onConfirm: (_, _) async => true);
      await tester.ensureVisible(find.text('12:00'));
      await tester.tap(find.text('12:00'));
      await settle(tester);

      final onPressed = tester.widget<AppGradientButton>(find.byType(AppGradientButton).last).onPressed!;
      await onPressed();
      await settle(tester);
      expect(slots.activeHoldsCount, 1); // оформление приняли, но экран ещё жив — удержание на нём

      // Запись создаёт и расходует удержание на сервере; если её не создали, закрытие экрана его освобождает
      await disposeTree(tester);
      expect(slots.activeHoldsCount, 0);
    });

    testWidgets('слот, выбранный давно, перепроверяется при подтверждении: слишком близкий отклоняется', (
      tester,
    ) async {
      var calls = 0;
      await pumpBooking(
        tester,
        onConfirm: (_, _) async {
          calls++;
          return true;
        },
      );
      await tester.ensureVisible(find.text('11:00'));
      await tester.tap(find.text('11:00'));
      await settle(tester);

      // К моменту подтверждения до слота осталось меньше 30 минут (таймер удержания ещё не сработал)
      clock.advance(const Duration(minutes: 35));
      final onPressed = tester.widget<AppGradientButton>(find.byType(AppGradientButton).last).onPressed!;
      await onPressed();
      await settle(tester);

      expect(calls, 0);
      expect(find.textContaining('слишком близко'), findsOneWidget);
      expect(find.text('Выберите время'), findsOneWidget); // выбор сброшен
      await disposeTree(tester);
    });

    testWidgets('нехватка кредитов: способ оплаты переключается на онлайн без изменения состояния в build', (
      tester,
    ) async {
      state.clientCredits = 5;
      await pumpBooking(tester);
      await tester.ensureVisible(find.text('14:00'));
      await tester.tap(find.text('14:00'));
      await settle(tester);

      expect(find.textContaining('К оплате'), findsOneWidget);
      expect(find.textContaining('Записаться ·'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('отказ при оформлении: экран остаётся, ключ обновляется для новой попытки', (tester) async {
      final keys = <String>[];
      await pumpBooking(
        tester,
        onConfirm: (d, _) async {
          keys.add(d.idempotencyKey);
          return false;
        },
      );
      await tester.ensureVisible(find.text('12:00'));
      await tester.tap(find.text('12:00'));
      await settle(tester);

      final button = find.textContaining('Записаться ·');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await settle(tester);
      await tester.tap(button);
      await settle(tester);

      expect(keys.length, 2);
      expect(keys[0], isNot(keys[1])); // отказ — новая попытка с новым ключом
      await disposeTree(tester);
    });

    testWidgets('сбой сети при загрузке слотов: ошибка и повтор', (tester) async {
      useBigPhone(tester);
      await tester.pumpWidget(
        AppScope(
          dependencies: deps,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: BookingScreen(salonId: 's-001', onBack: () {}, onConfirm: (_, _) async => true),
          ),
        ),
      );
      // Салон уже запрошен; следующий запрос (слоты) упадёт
      network.failNext();
      await settle(tester);
      expect(find.text('Повторить'), findsOneWidget);

      await tester.tap(find.text('Повторить'));
      await settle(tester);
      expect(find.text('Повторить'), findsNothing);
      expect(find.text('12:00'), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('Профиль', () {
    testWidgets('форма личных данных сохраняет изменения и закрывается', (tester) async {
      useBigPhone(tester);
      await tester.pumpWidget(
        AppScope(
          dependencies: deps,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(onPressed: () => ProfileSheets.editProfile(context), child: const Text('Изменить')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Изменить'));
      await settle(tester);
      expect(find.text('Личные данные'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Новое Имя');
      await tester.ensureVisible(find.text('Сохранить'));
      await tester.tap(find.text('Сохранить'));
      await settle(tester);

      expect(state.clientName, 'Новое Имя');
      expect(find.text('Личные данные'), findsNothing);

      // Повторное открытие и закрытие не оставляет ошибок (контроллеры освобождаются вместе с формой)
      await tester.tap(find.text('Изменить'));
      await settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      await disposeTree(tester);
    });
  });

  group('Оплата', () {
    testWidgets('двойной тап «Оплатить» платит и создаёт запись один раз', (tester) async {
      final slotsRepo = deps.slots as MockSlotsRepository;
      final hold = (await deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: DateTime(2026, 11, 11, 15),
        durationMinutes: 45,
      )).valueOrNull!;
      final draft = BookingDraft(
        salonId: 's-001',
        salonName: 'Nur Beauty',
        serviceId: 'm-002-s1',
        serviceName: 'Архитектура бровей + окрашивание',
        durationMinutes: 45,
        masterId: 'm-002',
        masterName: 'Сабина',
        dateTime: DateTime(2026, 11, 11, 15),
        baseCredits: 24,
        sumPrice: 110000,
        holdId: hold.id,
        holdExpiresAt: hold.expiresAt,
        idempotencyKey: 'key-pay-1',
      );

      var paid = 0;
      // Платёж отвечает не мгновенно, но использует тот же «сервер» удержаний
      final payDeps = AppDependencies(
        auth: deps.auth,
        catalog: deps.catalog,
        slots: deps.slots,
        bookings: deps.bookings,
        payments: MockPaymentsRepository(
          slots: slotsRepo,
          network: MockNetwork(latency: const Duration(milliseconds: 100)),
        ),
        subscription: deps.subscription,
        visitQr: deps.visitQr,
        masterCabinet: deps.masterCabinet,
        appState: deps.appState,
      );

      await pumpScreen(
        tester,
        PaymentScreen(
          draft: draft,
          onBack: () {},
          onPaid: (_) async {
            paid++;
            return true;
          },
        ),
        dependencies: payDeps,
      );

      // Два нажатия в один и тот же момент (до перерисовки кнопки)
      final onPressed = tester.widget<AppGradientButton>(find.byType(AppGradientButton).last).onPressed!;
      onPressed();
      onPressed();
      await settle(tester);
      expect(paid, 1);
      await disposeTree(tester);
    });

    testWidgets('удержание истекло: диалог и возврат к выбору времени, деньги не списаны', (tester) async {
      final hold = (await deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: DateTime(2026, 11, 11, 15),
        durationMinutes: 45,
      )).valueOrNull!;
      var backs = 0;
      await pumpScreen(
        tester,
        PaymentScreen(
          draft: BookingDraft(
            salonId: 's-001',
            salonName: 'Nur Beauty',
            serviceId: 'm-002-s1',
            serviceName: 'Брови',
            durationMinutes: 45,
            masterId: 'm-002',
            masterName: 'Сабина',
            dateTime: DateTime(2026, 11, 11, 15),
            baseCredits: 24,
            sumPrice: 110000,
            holdId: hold.id,
            holdExpiresAt: hold.expiresAt,
            idempotencyKey: 'key-pay-2',
          ),
          onBack: () => backs++,
          onPaid: (_) async => true,
        ),
      );
      expect(find.textContaining('Слот закреплён за вами'), findsOneWidget);

      clock.advance(const Duration(minutes: 11));
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      expect(find.text('Время брони истекло'), findsOneWidget);
      await tester.tap(find.text('Выбрать время'));
      await settle(tester);
      expect(backs, 1);
      await disposeTree(tester);
    });
  });

  group('Вход и сессия', () {
    Future<void> login(WidgetTester tester, String user, String password) async {
      await tester.enterText(find.byType(TextField).at(0), user);
      await tester.enterText(find.byType(TextField).at(1), password);
      await tester.tap(find.text('Войти').first);
      await settle(tester);
    }

    testWidgets('вход мастера возвращает сессию с ролью из токена', (tester) async {
      AuthSession? session;
      await pumpScreen(tester, AuthScreen(onLoginSuccess: (s) => session = s));
      await login(tester, 'master', '12345678');
      expect(session!.role, UserRole.master);
      expect(session!.userId, 'm-002');
      await disposeTree(tester);
    });

    testWidgets('неверный пароль: сообщение и нет входа', (tester) async {
      AuthSession? session;
      await pumpScreen(tester, AuthScreen(onLoginSuccess: (s) => session = s));
      await login(tester, 'client', 'неверный');
      expect(session, isNull);
      expect(find.textContaining('Неверный логин или пароль'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('сбой сети при входе: понятное сообщение, повтор возможен', (tester) async {
      AuthSession? session;
      await pumpScreen(tester, AuthScreen(onLoginSuccess: (s) => session = s));
      network.failNext();
      await login(tester, 'client', '12345678');
      expect(session, isNull);
      expect(find.textContaining('Нет соединения'), findsOneWidget);

      await tester.tap(find.text('Войти').first);
      await settle(tester);
      expect(session!.role, UserRole.client);
      await disposeTree(tester);
    });

    testWidgets('приложение: сохранённый токен мастера сразу открывает кабинет мастера', (tester) async {
      final storage = InMemoryTokenStorage();
      await MockAuthRepository(storage: storage).login(login: 'master', password: '12345678');

      useBigPhone(tester);
      await tester.pumpWidget(
        GozallikApp(
          dependencies: AppDependencies.mock(network: network, tokenStorage: storage),
          themeOverride: ThemeData(fontFamily: 'Roboto'),
        ),
      );
      await settle(tester);
      // Нижняя панель мастера, а не клиента
      expect(find.text('Сканер'), findsWidgets);
      expect(find.text('Главная'), findsNothing);
      await disposeTree(tester);
    });

    testWidgets('приложение: без токена — экран входа; вход клиента и выход возвращают на вход', (tester) async {
      useBigPhone(tester);
      await tester.pumpWidget(
        GozallikApp(
          dependencies: deps,
          themeOverride: ThemeData(fontFamily: 'Roboto'),
        ),
      );
      await settle(tester);
      expect(find.text('Вход в систему'), findsOneWidget);

      await login(tester, 'client', '12345678');
      expect(find.text('Главная'), findsWidgets);
      expect(deps.auth.currentSession?.role, UserRole.client);

      // Профиль → Настройки → Выйти
      await tester.tap(find.text('Профиль').last);
      await settle(tester);
      await tester.tap(find.text('Настройки'));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Выйти из аккаунта'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Выйти из аккаунта'));
      await settle(tester);
      await tester.tap(find.text('Выйти').last);
      await settle(tester);

      expect(find.text('Вход в систему'), findsOneWidget);
      expect(deps.auth.currentSession, isNull);
      await disposeTree(tester);
    });
  });
}
