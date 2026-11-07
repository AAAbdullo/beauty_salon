import '../../models/booking_error.dart';
import '../../utils/result.dart';

/// Временное удержание слота за клиентом на время оформления записи (ТЗ M-08: 10 минут).
/// Срок жизни определяет сервер ([expiresAt]); клиентский таймер лишь отсчитывает до него.
class SlotHold {
  final String id;
  final String salonId;

  /// Мастер, закреплённый за слотом (для «Любой мастер» — выбранный сервером); `null` — запись на салон
  final String? masterId;
  final String serviceId;
  final DateTime startsAt;
  final int durationMinutes;
  final DateTime expiresAt;

  const SlotHold({
    required this.id,
    required this.salonId,
    required this.masterId,
    required this.serviceId,
    required this.startsAt,
    required this.durationMinutes,
    required this.expiresAt,
  });

  SlotHold copyWith({DateTime? expiresAt}) => SlotHold(
    id: id,
    salonId: salonId,
    masterId: masterId,
    serviceId: serviceId,
    startsAt: startsAt,
    durationMinutes: durationMinutes,
    expiresAt: expiresAt ?? this.expiresAt,
  );
}

/// Свободные слоты и их удержание.
/// [BACKEND NOTE]: GET /api/v1/slots, POST /api/v1/slots/hold, DELETE /api/v1/slots/hold/:id
abstract interface class SlotsRepository {
  Future<List<DateTime>> availableSlots({
    required String salonId,
    String? masterId,
    String? serviceId,
    required DateTime date,
    required int durationMinutes,
    String? excludeBookingId,
  });

  /// Слоты сразу на несколько дней (ключ — дата без времени)
  Future<Map<DateTime, List<DateTime>>> availableSlotsForDays({
    required String salonId,
    String? masterId,
    String? serviceId,
    required List<DateTime> days,
    required int durationMinutes,
    String? excludeBookingId,
  });

  /// Закрепить слот за клиентом. [replaceHoldId] — прежнее удержание, которое освобождается атомарно.
  Future<Result<SlotHold, BookingError>> holdSlot({
    required String salonId,
    String? masterId,
    required String serviceId,
    required DateTime startsAt,
    required int durationMinutes,
    String? replaceHoldId,
  });

  Future<void> releaseHold(String holdId);
}
