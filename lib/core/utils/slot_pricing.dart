/// Цена слота в кредитах: базовая цена услуги × коэффициент слота (k_slot, ТЗ).
///
/// Вечерние слоты (с 18:00) стоят на 20% дороже. Единственное место, где считается цена слота:
/// её используют и экран записи, и перенос записи.
class SlotPricing {
  SlotPricing._();

  static const eveningStartHour = 18;
  static const eveningFactor = 1.2;

  static double kSlot(DateTime startsAt) => startsAt.hour >= eveningStartHour ? eveningFactor : 1.0;

  /// Цена в кредитах для слота, начинающегося в [startsAt]
  static int credits(int baseCredits, DateTime startsAt) => (baseCredits * kSlot(startsAt)).ceil();
}
