import 'package:flutter/foundation.dart';
import '../utils/formatters.dart';

/// Способы оплаты записи (строки совпадают с будущим полем `payment_method` API)
class PaymentMethods {
  static const credits = 'Кредиты';
  static const online = 'Онлайн оплата';
  static const inSalon = 'В салоне';
}

/// Модель записи на услугу
class BookingItem {
  final String id;
  final String salonName;
  final String serviceName;
  final String masterName;
  final String durationLabel;
  final String _dateLabel;
  final String _timeLabel;
  final int credits;
  final int sumPrice;
  final String paymentMethod;
  String status; // 'active', 'completed', 'cancelled'
  int? reviewRating;
  List<String>? reviewTags;
  String? reviewComment;
  DateTime? reviewDate;
  DateTime? appointmentDateTime;

  BookingItem({
    required this.id,
    required this.salonName,
    required this.serviceName,
    required this.masterName,
    String date = '',
    String time = '',
    this.durationLabel = '60 мин',
    required this.credits,
    required this.sumPrice,
    required this.paymentMethod,
    this.status = 'active',
    this.reviewRating,
    this.reviewTags,
    this.reviewComment,
    this.reviewDate,
    this.appointmentDateTime,
  }) : _dateLabel = date,
       _timeLabel = time;

  /// Подпись дня визита («Сегодня», «Завтра», «12 ноя») — считается от реальной даты
  String get date => appointmentDateTime != null ? Formatters.dayLabel(appointmentDateTime!) : _dateLabel;

  /// Время визита «HH:mm»
  String get time => appointmentDateTime != null ? Formatters.time(appointmentDateTime!) : _timeLabel;

  bool get isPaidWithCredits => paymentMethod == PaymentMethods.credits;

  /// Цена в том виде, в котором её оплатил клиент
  String get priceLabel => isPaidWithCredits ? Formatters.formatCredits(credits) : Formatters.formatSum(sumPrice);

  /// Вычисленная дата и время визита
  DateTime get resolvedDateTime {
    if (appointmentDateTime != null) return appointmentDateTime!;
    final now = DateTime.now();
    int hour = 16;
    int minute = 30;
    if (_timeLabel.contains(':')) {
      final parts = _timeLabel.split(':');
      hour = int.tryParse(parts[0].trim()) ?? 16;
      minute = int.tryParse(parts[1].trim()) ?? 30;
    }

    final lowerDate = _dateLabel.toLowerCase();
    if (lowerDate.contains('сегодня')) {
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
    if (lowerDate.contains('завтра')) {
      final tomorrow = now.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    }

    final months = {
      'янв': 1,
      'фев': 2,
      'мар': 3,
      'апр': 4,
      'май': 5,
      'мая': 5,
      'июн': 6,
      'июл': 7,
      'авг': 8,
      'сен': 9,
      'окт': 10,
      'ноя': 11,
      'дек': 12,
    };
    for (final entry in months.entries) {
      if (lowerDate.contains(entry.key)) {
        final numbers = RegExp(r'\d+').allMatches(lowerDate).map((m) => int.parse(m.group(0)!)).toList();
        final day = numbers.isNotEmpty ? numbers.first : 1;
        final year = numbers.length > 1 && numbers.last > 1900 ? numbers.last : now.year;
        return DateTime(year, entry.value, day, hour, minute);
      }
    }

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// Проверка правила сервиса: отмена разрешена строго не менее чем за 2 часа (>= 120 минут)
  /// Если осталось < 120 мин (например, 1 ч 59 мин или меньше), отмена строго блокируется!
  bool get canCancel {
    final diff = resolvedDateTime.difference(DateTime.now());
    return diff.inMinutes >= AppStateService.freeCancelMinutes;
  }

  /// Перенос подчиняется тому же правилу 2 часов, что и отмена
  bool get canReschedule => canCancel;

  Duration get timeUntilAppointment => resolvedDateTime.difference(DateTime.now());

  /// ТЗ M-13: отзыв можно оставить только после визита и не позднее 7 дней
  bool get isReviewWindowOpen =>
      status == 'completed' && DateTime.now().difference(resolvedDateTime).inDays < AppStateService.reviewWindowDays;
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
      final daysSince = DateTime.now().difference(last).inDays;
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

  // Избранные салоны и мастера (ТЗ M-15)
  final Set<String> _favoriteSalonNames = {'Nur Beauty', 'Mira Hair'};
  final Set<String> _favoriteMasterNames = {'Алена', 'Сабина'};

  Set<String> get favoriteSalonNames => Set.unmodifiable(_favoriteSalonNames);
  Set<String> get favoriteMasterNames => Set.unmodifiable(_favoriteMasterNames);
  int get totalFavoritesCount => _favoriteSalonNames.length + _favoriteMasterNames.length;

  bool isSalonFavorite(String salonName) => _favoriteSalonNames.contains(salonName);
  bool isMasterFavorite(String masterName) =>
      _favoriteMasterNames.contains(masterName) ||
      _favoriteMasterNames.any((fav) => masterName.contains(fav) || fav.contains(masterName));

  /// Переключение статуса «Избранное» для салона (M-15)
  /// [BACKEND NOTE]: При подключении NestJS заменяется на POST /api/v1/favorites/salons/:id
  void toggleSalonFavorite(String salonName) {
    if (_favoriteSalonNames.contains(salonName)) {
      _favoriteSalonNames.remove(salonName);
    } else {
      _favoriteSalonNames.add(salonName);
    }
    notifyListeners();
  }

  /// Переключение статуса «Избранное» для мастера (M-15)
  /// [BACKEND NOTE]: При подключении NestJS заменяется на POST /api/v1/favorites/masters/:id
  void toggleMasterFavorite(String masterName) {
    if (isMasterFavorite(masterName)) {
      _favoriteMasterNames.removeWhere((fav) => masterName.contains(fav) || fav.contains(masterName));
    } else {
      _favoriteMasterNames.add(masterName);
    }
    notifyListeners();
  }

  // Состояние мастера
  String masterName = 'Sabina Nur';
  String masterSalon = 'Nur Beauty';
  String masterAvatar = 'assets/images/masters/master_sabina.jpg';
  int masterVisitsToday = 8;
  int masterMonthlyVisits = 21;
  int masterDailyRevenue = 2450000;
  int masterMonthlyRevenue = 1240000;
  double salonCommissionPercent = 10.0;

  // Список записей
  final List<BookingItem> _bookings = [
    BookingItem(
      id: 'b-001',
      salonName: 'Nur Beauty',
      serviceName: 'Маникюр классический',
      masterName: 'Алена',
      durationLabel: '60 мин',
      credits: 34,
      sumPrice: 150000,
      paymentMethod: 'Кредиты',
      status: 'active',
      // Осталось ~1 час 20 минут (< 2 часов) для проверки блокировки отмены
      appointmentDateTime: DateTime.now().add(const Duration(minutes: 80)),
    ),
    BookingItem(
      id: 'b-005',
      salonName: 'Elite Barber & Style',
      serviceName: 'Стрижка и стайлинг',
      masterName: 'Тимур',
      durationLabel: '45 мин',
      credits: 26,
      sumPrice: 110000,
      paymentMethod: 'Кредиты',
      status: 'active',
      // Осталось > 2 часов для проверки успешной отмены с возвратом кредитов
      appointmentDateTime: DateTime.now().add(const Duration(hours: 22)),
    ),
    BookingItem(
      id: 'b-002',
      salonName: 'Lola Studio',
      serviceName: 'Окрашивание бровей',
      masterName: 'Сабина',
      durationLabel: '40 мин',
      // Визит 2 дня назад — ещё можно оставить отзыв (окно 7 дней, M-13)
      appointmentDateTime: _daysAgoAt(2, 14, 0),
      credits: 20,
      sumPrice: 80000,
      paymentMethod: 'Кредиты',
      status: 'completed',
    ),
    BookingItem(
      id: 'b-003',
      salonName: 'Mira Hair',
      serviceName: 'Женская стрижка',
      masterName: 'Дилноза',
      date: '28 сен 2026',
      time: '10:00',
      durationLabel: '45 мин',
      credits: 25,
      sumPrice: 90000,
      paymentMethod: PaymentMethods.online,
      status: 'completed',
      reviewRating: 5,
      reviewTags: ['Профессионализм мастера', 'Чистота и гигиена'],
      reviewComment: 'Очень понравилась стрижка! Мастер Дилноза учла все пожелания.',
      reviewDate: DateTime(2026, 9, 28, 12, 30),
    ),
  ];

  static DateTime _daysAgoAt(int days, int hour, int minute) {
    final d = DateTime.now().subtract(Duration(days: days));
    return DateTime(d.year, d.month, d.day, hour, minute);
  }

  List<BookingItem> _sorted(Iterable<BookingItem> items, {bool newestFirst = false}) {
    final list = items.toList()..sort((a, b) => a.resolvedDateTime.compareTo(b.resolvedDateTime));
    return newestFirst ? list.reversed.toList() : list;
  }

  List<BookingItem> get bookings => List.unmodifiable(_bookings);

  /// Активные — от ближайшего визита к дальнему
  List<BookingItem> get activeBookings => _sorted(_bookings.where((b) => b.status == 'active'));

  /// Прошедшие и отменённые — сначала свежие
  List<BookingItem> get completedBookings =>
      _sorted(_bookings.where((b) => b.status == 'completed'), newestFirst: true);
  List<BookingItem> get cancelledBookings =>
      _sorted(_bookings.where((b) => b.status == 'cancelled'), newestFirst: true);

  /// Ближайший активный визит (для QR из профиля)
  BookingItem? get nearestActiveBooking {
    final active = activeBookings;
    return active.isEmpty ? null : active.first;
  }

  /// K-03: сколько записей за кредиты в этот салон в месяце визита
  int creditBookingsInMonth(String salonName, DateTime month) {
    return _bookings
        .where(
          (b) =>
              b.salonName == salonName &&
              b.isPaidWithCredits &&
              b.status != 'cancelled' &&
              b.resolvedDateTime.year == month.year &&
              b.resolvedDateTime.month == month.month,
        )
        .length;
  }

  /// Почему нельзя оплатить кредитами (null — можно)
  String? creditsBlockReason({required String salonName, required int credits, required DateTime dateTime}) {
    if (isFrozen) return 'Абонемент заморожен';
    if (clientCredits < credits) return 'Не хватает ${credits - clientCredits} кр.';
    if (creditBookingsInMonth(salonName, dateTime) >= maxCreditBookingsPerSalonMonth) {
      return 'Лимит $maxCreditBookingsPerSalonMonth записи в месяц в этот салон';
    }
    return null;
  }

  /// Создание новой брони клиентом.
  /// [BACKEND NOTE]: POST /api/v1/bookings — кредиты резервируются, списание по итогу визита (K-07)
  BookingItem createBooking({
    required String salonName,
    required String serviceName,
    required String masterName,
    required DateTime dateTime,
    required int credits,
    required int sumPrice,
    required String paymentMethod,
    String durationLabel = '60 мин',
  }) {
    final newBooking = BookingItem(
      id: 'b-${DateTime.now().millisecondsSinceEpoch}',
      salonName: salonName,
      serviceName: serviceName,
      masterName: masterName,
      durationLabel: durationLabel,
      appointmentDateTime: dateTime,
      credits: credits,
      sumPrice: sumPrice,
      paymentMethod: paymentMethod,
      status: 'active',
    );

    _bookings.insert(0, newBooking);

    // Если оплачено кредитами, резервируем их с баланса
    if (paymentMethod == PaymentMethods.credits) {
      clientCredits = clientCredits >= credits ? clientCredits - credits : 0;
    }

    // Обновляем показатели мастера, если запись в его салон на сегодня
    final now = DateTime.now();
    if (salonName == masterSalon &&
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
      b.status = 'cancelled';

      // Возврат кредитов по правилу ТЗ
      if (b.isPaidWithCredits) {
        clientCredits += b.credits;
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  /// Перенос времени бронирования (M-10)
  /// [BACKEND NOTE]: При интеграции с NestJS заменяется на PATCH /api/v1/bookings/:id/reschedule
  bool rescheduleBooking({required String bookingId, required DateTime newDateTime}) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index == -1 || !_bookings[index].canReschedule) return false;
    _bookings[index].appointmentDateTime = newDateTime;
    notifyListeners();
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
      _bookings[index].reviewRating = rating;
      _bookings[index].reviewTags = tags;
      _bookings[index].reviewComment = comment;
      _bookings[index].reviewDate = DateTime.now();
      notifyListeners();
    }
  }

  /// Подтверждение визита через QR
  void completeVisit(String bookingId) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index].status = 'completed';
      notifyListeners();
    }
  }

  /// Динамический токен QR визита: `GZL|bookingId|issuedAtMillis`.
  /// [BACKEND NOTE]: на сервере токен подписывается (HMAC), клиент лишь отображает его.
  String visitQrToken(BookingItem booking) => 'GZL|${booking.id}|${DateTime.now().millisecondsSinceEpoch}';

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
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(issuedAt)).inSeconds;
    if (age > qrLifetimeSeconds + qrGraceSeconds) {
      return const VisitQrResult.failure('QR-код устарел. Попросите клиента показать обновлённый код.');
    }

    final index = _bookings.indexWhere((b) => b.id == parts[1]);
    if (index == -1) {
      return const VisitQrResult.failure('Запись не найдена.');
    }
    final booking = _bookings[index];
    if (booking.status != 'active') {
      return VisitQrResult.failure(booking.status == 'completed' ? 'Этот визит уже подтверждён.' : 'Запись отменена.');
    }
    if (booking.salonName != masterSalon) {
      return VisitQrResult.failure('Запись оформлена в другой салон: ${booking.salonName}.');
    }
    if (!ignoreTimeWindow) {
      final minutesToStart = booking.resolvedDateTime.difference(DateTime.now()).inMinutes;
      if (minutesToStart > qrEarlyMinutes || minutesToStart < -qrLateMinutes) {
        return VisitQrResult.failure(
          'Визит запланирован на ${booking.date}, ${booking.time}. '
          'Подтвердить можно за $qrEarlyMinutes мин до начала и до $qrLateMinutes мин после.',
        );
      }
    }

    completeVisit(booking.id);
    return VisitQrResult.success(booking);
  }

  /// Заморозка абонемента на [days] дней (K-08): срок действия сдвигается на время заморозки
  bool freezeSubscription(int days) {
    if (isFrozen || freezeBlockReason != null) return false;
    final clamped = days.clamp(freezeMinDays, freezeMaxDays);
    final now = DateTime.now();
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
      final unused = until.difference(DateTime.now());
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
    final base = subscriptionExpiresAt.isAfter(DateTime.now()) ? subscriptionExpiresAt : DateTime.now();
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
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.isRead = false,
  });
}
