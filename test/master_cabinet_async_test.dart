import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
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
}
