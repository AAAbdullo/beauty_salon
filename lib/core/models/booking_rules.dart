/// Бизнес-правила записей и абонемента (ТЗ). Единственное место, где живут эти числа.
class BookingRules {
  BookingRules._();

  /// Бесплатная отмена/перенос не позднее чем за 2 часа (решение заказчика; в ТЗ K-04 — 4 часа)
  static const freeCancelMinutes = 120;

  /// Записаться можно не позднее чем за 30 минут до начала
  static const minLeadMinutes = 30;

  /// K-03: не более 4 записей за кредиты в один салон в месяц
  static const maxCreditBookingsPerSalonMonth = 4;

  /// M-13: отзыв — в течение 7 дней после визита
  static const reviewWindowDays = 7;

  /// K-08: заморозка 7–30 дней, не чаще 1 раза в 3 месяца
  static const freezeMinDays = 7;
  static const freezeMaxDays = 30;
  static const freezeCooldownDays = 90;

  /// K-01: при продлении переносится не больше 20% объёма прежнего пакета
  static const rolloverShare = 0.2;

  /// QR визита: код живёт 60 с (+15 с на сетевую задержку), окно визита −30 / +60 мин
  static const qrLifetimeSeconds = 60;
  static const qrGraceSeconds = 15;
  static const qrEarlyMinutes = 30;
  static const qrLateMinutes = 60;
}
