import '../models/booking_rules.dart';
import '../utils/clock.dart';
import 'booking_store.dart';
import 'master_cabinet_repository.dart';
import 'masters_repository.dart';

/// Свободные слоты для записи. Единственное место, где решается «можно ли записаться на это время».
///
/// Слот доступен, если одновременно выполняется всё:
/// - у мастера в этот день рабочий день, и услуга целиком помещается в рабочие часы;
/// - слот открыт мастером (включён), услуга не пересекает выключенные слоты и перерывы;
/// - мастер не занят другой записью (отменённые не занимают время);
/// - слот не в прошлом и начинается не раньше чем через [BookingRules.minLeadMinutes].
///
/// Для «Любой мастер» берётся объединение слотов мастеров салона, оказывающих услугу.
/// У салона без мастеров в каталоге используется общий график по умолчанию.
///
/// [BACKEND NOTE]: превратится в GET /api/v1/slots?salon=&master=&service=&date=
class SlotService {
  static final SlotService _instance = SlotService._internal();
  factory SlotService() => _instance;
  SlotService._internal();

  final _masters = MastersRepository();
  final _cabinet = MasterCabinetRepository();
  final _store = BookingStore();

  /// Мастера, чьё время учитывается: конкретный мастер, объединение подходящих мастеров
  /// или `[null]` — салон без мастеров (общий календарь салона). Пустой список — записаться нельзя.
  List<String?> _resources({required String salonId, String? masterId, String? serviceId}) {
    final salonMasters = _masters.getMastersForSalon(salonId);
    if (masterId != null) {
      final exists = salonMasters.any((m) => m.id == masterId);
      return exists ? [masterId] : const [];
    }
    if (salonMasters.isEmpty) return const [null];
    return [
      for (final m in salonMasters)
        if (serviceId == null || m.offers(serviceId)) m.id,
    ];
  }

  /// Стартовые времена, доступные на [date] для услуги длительностью [durationMinutes].
  /// [excludeBookingId] — не считать занятой эту запись (при её переносе).
  List<DateTime> availableSlots({
    required String salonId,
    String? masterId,
    String? serviceId,
    required DateTime date,
    required int durationMinutes,
    String? excludeBookingId,
  }) {
    final result = <DateTime>{};
    for (final resource in _resources(salonId: salonId, masterId: masterId, serviceId: serviceId)) {
      result.addAll(
        _slotsFor(
          salonId: salonId,
          masterId: resource,
          date: date,
          durationMinutes: durationMinutes,
          excludeBookingId: excludeBookingId,
        ),
      );
    }
    return result.toList()..sort();
  }

  bool isAvailable({
    required String salonId,
    String? masterId,
    String? serviceId,
    required DateTime startsAt,
    required int durationMinutes,
    String? excludeBookingId,
  }) {
    return availableSlots(
      salonId: salonId,
      masterId: masterId,
      serviceId: serviceId,
      date: startsAt,
      durationMinutes: durationMinutes,
      excludeBookingId: excludeBookingId,
    ).contains(startsAt);
  }

  /// Для «Любой мастер»: все свободные на это время мастера (по броням и графику), в порядке каталога.
  /// Пустой список — свободного нет; `[null]` — у салона нет мастеров (запись на салон целиком).
  /// Чужие удержания здесь не учитываются — их знает слой удержаний и выбирает из этого списка.
  List<String?> freeMasterIds({
    required String salonId,
    String? serviceId,
    required DateTime startsAt,
    required int durationMinutes,
    String? excludeBookingId,
  }) {
    final result = <String?>[];
    for (final resource in _resources(salonId: salonId, serviceId: serviceId)) {
      if (resource == null) return const [null];
      final free = _slotsFor(
        salonId: salonId,
        masterId: resource,
        date: startsAt,
        durationMinutes: durationMinutes,
        excludeBookingId: excludeBookingId,
      );
      if (free.contains(startsAt)) result.add(resource);
    }
    return result;
  }

  /// Для «Любой мастер»: первый свободный мастер на это время. `null` — свободного нет
  /// или у салона нет мастеров (запись идёт на салон целиком).
  String? resolveMasterId({
    required String salonId,
    String? serviceId,
    required DateTime startsAt,
    required int durationMinutes,
    String? excludeBookingId,
  }) {
    for (final resource in _resources(salonId: salonId, serviceId: serviceId)) {
      if (resource == null) return null;
      final free = _slotsFor(
        salonId: salonId,
        masterId: resource,
        date: startsAt,
        durationMinutes: durationMinutes,
        excludeBookingId: excludeBookingId,
      );
      if (free.contains(startsAt)) return resource;
    }
    return null;
  }

  List<DateTime> _slotsFor({
    required String salonId,
    required String? masterId,
    required DateTime date,
    required int durationMinutes,
    String? excludeBookingId,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    final schedule = masterId == null ? MasterCabinetRepository.defaultDay : _cabinet.dayFor(masterId, day.weekday);
    if (!schedule.isWorking) return const [];

    final earliest = AppClock.now().add(const Duration(minutes: BookingRules.minLeadMinutes));
    final busy = _store.occupying(salonId: salonId, masterId: masterId).where((b) => b.id != excludeBookingId).toList();

    DateTime at(int minutes) => day.add(Duration(minutes: minutes));

    final result = <DateTime>[];
    for (final slot in schedule.slots) {
      if (!slot.enabled) continue;
      final start = slot.range.start;
      final interval = TimeRange(start, start + durationMinutes);
      if (start < schedule.workHours.start || interval.end > schedule.workHours.end) continue;
      if (at(start).isBefore(earliest)) continue;
      if (schedule.isInBreak(interval)) continue;
      // Услуга не должна заходить на закрытый мастером слот
      if (schedule.slots.any((s) => !s.enabled && s.range.overlaps(interval))) continue;
      final from = at(interval.start);
      final to = at(interval.end);
      if (busy.any((b) => b.overlaps(from, to))) continue;
      result.add(from);
    }
    return result;
  }
}
