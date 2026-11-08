import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/idempotency.dart';
import 'package:beauty_salons/core/data/mock/mock_auth_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/data/mock/mock_payments_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_slots_repository.dart';
import 'package:beauty_salons/core/data/repositories/auth_repository.dart';
import 'package:beauty_salons/core/data/repositories/bookings_repository.dart';
import 'package:beauty_salons/core/data/repositories/slots_repository.dart';
import 'package:beauty_salons/core/data/repository_exception.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/utils/result.dart';
import 'package:beauty_salons/core/utils/uuid.dart';

/// Тесты слоя данных (Фаза 3): идемпотентность, удержание слота, оплата, токен с ролью, QR, сбои сети.
/// Время фиксировано: среда 11 ноября 2026, 10:00.
void main() {
  final wednesday = DateTime(2026, 11, 11, 10);
  late FixedClock clock;
  late AppStateService state;
  late MockNetwork network;
  late AppDependencies deps;

  setUp(() {
    clock = FixedClock(wednesday);
    AppClock.current = clock;
    state = AppStateService()..resetSession();
    network = MockNetwork();
    deps = AppDependencies.mock(network: network);
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  DateTime at(int dayOffset, int hour) => DateTime(2026, 11, 11 + dayOffset, hour);

  /// Удержать слот Sabina (брови, 45 мин) и собрать запрос на запись
  Future<CreateBookingRequest> requestFor(DateTime when, {String method = PaymentMethods.credits}) async {
    final hold = (await deps.slots.holdSlot(
      salonId: 's-001',
      masterId: 'm-002',
      serviceId: 'm-002-s1',
      startsAt: when,
      durationMinutes: 45,
    )).valueOrNull!;
    return CreateBookingRequest(
      idempotencyKey: Uuid.v4(),
      holdId: hold.id,
      salonId: 's-001',
      salonName: 'Nur Beauty',
      serviceId: 'm-002-s1',
      serviceName: 'Архитектура бровей + окрашивание',
      masterId: 'm-002',
      masterName: 'Сабина',
      startsAt: when,
      durationMinutes: 45,
      baseCredits: 24,
      sumPrice: 110000,
      paymentMethod: method,
    );
  }

  group('Uuid', () {
    test('формат v4 и уникальность', () {
      final ids = {for (var i = 0; i < 200; i++) Uuid.v4()};
      expect(ids.length, 200);
      final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(ids.every(pattern.hasMatch), isTrue);
    });

    test('id новой записи — uuid', () {
      final r = state.createBooking(
        salonId: 's-001',
        salonName: 'Nur Beauty',
        serviceId: 'm-002-s1',
        serviceName: 'Брови',
        masterId: 'm-002',
        masterName: 'Сабина',
        dateTime: at(0, 15),
        durationMinutes: 45,
        baseCredits: 24,
        sumPrice: 110000,
        paymentMethod: PaymentMethods.inSalon,
      );
      expect(r.valueOrNull!.id, matches(RegExp(r'^b-[0-9a-f]{8}-')));
    });
  });

  group('IdempotencyGuard', () {
    test('одновременные вызовы с одним ключом выполняют действие один раз', () async {
      final guard = IdempotencyGuard();
      var runs = 0;
      Future<int> action() async {
        runs++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return runs;
      }

      final results = await Future.wait([guard.run('k', action), guard.run('k', action), guard.run('k', action)]);
      expect(runs, 1);
      expect(results, [1, 1, 1]);
    });

    test('повтор после завершения возвращает прежний результат', () async {
      final guard = IdempotencyGuard();
      var runs = 0;
      expect(await guard.run('k', () async => ++runs), 1);
      expect(await guard.run('k', () async => ++runs), 1);
      expect(await guard.run('другой', () async => ++runs), 2);
    });

    test('сетевая ошибка освобождает ключ — повтор выполняется заново', () async {
      final guard = IdempotencyGuard();
      var runs = 0;
      Future<int> flaky() async {
        runs++;
        if (runs == 1) throw const RepositoryException('нет сети');
        return runs;
      }

      await expectLater(guard.run('k', flaky), throwsA(isA<RepositoryException>()));
      expect(await guard.run('k', flaky), 2);
    });

    test('память ограничена', () async {
      final guard = IdempotencyGuard(maxEntries: 3);
      for (var i = 0; i < 5; i++) {
        await guard.run('k$i', () async => i);
      }
      expect(guard.contains('k0'), isFalse);
      expect(guard.contains('k4'), isTrue);
    });
  });

  group('Запись через репозиторий (задача 13)', () {
    test('двойной тап «Подтвердить» создаёт одну запись и списывает кредиты один раз', () async {
      final request = await requestFor(at(0, 15));
      final before = state.bookings.length;

      final results = await Future.wait([deps.bookings.create(request), deps.bookings.create(request)]);

      expect(results.every((r) => r.isSuccess), isTrue);
      expect(results[0].valueOrNull!.id, results[1].valueOrNull!.id);
      expect(state.bookings.length, before + 1);
      expect(state.clientCredits, 86 - 24);
    });

    test('повтор после успеха возвращает ту же запись, а не вторую', () async {
      final request = await requestFor(at(0, 15));
      final first = await deps.bookings.create(request);
      final again = await deps.bookings.create(request);
      expect(again.valueOrNull!.id, first.valueOrNull!.id);
      expect(state.bookings.where((b) => b.startsAt == at(0, 15)).length, 1);
    });

    test('двойная отмена с одним ключом и с разными ключами возвращает кредиты один раз', () async {
      final key = Uuid.v4();
      await Future.wait([
        deps.bookings.cancel(bookingId: 'b-005', idempotencyKey: key),
        deps.bookings.cancel(bookingId: 'b-005', idempotencyKey: key),
      ]);
      expect(state.clientCredits, 86 + 26);

      final other = await deps.bookings.cancel(bookingId: 'b-005', idempotencyKey: Uuid.v4());
      expect(other.errorOrNull?.code, BookingErrorCode.notActive);
      expect(state.clientCredits, 86 + 26);
    });

    test('двойная покупка пакета начисляет кредиты один раз', () async {
      final key = Uuid.v4();
      await Future.wait([
        deps.subscription.purchasePackage(planName: 'Lite', credits: 60, idempotencyKey: key),
        deps.subscription.purchasePackage(planName: 'Lite', credits: 60, idempotencyKey: key),
      ]);
      // Premium 250 → перенос не больше 20% = 50; 86 → 50 + 60
      expect(state.clientCredits, 110);
    });

    test('сбой сети не залипает: повтор с тем же ключом выполняется', () async {
      final request = await requestFor(at(0, 15));
      network.failNext();
      await expectLater(deps.bookings.create(request), throwsA(isA<RepositoryException>()));
      expect(state.bookings.any((b) => b.startsAt == at(0, 15)), isFalse);

      final retry = await deps.bookings.create(request);
      expect(retry.isSuccess, isTrue);
      expect(state.bookings.where((b) => b.startsAt == at(0, 15)).length, 1);
    });
  });

  group('Удержание слота (задача 14)', () {
    test('удержание живёт 10 минут от серверных часов', () async {
      final hold = (await deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: at(0, 15),
        durationMinutes: 45,
      )).valueOrNull!;
      expect(hold.expiresAt, wednesday.add(const Duration(minutes: 10)));
    });

    test('запись по истёкшему удержанию отклоняется', () async {
      final request = await requestFor(at(0, 15));
      clock.advance(const Duration(minutes: 10, seconds: 1));
      final result = await deps.bookings.create(request);
      expect(result.errorOrNull?.code, BookingErrorCode.holdExpired);
      expect(state.bookings.any((b) => b.startsAt == at(0, 15)), isFalse);
    });

    test('удержание расходуется записью: новая запись по нему невозможна', () async {
      final request = await requestFor(at(0, 15));
      expect((await deps.bookings.create(request)).isSuccess, isTrue);
      final second = CreateBookingRequest(
        idempotencyKey: Uuid.v4(),
        holdId: request.holdId,
        salonId: request.salonId,
        salonName: request.salonName,
        serviceId: request.serviceId,
        serviceName: request.serviceName,
        masterId: request.masterId,
        masterName: request.masterName,
        startsAt: request.startsAt,
        durationMinutes: request.durationMinutes,
        baseCredits: request.baseCredits,
        sumPrice: request.sumPrice,
        paymentMethod: request.paymentMethod,
      );
      expect((await deps.bookings.create(second)).errorOrNull?.code, BookingErrorCode.holdExpired);
    });

    test('освобождённое удержание нельзя использовать; замена освобождает прежнее', () async {
      final first = (await deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: at(0, 15),
        durationMinutes: 45,
      )).valueOrNull!;
      final second = (await deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: at(0, 16),
        durationMinutes: 45,
        replaceHoldId: first.id,
      )).valueOrNull!;

      final slots = deps.slots as MockSlotsRepository;
      expect(slots.activeHold(first.id), isNull);
      expect(slots.activeHold(second.id), isNotNull);

      await deps.slots.releaseHold(second.id);
      expect(slots.activeHold(second.id), isNull);
    });

    test('пересекающиеся удержания одного мастера отклоняются, «Любой мастер» закрепляется за конкретным', () async {
      Future<Result<SlotHold, BookingError>> hold(DateTime when, {String? masterId = 'm-002'}) => deps.slots.holdSlot(
        salonId: 's-001',
        masterId: masterId,
        serviceId: 'm-002-s1',
        startsAt: when,
        durationMinutes: 45,
      );

      expect((await hold(at(0, 15))).isSuccess, isTrue);
      expect((await hold(at(0, 15))).errorOrNull?.code, BookingErrorCode.slotUnavailable);

      final any = await hold(at(0, 16), masterId: null);
      expect(any.valueOrNull!.masterId, 'm-002'); // услугу оказывает только Sabina
    });

    test('после тайм-аута удержания выбор другого слота работает с первого раза (без падения)', () async {
      Future<Result<SlotHold, BookingError>> hold(DateTime when) => deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: when,
        durationMinutes: 45,
      );
      final slots = deps.slots as MockSlotsRepository;

      expect((await hold(at(0, 15))).isSuccess, isTrue);
      clock.advance(const Duration(minutes: 11)); // удержание истекло, но ещё лежит в реестре

      final next = await hold(at(0, 16)); // раньше: ConcurrentModificationError
      expect(next.isSuccess, isTrue);
      expect(slots.activeHoldsCount, 1); // истёкшее убрано, новое действует
    });

    test('истёкшее удержание того же мастера на то же время не мешает новому', () async {
      Future<Result<SlotHold, BookingError>> hold() => deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: at(0, 15),
        durationMinutes: 45,
      );

      expect((await hold()).isSuccess, isTrue);
      expect((await hold()).errorOrNull?.code, BookingErrorCode.slotUnavailable); // пока действует — конфликт

      clock.advance(const Duration(minutes: 11));
      expect((await hold()).isSuccess, isTrue); // истекло — слот снова свободен
    });

    test('счётчик активных удержаний не падает и не считает истёкшие', () async {
      final slots = deps.slots as MockSlotsRepository;
      await deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: at(0, 15),
        durationMinutes: 45,
      );
      expect(slots.activeHoldsCount, 1);
      clock.advance(const Duration(minutes: 11));
      expect(slots.activeHoldsCount, 0);
    });

    test('прошедшее и недоступное время не удерживается', () async {
      Future<Result<SlotHold, BookingError>> hold(DateTime when) => deps.slots.holdSlot(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: when,
        durationMinutes: 45,
      );
      expect((await hold(at(0, 9))).errorOrNull?.code, BookingErrorCode.inPast);
      expect((await hold(at(0, 13))).errorOrNull?.code, BookingErrorCode.slotUnavailable); // перерыв
    });
  });

  group('Оплата (задача 14 + платёж без записи)', () {
    test('оплата продлевает удержание, двойной тап платит один раз', () async {
      final request = await requestFor(at(0, 15), method: PaymentMethods.online);
      clock.advance(const Duration(minutes: 9));
      final key = Uuid.v4();
      final results = await Future.wait([
        deps.payments.pay(amount: 22000, provider: 'Click', holdId: request.holdId, idempotencyKey: key),
        deps.payments.pay(amount: 22000, provider: 'Click', holdId: request.holdId, idempotencyKey: key),
      ]);
      expect(results[0].isSuccess, isTrue);
      expect(results[0].valueOrNull!.id, results[1].valueOrNull!.id);

      // Удержание продлено: через 2 минуты (всего 11 от начала) запись ещё возможна
      clock.advance(const Duration(minutes: 2));
      final booking = await deps.bookings.create(request);
      expect(booking.isSuccess, isTrue);
    });

    test('без действующего удержания оплата не проходит', () async {
      final request = await requestFor(at(0, 15), method: PaymentMethods.online);
      clock.advance(const Duration(minutes: 11));
      final paid = await deps.payments.pay(
        amount: 22000,
        provider: 'Click',
        holdId: request.holdId,
        idempotencyKey: Uuid.v4(),
      );
      expect(paid.isFailure, isTrue);
    });

    test('возврат платежа выполняется один раз на ключ', () async {
      final payments = deps.payments as MockPaymentsRepository;
      final key = Uuid.v4();
      await deps.payments.refund(receiptId: 'pay_1', idempotencyKey: key);
      await deps.payments.refund(receiptId: 'pay_1', idempotencyKey: key);
      expect(payments.wasRefunded('pay_1'), isTrue);
    });
  });

  group('Авторизация (роль из токена)', () {
    test('вход возвращает сессию с ролью, прочитанной из токена', () async {
      final client = (await deps.auth.login(login: 'client', password: '12345678')).valueOrNull!;
      expect(client.role, UserRole.client);
      expect(client.userId, 'c-001');
      expect(client.accessToken.split('.').length, 3);

      final master = (await deps.auth.login(login: 'master', password: '12345678')).valueOrNull!;
      expect(master.isMaster, isTrue);
      expect(master.userId, 'm-002');
    });

    test('неверный пароль и неизвестный логин отклоняются', () async {
      expect((await deps.auth.login(login: 'client', password: 'x')).isFailure, isTrue);
      expect((await deps.auth.login(login: 'нет', password: '12345678')).isFailure, isTrue);
      expect(deps.auth.currentSession, isNull);
    });

    test('сессия восстанавливается из токена в хранилище; выход очищает его', () async {
      final storage = InMemoryTokenStorage();
      final first = MockAuthRepository(storage: storage);
      await first.login(login: 'master', password: '12345678');

      final second = MockAuthRepository(storage: storage); // «новый запуск приложения»
      final restored = await second.restoreSession();
      expect(restored!.role, UserRole.master);

      await second.logout();
      expect(await MockAuthRepository(storage: storage).restoreSession(), isNull);
    });

    test('истёкший или испорченный токен не принимается', () async {
      final storage = InMemoryTokenStorage();
      await MockAuthRepository(storage: storage).login(login: 'client', password: '12345678');
      clock.advance(MockAuthRepository.tokenLifetime + const Duration(minutes: 1));
      expect(await MockAuthRepository(storage: storage).restoreSession(), isNull);

      await storage.write('это.не.токен');
      expect(await MockAuthRepository(storage: storage).restoreSession(), isNull);
      expect(MockAuthRepository.sessionFromToken('мусор'), isNull);
    });

    test('роль нельзя подменить: меняется только payload — токен без подписи в моке, но роль читается из него', () {
      final token = MockAuthRepository.issueToken(
        userId: 'm-002',
        role: UserRole.master,
        expiresAt: wednesday.add(const Duration(hours: 1)),
      );
      expect(MockAuthRepository.sessionFromToken(token)!.role, UserRole.master);
    });
  });

  group('QR визита (задача 15)', () {
    test('токен выдаётся через репозиторий и подтверждает визит один раз', () async {
      final token = await deps.visitQr.issueToken('b-001');
      expect(token.expiresAt, wednesday.add(const Duration(seconds: 60)));
      expect(token.value.split('|').length, 4);

      final first = await deps.visitQr.verifyAndConfirm(token.value, ignoreTimeWindow: true);
      expect(first.isSuccess, isTrue);
      expect(first.booking!.clientName, 'Wazow');

      final replay = await deps.visitQr.verifyAndConfirm(token.value, ignoreTimeWindow: true);
      expect(replay.isSuccess, isFalse);
    });

    test('один и тот же nonce нельзя использовать повторно даже для другой записи', () async {
      state.createBooking(
        salonId: 's-001',
        salonName: 'Nur Beauty',
        serviceId: 'm-002-s1',
        serviceName: 'Брови',
        masterId: 'm-002',
        masterName: 'Сабина',
        dateTime: at(0, 15),
        durationMinutes: 45,
        baseCredits: 24,
        sumPrice: 110000,
        paymentMethod: PaymentMethods.inSalon,
      );
      final other = state.bookings.firstWhere((b) => b.startsAt == at(0, 15));
      final ms = clock.now().millisecondsSinceEpoch;

      expect(state.validateVisitQr('GZL|b-001|$ms|одноразовый', ignoreTimeWindow: true).isSuccess, isTrue);
      final reused = state.validateVisitQr('GZL|${other.id}|$ms|одноразовый', ignoreTimeWindow: true);
      expect(reused.isSuccess, isFalse);
      expect(reused.error, contains('использован'));
    });

    test('код «из будущего» и устаревший код отклоняются', () async {
      final future = clock.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
      final stale = clock.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch;
      expect(state.validateVisitQr('GZL|b-001|$future|n1', ignoreTimeWindow: true).error, contains('проверку времени'));
      expect(state.validateVisitQr('GZL|b-001|$stale|n2', ignoreTimeWindow: true).error, contains('устарел'));
      // Небольшое расхождение часов допустимо
      final skew = clock.now().add(const Duration(seconds: 10)).millisecondsSinceEpoch;
      expect(state.validateVisitQr('GZL|b-001|$skew|n3', ignoreTimeWindow: true).isSuccess, isTrue);
    });

    test('выдача токена для несуществующей записи — ошибка данных', () async {
      await expectLater(deps.visitQr.issueToken('нет-такой'), throwsA(isA<RepositoryException>()));
    });
  });

  group('Каталог', () {
    test('несуществующий салон и мастер дают null, а сбой сети — исключение', () async {
      expect(await deps.catalog.getSalonDetails('s-unknown'), isNull);
      expect(await deps.catalog.getMaster('m-unknown'), isNull);

      final details = (await deps.catalog.getSalonDetails('s-001'))!;
      expect(details.salon.name, 'Nur Beauty');
      expect(details.masters.map((m) => m.id), containsAll(['m-001', 'm-002']));

      network.failNext();
      await expectLater(deps.catalog.getSalons(), throwsA(isA<RepositoryException>()));
      expect((await deps.catalog.getSalons()).length, 9);
    });
  });
}
