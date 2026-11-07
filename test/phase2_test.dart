import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/booking_store.dart';
import 'package:beauty_salons/core/services/master_cabinet_repository.dart';
import 'package:beauty_salons/core/services/slot_service.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/utils/result.dart';

/// Тесты Фазы 2: единый стор записей, SlotService, правила создания/отмены/переноса,
/// заморозка, перенос кредитов (K-01), сброс сессии, график мастера.
///
/// Время фиксировано: среда 11 ноября 2026, 10:00. Мок-данные считаются от этого момента:
/// запись клиента b-001 к мастеру Sabina — 11:20 (до неё 80 минут), b-005 (Elite Barber) — завтра 08:00.
void main() {
  final wednesday = DateTime(2026, 11, 11, 10);
  late FixedClock clock;
  late AppStateService state;
  final slots = SlotService();

  setUp(() {
    clock = FixedClock(wednesday);
    AppClock.current = clock;
    state = AppStateService()..resetSession();
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  DateTime at(int dayOffset, int hour, [int minute = 0]) => DateTime(2026, 11, 11 + dayOffset, hour, minute);

  /// Запись к Sabina (брови, 45 мин, 24 кр.) по умолчанию
  Result<BookingItem, BookingError> book({
    String salonId = 's-001',
    String salonName = 'Nur Beauty',
    String? masterId = 'm-002',
    String masterName = 'Сабина',
    String serviceId = 'm-002-s1',
    String serviceName = 'Архитектура бровей + окрашивание',
    int duration = 45,
    int base = 24,
    int sum = 110000,
    required DateTime when,
    String method = PaymentMethods.credits,
  }) => state.createBooking(
    salonId: salonId,
    salonName: salonName,
    serviceId: serviceId,
    serviceName: serviceName,
    masterId: masterId,
    masterName: masterName,
    dateTime: when,
    durationMinutes: duration,
    baseCredits: base,
    sumPrice: sum,
    paymentMethod: method,
  );

  BookingErrorCode? codeOf(Result<Object?, BookingError> r) => r.errorOrNull?.code;

  group('SlotService', () {
    test('график мастера, перерыв, чужие записи, прошедшее время; отменённая запись время не занимает', () {
      // Sabina, среда: 9:00–19:00, перерыв 13–14. Занято: b-001 11:20–12:05, 12:00–13:00, 14:00–14:45
      // (запись в 16:00 отменена), прошедшее: до 10:30.
      final result = slots.availableSlots(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        date: wednesday,
        durationMinutes: 45,
      );
      expect(result, [at(0, 15), at(0, 16), at(0, 17), at(0, 18)]);
    });

    test('в воскресенье у Sabina выходной', () {
      final sunday = DateTime(2026, 11, 15);
      expect(
        slots.availableSlots(
          salonId: 's-001',
          masterId: 'm-002',
          serviceId: 'm-002-s1',
          date: sunday,
          durationMinutes: 45,
        ),
        isEmpty,
      );
    });

    test('изменения графика мастера сразу влияют на запись клиента: выключенный слот и перерыв', () {
      final cabinet = MasterCabinetRepository();
      final thursday = DateTime(2026, 11, 12);
      var day = cabinet.getDay(DateTime.thursday);

      // Закрыли слот 15:00
      day = day.copyWith(slots: [for (final s in day.slots) s.range.start == 900 ? s.copyWith(enabled: false) : s]);
      cabinet.saveDay(DateTime.thursday, day);

      final result = slots.availableSlots(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        date: thursday,
        durationMinutes: 45,
      );
      expect(result.contains(DateTime(2026, 11, 12, 15)), isFalse);
      expect(result.contains(DateTime(2026, 11, 12, 14)), isTrue);

      // Услуга на 90 минут с 14:00 заходит на закрытый слот 15:00 — тоже недоступна
      final long = slots.availableSlots(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s2',
        date: thursday,
        durationMinutes: 90,
      );
      expect(long.contains(DateTime(2026, 11, 12, 14)), isFalse);
    });

    test('«Любой мастер»: объединение мастеров, которые оказывают услугу', () {
      // Услугу m-002-s1 оказывает только Sabina
      final any = slots.availableSlots(salonId: 's-001', serviceId: 'm-002-s1', date: wednesday, durationMinutes: 45);
      expect(any, [at(0, 15), at(0, 16), at(0, 17), at(0, 18)]);

      // Услугу m-001-s1 оказывает только Алена: график по умолчанию 10:00–21:00, первый свободный — 11:00
      final alena = slots.availableSlots(salonId: 's-001', serviceId: 'm-001-s1', date: wednesday, durationMinutes: 60);
      expect(alena.first, at(0, 11));
      expect(alena.last, at(0, 20));
    });

    test('мастер из другого салона и неизвестная услуга дают пустой список', () {
      expect(slots.availableSlots(salonId: 's-001', masterId: 'm-005', date: wednesday, durationMinutes: 45), isEmpty);
      expect(
        slots.availableSlots(salonId: 's-001', serviceId: 'нет-такой', date: wednesday, durationMinutes: 45),
        isEmpty,
      );
    });

    test('салон без мастеров использует общий график и общий календарь', () {
      final free = slots.availableSlots(salonId: 's-005', date: wednesday, durationMinutes: 60);
      expect(free.first, at(0, 11)); // 10:00 уже прошло (раньше 10:30)

      expect(
        book(
          salonId: 's-005',
          salonName: 'Zara Beauty Lab',
          masterId: null,
          masterName: 'Любой мастер',
          serviceId: 's-005-c1',
          when: at(0, 13),
          method: PaymentMethods.inSalon,
        ).isSuccess,
        isTrue,
      );
      final after = slots.availableSlots(salonId: 's-005', date: wednesday, durationMinutes: 60);
      expect(after.contains(at(0, 13)), isFalse);
    });
  });

  group('Создание записи (задача 3)', () {
    test('успешная запись резервирует кредиты по k_slot и попадает в стор', () {
      final r = book(when: at(0, 17)); // вечер не наступил: до 18:00 коэффициент 1.0
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull!.credits, 24);
      expect(state.clientCredits, 86 - 24);

      final evening = book(when: at(0, 18), masterId: 'm-002'); // 18:00 → ×1.2 = 28.8 → 29
      expect(evening.valueOrNull!.credits, 29);
      expect(state.bookings.any((b) => b.id == evening.valueOrNull!.id), isTrue);
    });

    test('при нехватке кредитов запись не создаётся, баланс не уходит в ноль или минус', () {
      state.clientCredits = 5;
      final before = state.bookings.length;
      final r = book(when: at(0, 15));
      expect(codeOf(r), BookingErrorCode.notEnoughCredits);
      expect(state.clientCredits, 5);
      expect(state.bookings.length, before);
    });

    test('прошедшее время и слишком близкое отклоняются', () {
      expect(codeOf(book(when: at(0, 9))), BookingErrorCode.inPast);
      expect(codeOf(book(when: at(0, 10, 20))), BookingErrorCode.inPast); // меньше 30 минут
    });

    test('занятый слот и слот вне графика отклоняются', () {
      expect(book(when: at(0, 15)).isSuccess, isTrue);
      // Тот же мастер, то же время — занято
      expect(codeOf(book(when: at(0, 15), method: PaymentMethods.online)), BookingErrorCode.slotUnavailable);
      // Перерыв 13:00
      expect(codeOf(book(when: at(0, 13))), BookingErrorCode.slotUnavailable);
      // Воскресенье — выходной
      expect(codeOf(book(when: DateTime(2026, 11, 15, 11))), BookingErrorCode.slotUnavailable);
    });

    test('нельзя записаться на пересекающееся время к другому мастеру', () {
      expect(book(when: at(0, 15)).isSuccess, isTrue); // Sabina 15:00–15:45
      final other = book(
        masterId: 'm-001',
        masterName: 'Алена',
        serviceId: 'm-001-s1',
        serviceName: 'Комбинированный маникюр + гель-лак',
        duration: 60,
        base: 34,
        sum: 150000,
        when: at(0, 15),
      );
      expect(codeOf(other), BookingErrorCode.overlapsOwnBooking);
    });

    test('K-03: не больше 4 записей за кредиты в салон за месяц; онлайн-оплата лимитом не ограничена', () {
      state.clientCredits = 1000;
      // Уже есть две записи за кредиты в Nur Beauty в ноябре: b-001 и b-002
      Result<BookingItem, BookingError> alena(DateTime when, {String method = PaymentMethods.credits}) => book(
        masterId: 'm-001',
        masterName: 'Алена',
        serviceId: 'm-001-s1',
        serviceName: 'Комбинированный маникюр + гель-лак',
        duration: 60,
        base: 34,
        sum: 150000,
        when: when,
        method: method,
      );
      expect(alena(at(2, 10)).isSuccess, isTrue);
      expect(alena(at(3, 10)).isSuccess, isTrue);
      expect(codeOf(alena(at(5, 10))), BookingErrorCode.creditsLimit);
      expect(alena(at(5, 10), method: PaymentMethods.online).isSuccess, isTrue);
    });

    test('заморозка абонемента блокирует оплату кредитами', () {
      expect(state.freezeSubscription(7), isTrue);
      expect(codeOf(book(when: at(1, 15))), BookingErrorCode.creditsFrozen);
      expect(book(when: at(1, 15), method: PaymentMethods.inSalon).isSuccess, isTrue);
    });

    test('«Любой мастер» подменяется конкретным свободным мастером', () {
      final r = book(
        masterId: null,
        masterName: 'Любой мастер',
        serviceId: 'm-001-s1',
        serviceName: 'Комбинированный маникюр + гель-лак',
        duration: 60,
        base: 34,
        sum: 150000,
        when: at(1, 12),
      );
      expect(r.valueOrNull!.masterId, 'm-001');
      expect(r.valueOrNull!.masterName, 'Алена');
    });

    test('validateNewBooking ничего не меняет', () {
      final credits = state.clientCredits;
      final count = state.bookings.length;
      final check = state.validateNewBooking(
        salonId: 's-001',
        masterId: 'm-002',
        serviceId: 'm-002-s1',
        startsAt: at(0, 15),
        durationMinutes: 45,
        baseCredits: 24,
        paymentMethod: PaymentMethods.credits,
      );
      expect(check.isSuccess, isTrue);
      expect(state.clientCredits, credits);
      expect(state.bookings.length, count);
    });
  });

  group('Отмена, перенос, отзыв (задачи 4 и 5)', () {
    test('двойная отмена возвращает кредиты только один раз', () {
      final first = state.cancelBooking('b-005'); // завтра 08:00, до визита 22 часа
      expect(first.isSuccess, isTrue);
      expect(state.clientCredits, 86 + 26);

      final second = state.cancelBooking('b-005');
      expect(codeOf(second), BookingErrorCode.notActive);
      expect(state.clientCredits, 86 + 26);
    });

    test('отмена менее чем за 2 часа и чужая или несуществующая запись отклоняются', () {
      expect(codeOf(state.cancelBooking('b-001')), BookingErrorCode.tooLate); // 80 минут
      expect(codeOf(state.cancelBooking('x-101')), BookingErrorCode.notFound); // запись другого клиента
      expect(codeOf(state.cancelBooking('нет-такой')), BookingErrorCode.notFound);
      expect(state.clientCredits, 86);
    });

    test('отменённую запись нельзя перенести', () {
      state.cancelBooking('b-005');
      expect(codeOf(state.rescheduleBooking(bookingId: 'b-005', newDateTime: at(1, 12))), BookingErrorCode.notActive);
    });

    test('перенос пересчитывает кредиты по k_slot: вечером доплата, днём возврат', () {
      // b-005: Тимур, 26 кр. (база), завтра 08:00
      final evening = state.rescheduleBooking(bookingId: 'b-005', newDateTime: at(1, 18));
      expect(evening.valueOrNull!.credits, 32); // ceil(26 × 1.2)
      expect(state.clientCredits, 86 - 6);

      final day = state.rescheduleBooking(bookingId: 'b-005', newDateTime: at(1, 11));
      expect(day.valueOrNull!.credits, 26);
      expect(state.clientCredits, 86);
      expect(state.bookingById('b-005')!.startsAt, at(1, 11));
    });

    test('перенос с доплатой при нехватке кредитов отклоняется, запись не меняется', () {
      state.clientCredits = 3;
      final r = state.rescheduleBooking(bookingId: 'b-005', newDateTime: at(1, 18));
      expect(codeOf(r), BookingErrorCode.notEnoughCredits);
      expect(state.bookingById('b-005')!.startsAt, at(1, 8));
      expect(state.bookingById('b-005')!.credits, 26);
      expect(state.clientCredits, 3);
    });

    test('перенос на занятый слот и менее чем за 2 часа отклоняется', () {
      expect(
        book(
          salonId: 's-008',
          salonName: 'Elite Barber & Style',
          masterId: 'm-005',
          masterName: 'Тимур',
          serviceId: 'm-005-s2',
          serviceName: 'Моделирование бороды и усов',
          duration: 30,
          base: 18,
          sum: 80000,
          when: at(1, 12),
          method: PaymentMethods.inSalon,
        ).isSuccess,
        isTrue,
      );
      expect(
        codeOf(state.rescheduleBooking(bookingId: 'b-005', newDateTime: at(1, 12))),
        BookingErrorCode.slotUnavailable,
      );
      expect(codeOf(state.rescheduleBooking(bookingId: 'b-001', newDateTime: at(1, 15))), BookingErrorCode.tooLate);
    });

    test('отзыв: только после визита, один раз, в течение 7 дней', () {
      expect(
        codeOf(state.addReview(bookingId: 'b-001', rating: 5, tags: const [], comment: '')),
        BookingErrorCode.notCompleted,
      );
      expect(state.addReview(bookingId: 'b-002', rating: 5, tags: const ['a'], comment: 'ok').isSuccess, isTrue);
      expect(
        codeOf(state.addReview(bookingId: 'b-002', rating: 1, tags: const [], comment: 'повтор')),
        BookingErrorCode.alreadyReviewed,
      );
      expect(state.bookingById('b-002')!.reviewRating, 5);

      // Визит подтверждён по QR, но отзыв пишут через 8 дней
      expect(state.completeVisit('b-001').isSuccess, isTrue);
      clock.advance(const Duration(days: 8));
      expect(
        codeOf(state.addReview(bookingId: 'b-001', rating: 5, tags: const [], comment: '')),
        BookingErrorCode.reviewClosed,
      );
    });

    test('визит нельзя подтвердить дважды', () {
      expect(state.completeVisit('b-001').isSuccess, isTrue);
      expect(codeOf(state.completeVisit('b-001')), BookingErrorCode.notActive);
    });
  });

  group('Единый стор записей (задача 1)', () {
    test('запись клиента сразу видна мастеру, отмена отражается статусом', () {
      final created = book(when: at(0, 15)).valueOrNull!;
      final cabinet = MasterCabinetRepository();

      var today = cabinet.appointmentsForDate(wednesday);
      expect(today.map((a) => a.clientName), [
        'Алина Каримова',
        'Wazow',
        'Мадина Турсунова',
        'Санобар Алиева',
        'Wazow',
        'Нилуфар Рахимова',
      ]);
      expect(today.firstWhere((a) => a.bookingId == created.id).isActive, isTrue);

      expect(state.cancelBooking(created.id).isSuccess, isTrue);
      today = cabinet.appointmentsForDate(wednesday);
      expect(today.firstWhere((a) => a.bookingId == created.id).isCancelled, isTrue);
    });

    test('визит, подтверждённый по QR, попадает в доход мастера', () {
      final cabinet = MasterCabinetRepository();
      expect(cabinet.revenueForDay(wednesday), 0);

      final b001 = state.bookingById('b-001')!;
      final scan = state.validateVisitQr(state.visitQrToken(b001), ignoreTimeWindow: true);
      expect(scan.isSuccess, isTrue);
      expect(scan.booking!.status, BookingStatus.completed);

      expect(cabinet.revenueForDay(wednesday), 110000);
      expect(cabinet.visitsForMonth(0).first.clientName, 'Wazow');
      // Повторное сканирование тем же кодом не засчитывается
      expect(state.validateVisitQr(state.visitQrToken(b001), ignoreTimeWindow: true).isSuccess, isFalse);
      expect(cabinet.revenueForDay(wednesday), 110000);
    });

    test('доход по месяцам считается из завершённых визитов', () {
      final cabinet = MasterCabinetRepository();
      // 6 визитов других клиентов + завершённый визит самого клиента b-002 (он тоже был у Sabina)
      expect(cabinet.visitsForMonth(0).length, 7);
      expect(cabinet.revenueForMonth(0), 840000 + 110000);
      expect(cabinet.revenueForMonth(1), 560000);
    });

    test('стор неизменяем снаружи и оповещает слушателей', () {
      final store = BookingStore();
      var notified = 0;
      void listener() => notified++;
      store.addListener(listener);
      addTearDown(() => store.removeListener(listener));

      expect(() => store.all.add(store.all.first), throwsUnsupportedError);
      state.cancelBooking('b-005');
      expect(notified, greaterThan(0));
    });
  });

  group('Заморозка и пакеты (задачи 7 и 8)', () {
    test('заморозка заканчивается сама по времени', () {
      expect(state.freezeSubscription(7), isTrue);
      expect(state.isFrozen, isTrue);
      clock.advance(const Duration(days: 7, hours: 1));
      expect(state.isFrozen, isFalse);
      expect(state.creditsBlockReason(salonId: 's-001', credits: 10, dateTime: at(8, 12)), isNull);
      // Повторная заморозка раньше чем через 3 месяца запрещена
      expect(state.freezeBlockReason, isNotNull);
      expect(state.freezeSubscription(7), isFalse);
    });

    test('досрочная разморозка округляет неиспользованные дни вверх', () {
      final expiry = state.subscriptionExpiresAt;
      expect(state.freezeSubscription(10), isTrue);
      expect(state.subscriptionExpiresAt, expiry.add(const Duration(days: 10)));

      clock.advance(const Duration(days: 3, hours: 6)); // осталось 6 д 18 ч = 162 ч → 7 дней
      state.unfreezeSubscription();
      expect(state.isFrozen, isFalse);
      expect(state.subscriptionExpiresAt, expiry.add(const Duration(days: 3)));
    });

    test('K-01: при покупке переносится не больше 20% прежнего пакета', () {
      // Premium = 250 кр., лимит переноса 50; на балансе 86
      final preview = state.previewPurchase(120);
      expect((preview.carried, preview.burned, preview.total), (50, 36, 170));

      state.purchasePackage('Standart', 120);
      expect(state.clientCredits, 170);
      expect(state.subscriptionPlan, 'Standart');
    });

    test('K-01: небольшой остаток переносится целиком', () {
      state.clientCredits = 10;
      final preview = state.previewPurchase(60);
      expect((preview.carried, preview.burned, preview.total), (10, 0, 70));
    });
  });

  group('Выход из аккаунта (задача 9)', () {
    test('resetSession возвращает данные клиента, записи, избранное и график мастера', () {
      state.clientCredits = 1;
      state.toggleSalonFavorite('s-009');
      state.cancelBooking('b-005');
      book(when: at(1, 15));
      MasterCabinetRepository().setDayWorking(DateTime.monday, false);
      state.updateClientProfile(name: 'Другой', phone: '+998 1', birthDate: '01.01.2000', gender: 'Мужской');

      state.resetSession();

      expect(state.clientCredits, 86);
      expect(state.clientName, 'Wazow');
      expect(state.isSalonFavorite('s-009'), isFalse);
      expect(state.bookingById('b-005')!.status, BookingStatus.active);
      expect(state.bookings.length, 4);
      expect(MasterCabinetRepository().getDay(DateTime.monday).isWorking, isTrue);
    });
  });

  group('График мастера (задача 11)', () {
    test('regenerateSlots отбрасывает ручные слоты, пересекающиеся со сгенерированными или вне рабочего времени', () {
      final day = const DaySchedule(
        isWorking: true,
        workHours: TimeRange(540, 1170), // 09:00 – 19:30
        breaks: [],
        slots: [
          ScheduleSlot(range: TimeRange(570, 600), isCustom: true), // 09:30–10:00 пересекается с 09:00–10:00
          ScheduleSlot(range: TimeRange(1200, 1230), isCustom: true), // 20:00–20:30 вне рабочего времени
          ScheduleSlot(range: TimeRange(1140, 1170), isCustom: true), // 19:00–19:30 внутри и свободно
        ],
      ).regenerateSlots();

      final ranges = day.slots.map((s) => s.range.label).toList();
      expect(ranges.contains('09:30 – 10:00'), isFalse);
      expect(ranges.contains('20:00 – 20:30'), isFalse);
      expect(ranges.contains('19:00 – 19:30'), isTrue);
      expect(ranges.first, '09:00 – 10:00');
    });

    test('setDayWorking меняет только признак рабочего дня', () {
      final cabinet = MasterCabinetRepository();
      final before = cabinet.getDay(DateTime.tuesday);
      cabinet.setDayWorking(DateTime.tuesday, false);
      final after = cabinet.getDay(DateTime.tuesday);
      expect(after.isWorking, isFalse);
      expect(after.workHours.label, before.workHours.label);
      expect(after.slots.length, before.slots.length);
      expect(after.breaks.length, before.breaks.length);
    });
  });
}
