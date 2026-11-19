import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/data/mock/mock_master_cabinet_repository.dart';
import 'package:beauty_salons/core/data/repositories/master_cabinet_repository.dart';
import 'package:beauty_salons/core/utils/formatters.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/master_cabinet_store.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/features/master_cabinet/dashboard/master_dashboard_screen.dart';
import 'package:beauty_salons/features/master_cabinet/earnings/master_earnings_screen.dart';
import 'package:beauty_salons/features/master_cabinet/schedule/master_schedule_screen.dart';

/// Задача 37: кабинет мастера идёт через асинхронный репозиторий. Время: среда 11 ноября 2026, 10:00.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  late MockNetwork network;
  late AppDependencies deps;

  setUp(() {
    AppClock.current = FixedClock(DateTime(2026, 11, 11, 10));
    AppStateService().resetSession();
    network = MockNetwork();
    deps = AppDependencies.mock(network: network);
  });

  tearDown(() {
    AppClock.reset();
    AppStateService().resetSession();
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      AppScope(
        dependencies: deps,
        child: MaterialApp(theme: ThemeData(fontFamily: 'Roboto'), home: screen),
      ),
    );
    await settle(tester);
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('доход: сбой сети → «Повторить» → данные', (tester) async {
    network.failNext();
    await pump(tester, MasterEarningsScreen(onBack: () {}));
    expect(find.textContaining('Нет соединения'), findsOneWidget);
    expect(find.text('Начислено за месяц'), findsNothing);

    await tester.tap(find.text('Повторить'));
    await settle(tester);
    expect(find.text('Повторить'), findsNothing);
    expect(find.text('Начислено за месяц'), findsOneWidget);
    await dispose(tester);
  });

  testWidgets('главная мастера: сбой сети → «Повторить» → записи', (tester) async {
    network.failNext(2); // первый сбой уходит на загрузку профиля мастера (тихо), второй — на записи
    await pump(tester, MasterDashboardScreen(onOpenSchedule: () {}, onOpenEarnings: () {}, onScanQr: () {}));
    expect(find.textContaining('Нет соединения'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await settle(tester);
    expect(find.text('Повторить'), findsNothing);
    expect(find.text('Алина Каримова'), findsWidgets);
    await dispose(tester);
  });

  testWidgets('график: сбой загрузки показывает ошибку с повтором', (tester) async {
    network.failNext();
    await pump(tester, MasterScheduleScreen(onBack: () {}));
    expect(find.textContaining('Нет соединения'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await settle(tester);
    expect(find.text('Повторить'), findsNothing);
    expect(find.text('Рабочий график'), findsWidgets);
    await dispose(tester);
  });

  test('сбой сохранения дня не меняет график на «сервере»', () async {
    final before = MasterCabinetStore().getDay(DateTime.monday);
    network.failNext();
    await expectLater(deps.masterCabinet.saveDay(DateTime.monday, before.copyWith(isWorking: false)), throwsException);
    expect(MasterCabinetStore().getDay(DateTime.monday).isWorking, before.isWorking);

    await deps.masterCabinet.saveDay(DateTime.monday, before.copyWith(isWorking: false));
    expect(MasterCabinetStore().getDay(DateTime.monday).isWorking, isFalse);
  });

  AppDependencies depsWith(_ControlledRepo repo) {
    final base = AppDependencies.mock(network: network);
    return AppDependencies(
      auth: base.auth,
      reviews: base.reviews,
      catalog: base.catalog,
      slots: base.slots,
      bookings: base.bookings,
      payments: base.payments,
      subscription: base.subscription,
      visitQr: base.visitQr,
      masterCabinet: repo,
      appState: base.appState,
    );
  }

  testWidgets('главная мастера перечитывает данные только при изменении записей, а не избранного или аватара', (
    tester,
  ) async {
    final repo = _ControlledRepo(MockMasterCabinetRepository(network: network));
    deps = depsWith(repo);
    await pump(tester, MasterDashboardScreen(onOpenSchedule: () {}, onOpenEarnings: () {}, onScanQr: () {}));
    expect(repo.dashboardCalls, 1);

    AppStateService().toggleSalonFavorite('s-001');
    AppStateService().updateMasterAvatar('/tmp/master.jpg');
    await settle(tester);
    expect(repo.dashboardCalls, 1, reason: 'избранное и аватар не затрагивают записи');

    AppStateService().cancelBooking('b-005'); // запись изменилась
    await settle(tester);
    expect(repo.dashboardCalls, 2);
    await dispose(tester);
  });

  testWidgets('главная мастера: ответ на более старый запрос не затирает более новый', (tester) async {
    final repo = _ControlledRepo(MockMasterCabinetRepository(network: network))..manual = true;
    deps = depsWith(repo);
    MasterDashboardData data(int revenue) => MasterDashboardData(
      today: const [],
      tomorrow: const [],
      notifications: const [],
      visitsThisMonth: 0,
      monthClients: const [],
      revenueToday: revenue,
    );

    await pump(tester, MasterDashboardScreen(onOpenSchedule: () {}, onOpenEarnings: () {}, onScanQr: () {}));
    AppStateService().cancelBooking('b-005'); // второй запрос, пока первый не вернулся
    await tester.pump();
    expect(repo.pending.length, 2);

    // Сначала приходит ответ на новый запрос, потом запоздалый ответ на старый
    repo.pending[1].complete(data(2000));
    await settle(tester);
    repo.pending[0].complete(data(1000));
    await settle(tester);

    final shown = Formatters.formatSum(2000).replaceAll(' сум', '');
    final stale = Formatters.formatSum(1000).replaceAll(' сум', '');
    expect(find.text(shown), findsOneWidget);
    expect(find.text(stale), findsNothing);
    await dispose(tester);
  });
}

/// Репозиторий с управляемыми ответами: считает запросы главной и умеет отвечать на них в любом порядке.
class _ControlledRepo implements MasterCabinetRepository {
  _ControlledRepo(this._inner);

  final MasterCabinetRepository _inner;
  int dashboardCalls = 0;
  bool manual = false;
  final pending = <Completer<MasterDashboardData>>[];

  @override
  Future<MasterDashboardData> dashboard() {
    dashboardCalls++;
    if (!manual) return _inner.dashboard();
    final completer = Completer<MasterDashboardData>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<MasterEarningsData> earnings(int monthOffset) => _inner.earnings(monthOffset);

  @override
  Future<MasterAccountStats> accountStats() => _inner.accountStats();

  @override
  Future<MasterWeek> week() => _inner.week();

  @override
  Future<MasterClientProfile?> clientProfile(String clientId) => _inner.clientProfile(clientId);

  @override
  Future<void> saveDay(int weekday, DaySchedule schedule) => _inner.saveDay(weekday, schedule);

  @override
  Future<void> copyDayTo(DaySchedule source, Iterable<int> weekdays) => _inner.copyDayTo(source, weekdays);

  @override
  Future<void> setDayWorking(int weekday, bool isWorking) => _inner.setDayWorking(weekday, isWorking);
}
