import '../utils/slot_pricing.dart';

/// Черновик записи: всё, что клиент выбрал на экране бронирования (M-08),
/// до создания записи (оплата кредитами / онлайн / в салоне).
///
/// БЭКЕНД-ИНТЕГРАЦИЯ: соответствует телу POST /api/v1/bookings.
class BookingDraft {
  final String salonId;
  final String salonName;
  final String serviceId;
  final String serviceName;
  final int durationMinutes;

  /// `null` — клиент выбрал «Любой мастер»
  final String? masterId;

  /// Короткое имя мастера или «Любой мастер» (для отображения)
  final String masterName;
  final DateTime dateTime;

  /// Цена услуги в кредитах без коэффициента слота
  final int baseCredits;
  final int sumPrice;

  const BookingDraft({
    required this.salonId,
    required this.salonName,
    required this.serviceId,
    required this.serviceName,
    required this.durationMinutes,
    this.masterId,
    required this.masterName,
    required this.dateTime,
    required this.baseCredits,
    required this.sumPrice,
  });

  /// Длительность для отображения: «60 мин»
  String get durationLabel => '$durationMinutes мин';

  /// Цена в кредитах с учётом коэффициента слота (k_slot)
  int get credits => SlotPricing.credits(baseCredits, dateTime);

  /// Депозит при онлайн-оплате — 20% стоимости, округлённо до 1 000 сум
  int get depositSum => ((sumPrice * 0.2) / 1000).round() * 1000;
}
