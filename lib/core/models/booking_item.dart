import 'package:flutter/foundation.dart';
import '../utils/clock.dart';
import '../utils/formatters.dart';
import 'booking_rules.dart';

/// Способы оплаты записи (строки совпадают с будущим полем `payment_method` API)
class PaymentMethods {
  static const credits = 'Кредиты';
  static const online = 'Онлайн оплата';
  static const inSalon = 'В салоне';
}

/// Статус записи. Строковые значения (`wire`) совпадают с будущим полем `status` API.
enum BookingStatus {
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  final String wire;

  const BookingStatus(this.wire);

  static BookingStatus fromWire(String value) => BookingStatus.values.firstWhere(
    (s) => s.wire == value,
    orElse: () => throw ArgumentError('Unknown status: $value'),
  );
}

/// Запись на услугу. Модель неизменяемая: любое изменение — это новый объект через [copyWith],
/// который стор подставляет вместо старого и сообщает слушателям.
///
/// Названия салона, услуги, мастера и клиента — снимок на момент записи (для отображения);
/// связи с каталогом держатся только по id.
@immutable
class BookingItem {
  final String id;
  final String clientId;
  final String clientName;

  /// Фото клиента (asset) — если есть
  final String? clientAvatar;
  final String salonId;
  final String salonName;
  final String serviceId;
  final String serviceName;

  /// `null` — у салона нет мастеров в каталоге (запись на салон целиком)
  final String? masterId;
  final String masterName;
  final int durationMinutes;

  /// Дата и время визита (единственный источник даты — строк «Сегодня»/«28 сен» больше нет)
  final DateTime startsAt;

  /// Цена услуги в кредитах без коэффициента слота
  final int baseCredits;

  /// Кредиты, зарезервированные под эту запись (базовая цена × k_slot своего слота)
  final int credits;
  final int sumPrice;
  final String paymentMethod;

  /// Квитанция онлайн-оплаты, по которой при отмене возвращаются деньги (`null` — оплаты не было)
  final String? paymentReceiptId;

  /// Сколько фактически оплачено онлайн (депозит или полная сумма); `null` — неизвестно или оплаты не было
  final int? paidAmount;
  final BookingStatus status;
  final int? reviewRating;
  final List<String>? reviewTags;
  final String? reviewComment;
  final DateTime? reviewDate;

  BookingItem({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientAvatar,
    required this.salonId,
    required this.salonName,
    required this.serviceId,
    required this.serviceName,
    this.masterId,
    required this.masterName,
    this.durationMinutes = 60,
    required this.startsAt,
    required this.baseCredits,
    required this.credits,
    required this.sumPrice,
    required this.paymentMethod,
    this.paymentReceiptId,
    this.paidAmount,
    this.status = BookingStatus.active,
    this.reviewRating,
    List<String>? reviewTags,
    this.reviewComment,
    this.reviewDate,
  }) : reviewTags = reviewTags == null ? null : List.unmodifiable(reviewTags);

  BookingItem copyWith({
    String? masterId,
    String? masterName,
    DateTime? startsAt,
    int? credits,
    BookingStatus? status,
    int? reviewRating,
    List<String>? reviewTags,
    String? reviewComment,
    DateTime? reviewDate,
  }) {
    return BookingItem(
      id: id,
      clientId: clientId,
      clientName: clientName,
      clientAvatar: clientAvatar,
      salonId: salonId,
      salonName: salonName,
      serviceId: serviceId,
      serviceName: serviceName,
      masterId: masterId ?? this.masterId,
      masterName: masterName ?? this.masterName,
      durationMinutes: durationMinutes,
      startsAt: startsAt ?? this.startsAt,
      baseCredits: baseCredits,
      credits: credits ?? this.credits,
      sumPrice: sumPrice,
      paymentMethod: paymentMethod,
      paymentReceiptId: paymentReceiptId,
      paidAmount: paidAmount,
      status: status ?? this.status,
      reviewRating: reviewRating ?? this.reviewRating,
      reviewTags: reviewTags ?? this.reviewTags,
      reviewComment: reviewComment ?? this.reviewComment,
      reviewDate: reviewDate ?? this.reviewDate,
    );
  }

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  /// Длительность для отображения: «60 мин»
  String get durationLabel => '$durationMinutes мин';

  /// Подпись дня визита («Сегодня», «Завтра», «12 ноя») — считается от [startsAt]
  String get date => Formatters.dayLabel(startsAt);

  /// Время визита «HH:mm»
  String get time => Formatters.time(startsAt);

  bool get isPaidWithCredits => paymentMethod == PaymentMethods.credits;

  /// Запись занимает время мастера (отменённые не занимают)
  bool get occupiesTime => status != BookingStatus.cancelled;

  /// Пересекается ли запись по времени с интервалом [from, to)
  bool overlaps(DateTime from, DateTime to) => startsAt.isBefore(to) && from.isBefore(endsAt);

  /// Цена в том виде, в котором её оплатил клиент
  String get priceLabel => isPaidWithCredits ? Formatters.formatCredits(credits) : Formatters.formatSum(sumPrice);

  /// Проверка правила сервиса: отмена разрешена строго не менее чем за 2 часа (>= 120 минут)
  /// Если осталось < 120 мин (например, 1 ч 59 мин или меньше), отмена строго блокируется!
  bool get canCancel {
    final diff = startsAt.difference(AppClock.now());
    return diff.inMinutes >= BookingRules.freeCancelMinutes;
  }

  /// Перенос подчиняется тому же правилу 2 часов, что и отмена
  bool get canReschedule => canCancel;

  Duration get timeUntilAppointment => startsAt.difference(AppClock.now());

  /// ТЗ M-13: отзыв можно оставить только после визита и не позднее 7 дней
  bool get isReviewWindowOpen =>
      status == BookingStatus.completed && AppClock.now().difference(startsAt).inDays < BookingRules.reviewWindowDays;
}
