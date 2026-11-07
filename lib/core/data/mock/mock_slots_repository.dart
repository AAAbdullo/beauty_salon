import 'package:flutter/foundation.dart' show visibleForTesting;
import '../../models/booking_error.dart';
import '../../models/booking_rules.dart';
import '../../services/slot_service.dart';
import '../../utils/clock.dart';
import '../../utils/result.dart';
import '../../utils/uuid.dart';
import '../repositories/slots_repository.dart';
import 'mock_network.dart';

/// Мок слотов и их удержания. Удержания хранятся «на сервере» (в памяти) со сроком жизни по часам приложения.
class MockSlotsRepository implements SlotsRepository {
  MockSlotsRepository({MockNetwork? network, SlotService? slots, this.holdTtl = const Duration(minutes: 10)})
    : _network = network ?? MockNetwork(),
      _slots = slots ?? SlotService();

  final MockNetwork _network;
  final SlotService _slots;

  /// ТЗ M-08: слот удерживается 10 минут
  final Duration holdTtl;

  final Map<String, SlotHold> _holds = {};

  // --- серверная часть, которой пользуются другие моки ---------------------------------

  /// Действующее удержание (истёкшие удаляются)
  SlotHold? activeHold(String id) {
    final hold = _holds[id];
    if (hold == null) return null;
    if (!AppClock.now().isBefore(hold.expiresAt)) {
      _holds.remove(id);
      return null;
    }
    return hold;
  }

  /// Удержание использовано (запись создана)
  void consumeHold(String id) => _holds.remove(id);

  /// Продлить удержание на время оплаты
  SlotHold? extendHold(String id, Duration by) {
    final hold = activeHold(id);
    if (hold == null) return null;
    final until = AppClock.now().add(by);
    if (!until.isAfter(hold.expiresAt)) return hold;
    return _holds[id] = hold.copyWith(expiresAt: until);
  }

  /// Удалить истёкшие удержания разом. Нельзя удалять их во время обхода словаря
  /// (`activeHold` внутри `keys.map(...)` давал ConcurrentModificationError), поэтому чистка — отдельным шагом.
  void _purgeExpired() {
    final now = AppClock.now();
    _holds.removeWhere((_, hold) => !now.isBefore(hold.expiresAt));
  }

  int get activeHoldsCount {
    _purgeExpired();
    return _holds.length;
  }

  /// Есть ли действующее удержание этого мастера (или салона без мастеров), пересекающееся со слотом
  bool _hasHoldConflict(String salonId, String? masterId, DateTime startsAt, DateTime endsAt) {
    _purgeExpired();
    return _holds.values
        .where((h) => h.salonId == salonId && h.masterId == masterId)
        .any(
          (h) => h.startsAt.isBefore(endsAt) && startsAt.isBefore(h.startsAt.add(Duration(minutes: h.durationMinutes))),
        );
  }

  /// Первый кандидат без чужого удержания. `found == false` — все кандидаты удерживаются.
  /// Кандидат `null` означает салон без мастеров (общий календарь), поэтому «не найден» передаётся отдельным флагом.
  @visibleForTesting
  static ({bool found, String? masterId}) pickUnheldMaster(
    List<String?> candidates, {
    required bool Function(String? candidate) isHeld,
  }) {
    for (final candidate in candidates) {
      if (!isHeld(candidate)) return (found: true, masterId: candidate);
    }
    return (found: false, masterId: null);
  }

  // --- интерфейс -------------------------------------------------------------------------

  @override
  Future<List<DateTime>> availableSlots({
    required String salonId,
    String? masterId,
    String? serviceId,
    required DateTime date,
    required int durationMinutes,
    String? excludeBookingId,
  }) => _network(
    () => _slots.availableSlots(
      salonId: salonId,
      masterId: masterId,
      serviceId: serviceId,
      date: date,
      durationMinutes: durationMinutes,
      excludeBookingId: excludeBookingId,
    ),
  );

  @override
  Future<Map<DateTime, List<DateTime>>> availableSlotsForDays({
    required String salonId,
    String? masterId,
    String? serviceId,
    required List<DateTime> days,
    required int durationMinutes,
    String? excludeBookingId,
  }) => _network(
    () => {
      for (final day in days)
        DateTime(day.year, day.month, day.day): _slots.availableSlots(
          salonId: salonId,
          masterId: masterId,
          serviceId: serviceId,
          date: day,
          durationMinutes: durationMinutes,
          excludeBookingId: excludeBookingId,
        ),
    },
  );

  @override
  Future<Result<SlotHold, BookingError>> holdSlot({
    required String salonId,
    String? masterId,
    required String serviceId,
    required DateTime startsAt,
    required int durationMinutes,
    String? replaceHoldId,
  }) => _network<Result<SlotHold, BookingError>>(() {
    if (replaceHoldId != null) _holds.remove(replaceHoldId);
    _purgeExpired(); // истёкшие удержания не мешают новому и не ломают обход ниже

    final now = AppClock.now();
    if (startsAt.isBefore(now.add(const Duration(minutes: BookingRules.minLeadMinutes)))) {
      return const Result.failure(
        BookingError(BookingErrorCode.inPast, 'Это время уже прошло или начинается слишком скоро.'),
      );
    }
    if (!_slots.isAvailable(
      salonId: salonId,
      masterId: masterId,
      serviceId: serviceId,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
    )) {
      return const Result.failure(
        BookingError(BookingErrorCode.slotUnavailable, 'Это время недоступно. Выберите другой слот.'),
      );
    }

    // Мастер, за которым закрепляется слот. «Любой мастер» → первый свободный, у кого этот слот
    // не удерживает другой клиент; если выбран конкретный мастер — только он.
    final endsAt = startsAt.add(Duration(minutes: durationMinutes));
    final candidates = masterId != null
        ? <String?>[masterId]
        : _slots.freeMasterIds(
            salonId: salonId,
            serviceId: serviceId,
            startsAt: startsAt,
            durationMinutes: durationMinutes,
          );
    final pick = pickUnheldMaster(
      candidates,
      isHeld: (candidate) => _hasHoldConflict(salonId, candidate, startsAt, endsAt),
    );
    final resolvedMaster = pick.masterId; // для салона без мастеров это null — запись на салон целиком
    if (!pick.found) {
      return const Result.failure(
        BookingError(
          BookingErrorCode.slotUnavailable,
          'Этот слот сейчас удерживает другой клиент. Выберите другое время.',
        ),
      );
    }

    final hold = SlotHold(
      id: Uuid.v4(),
      salonId: salonId,
      masterId: resolvedMaster,
      serviceId: serviceId,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      expiresAt: now.add(holdTtl),
    );
    _holds[hold.id] = hold;
    return Result.success(hold);
  });

  @override
  Future<void> releaseHold(String holdId) => _network(() => _holds.remove(holdId));
}
