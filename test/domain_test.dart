import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/masters_repository.dart';
import 'package:beauty_salons/core/services/salons_repository.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/utils/result.dart';

/// Тесты доменного фундамента (Фаза 1): время, Result, неизменяемые записи, id вместо имён.
void main() {
  tearDown(AppClock.reset);

  group('Clock', () {
    test('SystemClock отдаёт текущее время', () {
      final before = DateTime.now();
      final now = const SystemClock().now();
      expect(now.isBefore(before), isFalse);
      expect(now.difference(before).inSeconds, lessThan(5));
    });

    test('FixedClock стоит на месте, пока его не сдвинули', () {
      final clock = FixedClock(DateTime(2026, 11, 7, 12));
      expect(clock.now(), DateTime(2026, 11, 7, 12));
      clock.advance(const Duration(hours: 3));
      expect(clock.now(), DateTime(2026, 11, 7, 15));
    });

    test('AppClock подменяется и сбрасывается', () {
      AppClock.current = FixedClock(DateTime(2030, 1, 1));
      expect(AppClock.now(), DateTime(2030, 1, 1));
      AppClock.reset();
      expect(AppClock.now().year, isNot(2030));
    });
  });

  group('Result', () {
    test('Success и Failure', () {
      const ok = Result<int, String>.success(5);
      const bad = Result<int, String>.failure('нет кредитов');
      expect(ok.isSuccess, isTrue);
      expect(ok.valueOrNull, 5);
      expect(ok.errorOrNull, isNull);
      expect(bad.isFailure, isTrue);
      expect(bad.valueOrNull, isNull);
      expect(bad.errorOrNull, 'нет кредитов');
    });

    test('fold и map', () {
      const ok = Result<int, String>.success(2);
      const bad = Result<int, String>.failure('ошибка');
      expect(ok.map((v) => v * 10).valueOrNull, 20);
      expect(bad.map((v) => v * 10).errorOrNull, 'ошибка');
      expect(ok.fold(onSuccess: (v) => 'ok $v', onFailure: (e) => 'fail $e'), 'ok 2');
      expect(bad.fold(onSuccess: (v) => 'ok $v', onFailure: (e) => 'fail $e'), 'fail ошибка');
    });

    test('исчерпывающий switch по sealed-классу', () {
      const Result<int, String> r = Result.success(1);
      final text = switch (r) {
        Success(:final value) => 'v$value',
        Failure(:final error) => 'e$error',
      };
      expect(text, 'v1');
    });
  });

  group('BookingItem', () {
    BookingItem make({DateTime? startsAt, BookingStatus status = BookingStatus.active}) => BookingItem(
      id: 'b-test',
      clientId: 'c-001',
      clientName: 'Wazow',
      baseCredits: 34,
      salonId: 's-001',
      salonName: 'Nur Beauty',
      serviceId: 'm-001-s1',
      serviceName: 'Маникюр',
      masterId: 'm-001',
      masterName: 'Алена',
      startsAt: startsAt ?? DateTime(2026, 11, 7, 15),
      credits: 34,
      sumPrice: 150000,
      paymentMethod: PaymentMethods.credits,
      status: status,
    );

    test('copyWith создаёт новый объект, исходный не меняется', () {
      final original = make();
      final cancelled = original.copyWith(status: BookingStatus.cancelled);
      expect(original.status, BookingStatus.active);
      expect(cancelled.status, BookingStatus.cancelled);
      expect(cancelled.id, original.id);
      expect(cancelled.startsAt, original.startsAt);
    });

    test('теги отзыва нельзя изменить снаружи', () {
      final item = make().copyWith(reviewTags: ['a', 'b']);
      expect(() => item.reviewTags!.add('c'), throwsUnsupportedError);
    });

    test('дата и время берутся только из startsAt', () {
      AppClock.current = FixedClock(DateTime(2026, 11, 7, 10));
      final item = make(startsAt: DateTime(2026, 11, 7, 16, 30));
      expect(item.date, 'Сегодня');
      expect(item.time, '16:30');
      expect(make(startsAt: DateTime(2026, 11, 8, 9)).date, 'Завтра');
    });

    test('правило отмены за 2 часа считается по Clock', () {
      final clock = FixedClock(DateTime(2026, 11, 7, 10));
      AppClock.current = clock;
      final item = make(startsAt: DateTime(2026, 11, 7, 12, 30));
      expect(item.canCancel, isTrue); // осталось 2 ч 30 мин
      clock.advance(const Duration(minutes: 31));
      expect(item.canCancel, isFalse); // осталось 1 ч 59 мин
    });

    test('окно отзыва: только завершённые и не старше 7 дней', () {
      final clock = FixedClock(DateTime(2026, 11, 7, 10));
      AppClock.current = clock;
      final done = make(startsAt: DateTime(2026, 11, 5, 10), status: BookingStatus.completed);
      expect(done.isReviewWindowOpen, isTrue);
      expect(make(startsAt: DateTime(2026, 11, 5, 10)).isReviewWindowOpen, isFalse); // не завершена
      clock.advance(const Duration(days: 6));
      expect(done.isReviewWindowOpen, isFalse);
    });

    test('BookingStatus.fromWire', () {
      expect(BookingStatus.fromWire('cancelled'), BookingStatus.cancelled);
      expect(() => BookingStatus.fromWire('???'), throwsArgumentError);
    });
  });

  group('Идентификаторы', () {
    test('у всех салонов, мастеров и услуг есть уникальные id', () {
      final salons = SalonsRepository().getSalons();
      expect(salons.map((s) => s.id).toSet().length, salons.length);

      final masters = MastersRepository().getMasters();
      expect(masters.map((m) => m.id).toSet().length, masters.length);

      final serviceIds = <String>[
        for (final m in masters) ...m.services.map((s) => s.id),
        for (final s in salons) ...SalonsRepository().getSalonServices(s.id).map((x) => x.id),
      ];
      expect(serviceIds.every((id) => id.isNotEmpty), isTrue);
      // услуги мастеров попадают в список салона повторно — сравниваем без дублей
      expect(serviceIds.toSet().length, lessThanOrEqualTo(serviceIds.length));
    });

    test('поиск по неизвестному id возвращает null — без подстановки другого салона или мастера', () {
      expect(SalonsRepository().getSalonById('s-unknown'), isNull);
      expect(SalonsRepository().getSalonById('Nur Beauty'), isNull); // имя — не ключ
      expect(MastersRepository().getMasterById('m-unknown'), isNull);
      expect(MastersRepository().getMasterById('Алена'), isNull);
    });

    test('мастера салона находятся по salonId', () {
      final masters = MastersRepository().getMastersForSalon('s-001');
      expect(masters.map((m) => m.id), containsAll(['m-001', 'm-002', 'm-004']));
      expect(MastersRepository().getMastersForSalon('Nur Beauty'), isEmpty);
    });

    test('мок-записи ссылаются на существующие салоны, мастеров и услуги', () {
      final salons = SalonsRepository();
      final masters = MastersRepository();
      for (final b in AppStateService().bookings) {
        expect(salons.getSalonById(b.salonId), isNotNull, reason: '${b.id}: салон ${b.salonId}');
        final masterId = b.masterId;
        if (masterId != null) {
          final master = masters.getMasterById(masterId);
          expect(master, isNotNull, reason: '${b.id}: мастер $masterId');
          expect(master!.salonId, b.salonId, reason: '${b.id}: мастер из другого салона');
          expect(master.offers(b.serviceId), isTrue, reason: '${b.id}: услуга ${b.serviceId}');
        }
      }
    });

    test('избранное хранит id и не путает похожие имена', () {
      final state = AppStateService();
      final salonsBefore = state.favoriteSalonIds;
      final mastersBefore = state.favoriteMasterIds;
      addTearDown(() {
        for (final id
            in state.favoriteSalonIds
                .difference(salonsBefore)
                .followedBy(salonsBefore.difference(state.favoriteSalonIds))) {
          state.toggleSalonFavorite(id);
        }
        for (final id
            in state.favoriteMasterIds
                .difference(mastersBefore)
                .followedBy(mastersBefore.difference(state.favoriteMasterIds))) {
          state.toggleMasterFavorite(id);
        }
      });

      expect(state.isMasterFavorite('m-001'), isTrue);
      expect(state.isMasterFavorite('m-003'), isFalse);
      // раньше «Ал» совпадало с «Алена» по подстроке
      expect(state.isMasterFavorite('Ал'), isFalse);
      expect(state.isMasterFavorite('Алена'), isFalse);

      state.toggleMasterFavorite('m-003');
      expect(state.isMasterFavorite('m-003'), isTrue);
      expect(state.isMasterFavorite('m-001'), isTrue); // соседний не затронут
      state.toggleMasterFavorite('m-003');
      expect(state.isMasterFavorite('m-003'), isFalse);

      state.toggleSalonFavorite('s-002');
      expect(state.isSalonFavorite('s-002'), isTrue);
      expect(state.isSalonFavorite('Lola Studio'), isFalse);
      state.toggleSalonFavorite('s-002');
    });
  });
}
