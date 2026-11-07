import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/data/mock/mock_slots_repository.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/location_permission_service.dart';
import 'package:beauty_salons/core/services/slot_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/widgets/ticker_mode_listener.dart';
import 'package:beauty_salons/features/master_cabinet/dashboard/master_dashboard_screen.dart';

/// Приёмка, задачи 39, 42, 43, 44. Время: среда 11 ноября 2026, 10:00.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  group('39. TickerModeListener: вкладка скрыта → сигнал', () {
    testWidgets('onChanged вызывается при скрытии и показе, но не при первом построении', (tester) async {
      final events = <bool>[];
      Widget build(bool enabled) => TickerMode(
        enabled: enabled,
        child: TickerModeListener(onChanged: events.add, child: const SizedBox()),
      );

      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(events, isEmpty);

      await tester.pumpWidget(build(false));
      await tester.pump();
      expect(events, [false]);

      await tester.pumpWidget(build(true));
      await tester.pump();
      expect(events, [false, true]);
    });
  });

  group('42. Экраны мастера берут время из AppClock', () {
    Future<void> pumpDashboard(WidgetTester tester) async {
      useBigPhone(tester);
      await tester.pumpWidget(
        AppScope(
          dependencies: AppDependencies.mock(network: MockNetwork()),
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Roboto'),
            home: MasterDashboardScreen(onOpenSchedule: () {}, onOpenEarnings: () {}, onScanQr: () {}),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('ближайший клиент считается от часов приложения, а не устройства', (tester) async {
      await pumpDashboard(tester); // 10:00 — запись Алины Каримовой (10:00–10:45) идёт прямо сейчас
      expect(find.text('Идёт сейчас'), findsOneWidget);
      expect(find.text('Алина Каримова'), findsWidgets);
      await disposeTree(tester);

      clock.set(DateTime(2026, 11, 11, 10, 50)); // её визит закончился: следующий — Wazow в 11:20
      await pumpDashboard(tester);
      expect(find.text('Идёт сейчас'), findsNothing);
      expect(find.text('Через 30 мин'), findsOneWidget);
      await disposeTree(tester);
    });
  });

  group('43. «Любой мастер» и чужие удержания', () {
    test('freeMasterIds возвращает всех свободных мастеров в порядке каталога', () {
      // 14:00: у Sabina занято (запись), у Алены и Мадины свободно
      final free = SlotService().freeMasterIds(
        salonId: 's-001',
        startsAt: DateTime(2026, 11, 11, 14),
        durationMinutes: 60,
      );
      expect(free, ['m-001', 'm-004']);
    });

    test('pickUnheldMaster пропускает мастера с чужим удержанием и берёт следующего', () {
      final pick = MockSlotsRepository.pickUnheldMaster(['m-A', 'm-B'], isHeld: (m) => m == 'm-A');
      expect(pick.found, isTrue);
      expect(pick.masterId, 'm-B');
    });

    test('pickUnheldMaster: удерживаются все — «не найден»; салон без мастеров (null) различим', () {
      expect(MockSlotsRepository.pickUnheldMaster(['m-A', 'm-B'], isHeld: (_) => true).found, isFalse);

      final free = MockSlotsRepository.pickUnheldMaster([null], isHeld: (_) => false);
      expect((free.found, free.masterId), (true, null)); // запись на салон целиком
      expect(MockSlotsRepository.pickUnheldMaster([null], isHeld: (_) => true).found, isFalse);
    });

    test('удержание у салона без мастеров по-прежнему конфликтует с другим удержанием', () async {
      final deps = AppDependencies.mock(network: MockNetwork());
      Future<bool> hold() async => (await deps.slots.holdSlot(
        salonId: 's-005',
        serviceId: 's-005-c1',
        startsAt: DateTime(2026, 11, 11, 14),
        durationMinutes: 60,
      )).isSuccess;

      expect(await hold(), isTrue);
      expect(await hold(), isFalse);
    });
  });

  group('44. Разрешение на геолокацию: «отказал навсегда»', () {
    const channel = MethodChannel('com.beauty_salon/location');

    void mockPlatform(Object? Function(MethodCall call) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => handler(call),
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null),
      );
    }

    test('все состояния платформы разбираются, включая permanentlyDenied', () async {
      final service = LocationPermissionService();
      for (final (raw, expected) in [
        ('granted', LocationPermissionStatus.granted),
        ('notDetermined', LocationPermissionStatus.notDetermined),
        ('denied', LocationPermissionStatus.denied),
        ('permanentlyDenied', LocationPermissionStatus.permanentlyDenied),
        ('restricted', LocationPermissionStatus.restricted),
        ('что-то-новое', LocationPermissionStatus.unsupported),
      ]) {
        mockPlatform((_) => raw);
        expect(await service.status(), expected, reason: raw);
        expect(await service.request(), expected, reason: raw);
      }
    });

    test('без нативного канала (тесты, десктоп) — unsupported', () async {
      expect(await LocationPermissionService().status(), LocationPermissionStatus.unsupported);
    });
  });
}
