/// Черновик записи: всё, что клиент выбрал на экране бронирования (M-08),
/// до создания записи (оплата кредитами / онлайн / в салоне).
///
/// БЭКЕНД-ИНТЕГРАЦИЯ: соответствует телу POST /api/v1/bookings.
class BookingDraft {
  final String salonId;
  final String salonName;
  final String serviceId;
  final String serviceName;
  final String durationLabel;

  /// `null` — клиент выбрал «Любой мастер»
  final String? masterId;

  /// Короткое имя мастера или «Любой мастер» (для отображения)
  final String masterName;
  final DateTime dateTime;

  /// Цена в кредитах с учётом коэффициента слота (k_slot)
  final int credits;
  final int sumPrice;

  const BookingDraft({
    required this.salonId,
    required this.salonName,
    required this.serviceId,
    required this.serviceName,
    required this.durationLabel,
    this.masterId,
    required this.masterName,
    required this.dateTime,
    required this.credits,
    required this.sumPrice,
  });

  /// Депозит при онлайн-оплате — 20% стоимости, округлённо до 1 000 сум
  int get depositSum => ((sumPrice * 0.2) / 1000).round() * 1000;
}
