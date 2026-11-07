import 'package:flutter/foundation.dart';
import '../utils/clock.dart';
import '../utils/formatters.dart';

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

  static BookingStatus fromWire(String value) =>
      BookingStatus.values.firstWhere((s) => s.wire == value, orElse: () => throw ArgumentError('Unknown status: $value'));
}

/// Запись на услугу. Модель неизменяемая: любое изменение — это новый объект через [copyWith],
/// который стор подставляет вместо старого и сообщает слушателям.
///
/// Названия салона, услуги и мастера — снимок на момент записи (для отображения);
/// связи с каталогом держатся только по id.
@immutable
class BookingItem {
  final String id;
  final String salonId;
  final String salonName;
  final String serviceId;
  final String serviceName;

  /// `null` — клиент выбрал «Любой мастер»
  final String? masterId;
  final String masterName;
  final String durationLabel;

  /// Дата и время визита (единственный источник даты — строк «Сегодня»/«28 сен» больше нет)
  final DateTime startsAt;
  final int credits;
  final int sumPrice;
  final String paymentMethod;
  final BookingStatus status;
  final int? reviewRating;
  final List<String>? reviewTags;
  final String? reviewComment;
  final DateTime? reviewDate;

  BookingItem({
    required this.id,
    required this.salonId,
    required this.salonName,
    required this.serviceId,
    required this.serviceName,
    this.masterId,
    required this.masterName,
    this.durationLabel = '60 мин',
    required this.startsAt,
    required this.credits,
    required this.sumPrice,
    required this.paymentMethod,
    this.status = BookingStatus.active,
    this.reviewRating,
    List<String>? reviewTags,
    this.reviewComment,
    this.reviewDate,
  }) : reviewTags = reviewTags == null ? null : List.unmodifiable(reviewTags);

  BookingItem copyWith({
    String? id,
    String? salonId,
    String? salonName,
    String? serviceId,
    String? serviceName,
    String? masterId,
    String? masterName,
    String? durationLabel,
    DateTime? startsAt,
    int? credits,
    int? sumPrice,
    String? paymentMethod,
    BookingStatus? status,
    int? reviewRating,
    List<String>? reviewTags,
    String? reviewComment,
    DateTime? reviewDate,
  }) {
    return BookingItem(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      salonName: salonName ?? this.salonName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      masterId: masterId ?? this.masterId,
      masterName: masterName ?? this.masterName,
      durationLabel: durationLabel ?? this.durationLabel,
      startsAt: startsAt ?? this.startsAt,
      credits: credits ?? this.credits,
      sumPrice: sumPrice ?? this.sumPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      reviewRating: reviewRating ?? this.reviewRating,
      reviewTags: reviewTags ?? this.reviewTags,
      reviewComment: reviewComment ?? this.reviewComment,
      reviewDate: reviewDate ?? this.reviewDate,
    );
  }

  /// Подпись дня визита («Сегодня», «Завтра», «12 ноя») — считается от [startsAt]
  String get date => Formatters.dayLabel(startsAt);

  /// Время визита «HH:mm»
  String get time => Formatters.time(startsAt);

  bool get isPaidWithCredits => paymentMethod == PaymentMethods.credits;

  /// Цена в том виде, в котором её оплатил клиент
  String get priceLabel => isPaidWithCredits ? Formatters.formatCredits(credits) : Formatters.formatSum(sumPrice);

  /// Проверка правила сервиса: отмена разрешена строго не менее чем за 2 часа (>= 120 минут)
  /// Если осталось < 120 мин (например, 1 ч 59 мин или меньше), отмена строго блокируется!
  bool get canCancel {
    final diff = startsAt.difference(AppClock.now());
    return diff.inMinutes >= AppStateService.freeCancelMinutes;
  }

  /// Перенос подчиняется тому же правилу 2 часов, что и отмена
  bool get canReschedule => canCancel;

  Duration get timeUntilAppointment => startsAt.difference(AppClock.now());

  /// ТЗ M-13: отзыв можно оставить только после визита и не позднее 7 дней
  bool get isReviewWindowOpen =>
      status == BookingStatus.completed &&
      AppClock.now().difference(startsAt).inDays < AppStateService.reviewWindowDays;
}

/// Результат проверки QR-кода визита мастером
class VisitQrResult {
  final BookingItem? booking;
  final String? error;

  const VisitQrResult.success(BookingItem this.booking) : error = null;
  const VisitQrResult.failure(String this.error) : booking = null;

  bool get isSuccess => booking != null;
}

/// Синглтон-сервис локального состояния (Mock Data Store)
class AppStateService extends ChangeNotifier {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  // Бизнес-правила (ТЗ)
  /// Бесплатная отмена/перенос не позднее чем за 2 часа (решение заказчика; в ТЗ K-04 — 4 часа)
  static const freeCancelMinutes = 120;

  /// K-03: не более 4 записей за кредиты в один салон в месяц
  static const maxCreditBookingsPerSalonMonth = 4;

  /// M-13: отзыв — в течение 7 дней после визита
  static const reviewWindowDays = 7;

  /// K-08: заморозка 7–30 дней, не чаще 1 раза в 3 месяца
  static const freezeMinDays = 7;
  static const freezeMaxDays = 30;
  static const freezeCooldownDays = 90;

  /// QR визита: код живёт 60 с (+15 с на сетевую задержку), окно визита −30 / +60 мин
  static const qrLifetimeSeconds = 60;
  static const qrGraceSeconds = 15;
  static const qrEarlyMinutes = 30;
  static const qrLateMinutes = 60;

  /// Пакеты кредитов (ТЗ): название → кредитов в месяц
  static const planCredits = {'Lite': 60, 'Standart': 120, 'Premium': 250};

  // Состояние клиента
  String clientName = 'Wazow';
  String clientPhone = '+998 90 123 45 67';
  String clientAvatar = 'assets/images/clients/client_wazow.jpg';
  int clientCredits = 86;
  String subscriptionPlan = 'Premium';
  DateTime subscriptionExpiresAt = DateTime(2026, 11, 12);
  String clientBirthDate = '14.05.1998';
  String clientGender = 'Женский';

  // Заморозка абонемента (K-08)
  bool isFrozen = false;
  DateTime? frozenUntil;
  DateTime? lastFreezeStartedAt;

  // Настройки приложения
  bool promoNotificationsEnabled = true;
  bool newsNotificationsEnabled = true;
  bool useLocationEnabled = true;

  String get subscriptionExpiry => Formatters.fullDate(subscriptionExpiresAt);

  /// Объём кредитов текущего тарифа
  int get planTotalCredits => planCredits[subscriptionPlan] ?? 60;

  /// Израсходовано кредитов в текущем периоде (для прогресс-бара)
  int get usedPlanCredits => (planTotalCredits - clientCredits).clamp(0, planTotalCredits);

  /// Можно ли сейчас заморозить абонемент; если нет — причина
  String? get freezeBlockReason {
    if (isFrozen) return null;
    final last = lastFreezeStartedAt;
    if (last != null) {
      final daysSince = AppClock.now().difference(last).inDays;
      if (daysSince < freezeCooldownDays) {
        final available = last.add(const Duration(days: freezeCooldownDays));
        return 'Заморозка доступна 1 раз в 3 месяца. Следующая — с ${Formatters.fullDate(available)}.';
      }
    }
    return null;
  }

  void updateSettings({bool? promo, bool? news, bool? location}) {
    promoNotificationsEnabled = promo ?? promoNotificationsEnabled;
    newsNotificationsEnabled = news ?? newsNotificationsEnabled;
    useLocationEnabled = location ?? useLocationEnabled;
    notifyListeners();
  }

  void updateClientProfile({
    required String name,
    required String phone,
    required String birthDate,
    required String gender,
  }) {
    clientName = name;
    clientPhone = phone;
    clientBirthDate = birthDate;
    clientGender = gender;
    notifyListeners();
  }

  // Избранные салоны и мастера (ТЗ M-15) — только по id
  final Set<String> _favoriteSalonIds = {'s-001', 's-003'};
  final Set<String> _favoriteMasterIds = {'m-001', 'm-002'};

  Set<String> get favoriteSalonIds => Set.unmodifiable(_favoriteSalonIds);
  Set<String> get favoriteMasterIds => Set.unmodifiable(_favoriteMasterIds);
  int get totalFavoritesCount => _favoriteSalonIds.length + _favoriteMasterIds.length;

  bool isSalonFavorite(String salonId) => _favoriteSalonIds.contains(salonId);
  bool isMasterFavorite(String masterId) => _favoriteMasterIds.contains(masterId);

  /// Переключение статуса «Избранное» для салона (M-15)
  /// [BACKEND NOTE]: При подключении NestJS заменяется на POST /api/v1/favorites/salons/:id
  void toggleSalonFavorite(String salonId) {
    if (!_favoriteSalonIds.remove(salonId)) _favoriteSalonIds.add(salonId);
    notifyListeners();
  }

  /// Переключение статуса «Избранное» для мастера (M-15)
  /// [BACKEND NOTE]: При подключении NestJS заменяется на POST /api/v1/favorites/masters/:id
  void toggleMasterFavorite(String masterId) {
    if (!_favoriteMasterIds.remove(masterId)) _favoriteMasterIds.add(masterId);
    notifyListeners();
  }

  // Состояние мастера: связь с каталогом — только по id, имя и салон — для отображения
  String masterId = 'm-002';
  String masterName = 'Sabina Nur';
  String masterSalonId = 's-001';
  String masterSalon = 'Nur Beauty';
  String masterAvatar = 'assets/images/masters/master_sabina.jpg';
  int masterVisitsToday = 8;
  int masterMonthlyVisits = 21;
  int masterDailyRevenue = 2450000;
  int masterMonthlyRevenue = 1240000;
  double salonCommissionPercent = 10.0;

  // Список записей. Мок-записи — снимки реальных услуг каталога (ссылки по id).
  final List<BookingItem> _bookings = [
    BookingItem(
      id: 'b-001',
      salonId: 's-001',
      salonName: 'Nur Beauty',
      serviceId: 'm-001-s1',
      serviceName: 'Комбинированный маникюр + гель-лак',
      masterId: 'm-001',
      masterName: 'Алена',
      durationLabel: '60 мин',
      credits: 34,
      sumPrice: 150000,
      paymentMethod: PaymentMethods.credits,
      // Осталось ~1 час 20 минут (< 2 часов) для проверки блокировки отмены
      startsAt: AppClock.now().add(const Duration(minutes: 80)),
    ),
    BookingItem(
      id: 'b-005',
      salonId: 's-008',
      salonName: 'Elite Barber & Style',
      serviceId: 'm-005-s1',
      serviceName: 'Мужская стрижка + мытье + стайлинг',
      masterId: 'm-005',
      masterName: 'Тимур',
      durationLabel: '45 мин',
      credits: 26,
      sumPrice: 110000,
      paymentMethod: PaymentMethods.credits,
      // Осталось > 2 часов для проверки успешной отмены с возвратом кредитов
      startsAt: AppClock.now().add(const Duration(hours: 22)),
    ),
    BookingItem(
      id: 'b-002',
      salonId: 's-001',
      salonName: 'Nur Beauty',
      serviceId: 'm-002-s1',
      serviceName: 'Архитектура бровей + окрашивание',
      masterId: 'm-002',
      masterName: 'Сабина',
      durationLabel: '45 мин',
      // Визит 2 дня назад — ещё можно оставить отзыв (окно 7 дней, M-13)
      startsAt: _daysAgoAt(2, 14, 0),
      credits: 24,
      sumPrice: 110000,
      paymentMethod: PaymentMethods.credits,
      status: BookingStatus.completed,
    ),
    BookingItem(
      id: 'b-003',
      salonId: 's-003',
      salonName: 'Mira Hair',
      serviceId: 'm-003-s1',
      serviceName: 'Женская стрижка + брашинг',
      masterId: 'm-003',
      masterName: 'Дилноза',
      durationLabel: '60 мин',
      startsAt: DateTime(2026, 9, 28, 10, 0),
      credits: 32,
      sumPrice: 140000,
      paymentMethod: PaymentMethods.online,
      status: BookingStatus.completed,
      reviewRating: 5,
      reviewTags: const ['Профессионализм мастера', 'Чистота и гигиена'],
      reviewComment: 'Очень понравилась стрижка! Мастер Дилноза учла все пожелания.',
      reviewDate: DateTime(2026, 9, 28, 12, 30),
    ),
  ];

  static DateTime _daysAgoAt(int days, int hour, int minute) {
    final d = AppClock.now().subtract(Duration(days: days));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  List<BookingItem> _sorted(Iterable<BookingItem> items, {bool newestFirst = false}) {
    final list = items.toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return newestFirst ? list.reversed.toList() : list;
  }

  List<BookingItem> get bookings => List.unmodifiable(_bookings);

  /// Активные — от ближайшего визита к дальнему
  List<BookingItem> get activeBookings => _sorted(_bookings.where((b) => b.status == BookingStatus.active));

  /// Прошедшие и отменённые — сначала свежие
  List<BookingItem> get completedBookings =>
      _sorted(_bookings.where((b) => b.status == BookingStatus.completed), newestFirst: true);
  List<BookingItem> get cancelledBookings =>
      _sorted(_bookings.where((b) => b.status == BookingStatus.cancelled), newestFirst: true);

  /// Запись по id; `null`, если такой нет
  BookingItem? bookingById(String id) {
    for (final b in _bookings) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// Заменить запись новой версией (модель неизменяемая) и уведомить слушателей
  void _replaceBooking(BookingItem updated) {
    final index = _bookings.indexWhere((b) => b.id == updated.id);
    if (index == -1) return;
    _bookings[index] = updated;
    notifyListeners();
  }

  /// Ближайший активный визит (для QR из профиля)
  BookingItem? get nearestActiveBooking {
    final active = activeBookings;
    return active.isEmpty ? null : active.first;
  }

  /// K-03: сколько записей за кредиты в этот салон в месяце визита
  int creditBookingsInMonth(String salonId, DateTime month) {
    return _bookings
        .where(
          (b) =>
              b.salonId == salonId &&
              b.isPaidWithCredits &&
              b.status != BookingStatus.cancelled &&
              b.startsAt.year == month.year &&
              b.startsAt.month == month.month,
        )
        .length;
  }

  /// Почему нельзя оплатить кредитами (null — можно)
  String? creditsBlockReason({required String salonId, required int credits, required DateTime dateTime}) {
    if (isFrozen) return 'Абонемент заморожен';
    if (clientCredits < credits) return 'Не хватает ${credits - clientCredits} кр.';
    if (creditBookingsInMonth(salonId, dateTime) >= maxCreditBookingsPerSalonMonth) {
      return 'Лимит $maxCreditBookingsPerSalonMonth записи в месяц в этот салон';
    }
    return null;
  }

  /// Создание новой брони клиентом.
  /// [BACKEND NOTE]: POST /api/v1/bookings — кредиты резервируются, списание по итогу визита (K-07)
  BookingItem createBooking({
    required String salonId,
    required String salonName,
    required String serviceId,
    required String serviceName,
    String? masterId,
    required String masterName,
    required DateTime dateTime,
    required int credits,
    required int sumPrice,
    required String paymentMethod,
    String durationLabel = '60 мин',
  }) {
    final newBooking = BookingItem(
      // [Фаза 3]: id станет uuid вместе с идемпотентностью; время здесь — не правило, а просто метка
      id: 'b-${DateTime.now().microsecondsSinceEpoch}',
      salonId: salonId,
      salonName: salonName,
      serviceId: serviceId,
      serviceName: serviceName,
      masterId: masterId,
      masterName: masterName,
      durationLabel: durationLabel,
      startsAt: dateTime,
      credits: credits,
      sumPrice: sumPrice,
      paymentMethod: paymentMethod,
      status: BookingStatus.active,
    );

    _bookings.insert(0, newBooking);

    // Если оплачено кредитами, резервируем их с баланса
    if (paymentMethod == PaymentMethods.credits) {
      clientCredits = clientCredits >= credits ? clientCredits - credits : 0;
    }

    // Обновляем показатели мастера, если запись в его салон на сегодня
    final now = AppClock.now();
    if (salonId == masterSalonId &&
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      masterVisitsToday++;
      masterDailyRevenue += sumPrice;
    }

    notifyListeners();
    return newBooking;
  }

  /// Отмена бронирования (с проверкой правила 2 часов)
  bool cancelBooking(String bookingId) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final b = _bookings[index];
      if (!b.canCancel) {
        return false; // Отмена строго заблокирована (до визита осталось менее 2 часов)
      }
      // Возврат кредитов по правилу ТЗ
      if (b.isPaidWithCredits) {
        clientCredits += b.credits;
      }

      _replaceBooking(b.copyWith(status: BookingStatus.cancelled));
      return true;
    }
    return false;
  }

  /// Перенос времени бронирования (M-10)
  /// [BACKEND NOTE]: При интеграции с NestJS заменяется на PATCH /api/v1/bookings/:id/reschedule
  bool rescheduleBooking({required String bookingId, required DateTime newDateTime}) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1 || !_bookings[index].canReschedule) return false;
    _replaceBooking(_bookings[index].copyWith(startsAt: newDateTime));
    return true;
  }

  /// Добавление оценки и отзыва о визите (M-13)
  /// [BACKEND NOTE]: При интеграции с NestJS заменяется на POST /api/v1/bookings/:id/review
  /// body: { "rating": rating, "tags": tags, "comment": comment }
  void addReview({
    required String bookingId,
    required int rating,
    required List<String> tags,
    required String comment,
  }) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _replaceBooking(
        _bookings[index].copyWith(
          reviewRating: rating,
          reviewTags: tags,
          reviewComment: comment,
          reviewDate: AppClock.now(),
        ),
      );
    }
  }

  /// Подтверждение визита через QR
  void completeVisit(String bookingId) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _replaceBooking(_bookings[index].copyWith(status: BookingStatus.completed));
    }
  }

  /// Динамический токен QR визита: `GZL|bookingId|issuedAtMillis`.
  /// [BACKEND NOTE]: на сервере токен подписывается (HMAC), клиент лишь отображает его.
  String visitQrToken(BookingItem booking) => 'GZL|${booking.id}|${AppClock.now().millisecondsSinceEpoch}';

  /// Проверка QR мастером: формат, срок жизни кода, статус записи, салон, окно −30/+60 мин.
  /// При успехе визит отмечается выполненным.
  VisitQrResult validateVisitQr(String raw, {bool ignoreTimeWindow = false}) {
    final parts = raw.split('|');
    if (parts.length != 3 || parts[0] != 'GZL') {
      return const VisitQrResult.failure('Это не QR-код визита Go\'zallik.');
    }
    final issuedAt = int.tryParse(parts[2]);
    if (issuedAt == null) {
      return const VisitQrResult.failure('QR-код повреждён. Попросите клиента открыть его заново.');
    }
    final age = AppClock.now().difference(DateTime.fromMillisecondsSinceEpoch(issuedAt)).inSeconds;
    if (age > qrLifetimeSeconds + qrGraceSeconds) {
      return const VisitQrResult.failure('QR-код устарел. Попросите клиента показать обновлённый код.');
    }

    final index = _bookings.indexWhere((b) => b.id == parts[1]);
    if (index == -1) {
      return const VisitQrResult.failure('Запись не найдена.');
    }
    final booking = _bookings[index];
    if (booking.status != BookingStatus.active) {
      return VisitQrResult.failure(
        booking.status == BookingStatus.completed ? 'Этот визит уже подтверждён.' : 'Запись отменена.',
      );
    }
    if (booking.salonId != masterSalonId) {
      return VisitQrResult.failure('Запись оформлена в другой салон: ${booking.salonName}.');
    }
    if (!ignoreTimeWindow) {
      final minutesToStart = booking.startsAt.difference(AppClock.now()).inMinutes;
      if (minutesToStart > qrEarlyMinutes || minutesToStart < -qrLateMinutes) {
        return VisitQrResult.failure(
          'Визит запланирован на ${booking.date}, ${booking.time}. '
          'Подтвердить можно за $qrEarlyMinutes мин до начала и до $qrLateMinutes мин после.',
        );
      }
    }

    completeVisit(booking.id);
    return VisitQrResult.success(bookingById(booking.id) ?? booking);
  }

  /// Заморозка абонемента на [days] дней (K-08): срок действия сдвигается на время заморозки
  bool freezeSubscription(int days) {
    if (isFrozen || freezeBlockReason != null) return false;
    final clamped = days.clamp(freezeMinDays, freezeMaxDays);
    final now = AppClock.now();
    isFrozen = true;
    lastFreezeStartedAt = now;
    frozenUntil = now.add(Duration(days: clamped));
    subscriptionExpiresAt = subscriptionExpiresAt.add(Duration(days: clamped));
    notifyListeners();
    return true;
  }

  /// Досрочная разморозка: неиспользованные дни заморозки снимаются со срока действия
  void unfreezeSubscription() {
    if (!isFrozen) return;
    final until = frozenUntil;
    if (until != null) {
      final unused = until.difference(AppClock.now());
      if (!unused.isNegative) {
        subscriptionExpiresAt = subscriptionExpiresAt.subtract(Duration(days: unused.inDays));
      }
    }
    isFrozen = false;
    frozenUntil = null;
    notifyListeners();
  }

  /// Покупка/смена пакета: начисление кредитов и продление на 30 дней (K-01)
  void purchasePackage(String planName, int credits) {
    clientCredits += credits;
    subscriptionPlan = planName;
    final now = AppClock.now();
    final base = subscriptionExpiresAt.isAfter(now) ? subscriptionExpiresAt : now;
    subscriptionExpiresAt = base.add(const Duration(days: 30));
    notifyListeners();
  }

  /// Покупка пакета кредитов
  void addCredits(int credits) {
    clientCredits += credits;
    notifyListeners();
  }

  // Уведомления клиента
  // [BACKEND NOTE]: GET /api/v1/notifications, PATCH /api/v1/notifications/:id/read
  final List<AppNotification> _notifications = [
    AppNotification(
      id: 'n-001',
      type: AppNotificationType.reminder,
      title: 'Напоминание о визите',
      body: 'Сегодня в 16:30 — Маникюр классический в Nur Beauty. Не забудьте QR-код.',
      timeLabel: '10 мин назад',
    ),
    AppNotification(
      id: 'n-002',
      type: AppNotificationType.credits,
      title: 'Кредиты заканчиваются',
      body: 'На балансе осталось меньше 100 кредитов. Пополните, чтобы не потерять запись.',
      timeLabel: '2 ч назад',
    ),
    AppNotification(
      id: 'n-003',
      type: AppNotificationType.promo,
      title: 'Новый салон рядом',
      body: 'Lola Studio в Яшнабадском районе теперь принимает кредиты.',
      timeLabel: 'Вчера',
      salonId: 's-002',
    ),
    AppNotification(
      id: 'n-004',
      type: AppNotificationType.review,
      title: 'Оцените визит',
      body: 'Как прошла стрижка в Mira Hair? Ваш отзыв поможет другим.',
      timeLabel: '3 дня назад',
      isRead: true,
    ),
  ];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  void markNotificationRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1 || _notifications[index].isRead) return;
    _notifications[index].isRead = true;
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }
}

enum AppNotificationType { reminder, credits, promo, review }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final String timeLabel;

  /// Салон, на который ведёт уведомление (если есть)
  final String? salonId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.salonId,
    this.isRead = false,
  });
}
