import 'package:flutter/foundation.dart';
import '../models/booking_error.dart';
import '../models/booking_item.dart';
import '../models/booking_rules.dart';
import '../utils/clock.dart';
import '../utils/formatters.dart';
import '../utils/result.dart';
import '../utils/slot_pricing.dart';
import '../utils/uuid.dart';
import 'booking_seed.dart';
import 'booking_store.dart';
import 'master_cabinet_store.dart';
import 'masters_repository.dart';
import 'slot_service.dart';

// Экраны подключают только этот файл — модели записей доступны через него.
export '../models/booking_error.dart';
export '../models/booking_item.dart';

/// Результат проверки QR-кода визита мастером
class VisitQrResult {
  final BookingItem? booking;
  final String? error;

  const VisitQrResult.success(BookingItem this.booking) : error = null;
  const VisitQrResult.failure(String this.error) : booking = null;

  bool get isSuccess => booking != null;
}

/// Синглтон-сервис локального состояния (Mock Data Store): клиент, абонемент, избранное, настройки.
///
/// Записи хранятся в едином [BookingStore], занятость слотов считает [SlotService]; здесь —
/// правила: кому и когда можно записаться, отменить, перенести, оставить отзыв, купить пакет.
/// Каждая операция проверяет правила сама (UI-проверки — только подсказка пользователю)
/// и возвращает [Result] с причиной отказа.
/// Стандартное фото мастера (Sabina Nur)
const seedMasterAvatar = 'assets/images/masters/master_sabina.jpg';

class AppStateService extends ChangeNotifier {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal() {
    _applySeed();
    // Любое изменение записей (в том числе от кабинета мастера) обновляет все экраны
    _store.addListener(notifyListeners);
  }

  final BookingStore _store = BookingStore();
  final SlotService _slots = SlotService();

  /// Меняется только при изменении записей (новая, отмена, перенос, визит по QR), а не при смене избранного,
  /// аватара или настроек. Кабинет мастера перечитывает данные по этому событию.
  Listenable get bookingChanges => _store;

  // Бизнес-правила (ТЗ) — значения живут в BookingRules
  static const freeCancelMinutes = BookingRules.freeCancelMinutes;
  static const minLeadMinutes = BookingRules.minLeadMinutes;
  static const maxCreditBookingsPerSalonMonth = BookingRules.maxCreditBookingsPerSalonMonth;
  static const reviewWindowDays = BookingRules.reviewWindowDays;
  static const freezeMinDays = BookingRules.freezeMinDays;
  static const freezeMaxDays = BookingRules.freezeMaxDays;
  static const freezeCooldownDays = BookingRules.freezeCooldownDays;
  static const qrLifetimeSeconds = BookingRules.qrLifetimeSeconds;
  static const qrGraceSeconds = BookingRules.qrGraceSeconds;
  static const qrEarlyMinutes = BookingRules.qrEarlyMinutes;
  static const qrLateMinutes = BookingRules.qrLateMinutes;

  /// Пакеты кредитов (ТЗ): название → кредитов в месяц
  static const planCredits = {'Lite': 60, 'Standart': 120, 'Premium': 250};

  // Состояние клиента
  late String clientId;
  late String clientName;
  late String clientPhone;
  late String clientAvatar;
  late int clientCredits;
  late String subscriptionPlan;
  late DateTime subscriptionExpiresAt;
  late String clientBirthDate;
  late String clientGender;

  // Заморозка абонемента (K-08)
  DateTime? frozenUntil;
  DateTime? lastFreezeStartedAt;

  // Настройки приложения
  late bool promoNotificationsEnabled;
  late bool newsNotificationsEnabled;
  /// Настройка устройства, а не аккаунта: при выходе не сбрасывается (см. [resetSession])
  bool useLocationEnabled = true;

  // Избранные салоны и мастера (ТЗ M-15) — только по id
  late Set<String> _favoriteSalonIds;
  late Set<String> _favoriteMasterIds;

  // Состояние мастера: связь с каталогом — только по id, имя и салон — для отображения
  late String masterId;
  late String masterName;
  late String masterSalonId;
  late String masterSalon;
  late String masterAvatar;
  late double salonCommissionPercent;

  // Уведомления клиента
  late List<AppNotification> _notifications;

  /// Использованные nonce QR-кодов (мок серверной защиты от повторного предъявления одного кода)
  late Set<String> _usedQrNonces;

  /// Начальные (мок) данные. Вызывается при создании и при выходе из аккаунта,
  /// чтобы следующий пользователь не видел данные предыдущего.
  void _applySeed() {
    clientId = seedClientId;
    clientName = seedClientName;
    clientPhone = '+998 90 123 45 67';
    clientAvatar = seedClientAvatar;
    clientCredits = 86;
    subscriptionPlan = 'Premium';
    // Мок: срок считается от текущих часов, чтобы демо не «протухало» с календарём
    subscriptionExpiresAt = AppClock.now().add(const Duration(days: 20));
    clientBirthDate = '14.05.1998';
    clientGender = 'Женский';

    frozenUntil = null;
    lastFreezeStartedAt = null;
    _usedQrNonces = {};

    promoNotificationsEnabled = true;
    newsNotificationsEnabled = true;

    _favoriteSalonIds = {'s-001', 's-003'};
    _favoriteMasterIds = {'m-001', 'm-002'};

    masterId = 'm-002';
    masterName = 'Sabina Nur';
    masterSalonId = 's-001';
    masterSalon = 'Nur Beauty';
    masterAvatar = seedMasterAvatar;
    salonCommissionPercent = 10.0;

    // [BACKEND NOTE]: GET /api/v1/notifications, PATCH /api/v1/notifications/:id/read
    _notifications = [
      AppNotification(
        id: 'n-001',
        type: AppNotificationType.reminder,
        title: 'Напоминание о визите',
        body: 'Скоро визит: «Архитектура бровей + окрашивание» в Nur Beauty. Не забудьте QR-код.',
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
  }

  /// Выход из аккаунта: вернуть всё состояние к начальному (клиент, записи, график мастера, избранное)
  void resetSession() {
    _applySeed();
    _store.reset();
    MasterCabinetStore().reset();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Абонемент
  // ---------------------------------------------------------------------------

  /// Заморозка действует, пока не наступил [frozenUntil]; по истечении снимается сама
  bool get isFrozen {
    final until = frozenUntil;
    return until != null && AppClock.now().isBefore(until);
  }

  /// Срок абонемента вышел: кредитами платить нельзя, пока не куплен новый пакет
  bool get isSubscriptionExpired => !AppClock.now().isBefore(subscriptionExpiresAt);

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

  /// Заморозка абонемента на [days] дней (K-08): срок действия сдвигается на время заморозки
  bool freezeSubscription(int days) {
    if (isFrozen || freezeBlockReason != null) return false;
    final clamped = days.clamp(freezeMinDays, freezeMaxDays);
    final now = AppClock.now();
    lastFreezeStartedAt = now;
    frozenUntil = now.add(Duration(days: clamped));
    subscriptionExpiresAt = subscriptionExpiresAt.add(Duration(days: clamped));
    notifyListeners();
    return true;
  }

  /// Досрочная разморозка: неиспользованные дни заморозки снимаются со срока действия.
  /// Неполный день считается целым (округление вверх), чтобы заморозка не давала лишнего срока.
  void unfreezeSubscription() {
    if (!isFrozen) return;
    final unused = frozenUntil!.difference(AppClock.now());
    final unusedDays = (unused.inHours / 24).ceil();
    subscriptionExpiresAt = subscriptionExpiresAt.subtract(Duration(days: unusedDays));
    frozenUntil = null;
    notifyListeners();
  }

  /// K-01: сколько кредитов останется после покупки пакета на [credits] кредитов.
  /// При продлении переносится не больше 20% объёма прежнего пакета, остальное сгорает.
  ({int carried, int burned, int total}) previewPurchase(int credits) {
    final cap = (planTotalCredits * BookingRules.rolloverShare).floor();
    final carried = clientCredits < cap ? clientCredits : cap;
    return (carried: carried, burned: clientCredits - carried, total: credits + carried);
  }

  /// Покупка/смена пакета: новый период на 30 дней (K-01), перенос остатка по [previewPurchase]
  void purchasePackage(String planName, int credits) {
    clientCredits = previewPurchase(credits).total;
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

  // ---------------------------------------------------------------------------
  // Профиль и настройки
  // ---------------------------------------------------------------------------

  void updateSettings({bool? promo, bool? news, bool? location}) {
    promoNotificationsEnabled = promo ?? promoNotificationsEnabled;
    newsNotificationsEnabled = news ?? newsNotificationsEnabled;
    useLocationEnabled = location ?? useLocationEnabled;
    notifyListeners();
  }

  /// Фото профиля: путь к файлу, выбранному пользователем, или встроенный ресурс
  void updateClientAvatar(String path) {
    clientAvatar = path;
    notifyListeners();
  }

  /// Вернуть стандартный аватар (фото удалено)
  void resetClientAvatar() => updateClientAvatar(seedClientAvatar);

  /// Фото мастера в его кабинете: путь к файлу или встроенный ресурс
  void updateMasterAvatar(String path) {
    masterAvatar = path;
    notifyListeners();
  }

  void resetMasterAvatar() => updateMasterAvatar(seedMasterAvatar);

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

  // ---------------------------------------------------------------------------
  // Избранное
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Записи клиента (данные — в BookingStore)
  // ---------------------------------------------------------------------------

  static int _byStart(BookingItem a, BookingItem b) => a.startsAt.compareTo(b.startsAt);

  /// Все записи текущего клиента
  List<BookingItem> get bookings => List.unmodifiable(_store.forClient(clientId));

  /// Запись по id (любого клиента — нужна и кабинету мастера); `null`, если такой нет
  BookingItem? bookingById(String id) => _store.byId(id);

  /// Активные — от ближайшего визита к дальнему
  List<BookingItem> get activeBookings =>
      _store.forClient(clientId).where((b) => b.status == BookingStatus.active).toList()..sort(_byStart);

  /// Прошедшие и отменённые — сначала свежие
  List<BookingItem> get completedBookings =>
      _store.forClient(clientId).where((b) => b.status == BookingStatus.completed).toList()
        ..sort((a, b) => _byStart(b, a));
  List<BookingItem> get cancelledBookings =>
      _store.forClient(clientId).where((b) => b.status == BookingStatus.cancelled).toList()
        ..sort((a, b) => _byStart(b, a));

  /// Ближайший активный визит (для QR из профиля)
  BookingItem? get nearestActiveBooking {
    final active = activeBookings;
    return active.isEmpty ? null : active.first;
  }

  /// K-03: сколько записей за кредиты в этот салон в месяце визита.
  /// [excludeBookingId] — не считать эту запись (при её переносе).
  int creditBookingsInMonth(String salonId, DateTime month, {String? excludeBookingId}) {
    return _store
        .forClient(clientId)
        .where(
          (b) =>
              b.id != excludeBookingId &&
              b.salonId == salonId &&
              b.isPaidWithCredits &&
              b.status != BookingStatus.cancelled &&
              b.startsAt.year == month.year &&
              b.startsAt.month == month.month,
        )
        .length;
  }

  /// Почему нельзя оплатить [credits] кредитов (null — можно): заморозка, нехватка, лимит K-03
  BookingError? _creditsBlock({
    required String salonId,
    required int credits,
    required DateTime dateTime,
    String? excludeBookingId,
  }) {
    if (isFrozen) {
      return const BookingError(BookingErrorCode.creditsFrozen, 'Абонемент заморожен');
    }
    if (isSubscriptionExpired) {
      return const BookingError(BookingErrorCode.subscriptionExpired, 'Абонемент истёк');
    }
    if (clientCredits < credits) {
      return BookingError(BookingErrorCode.notEnoughCredits, 'Не хватает ${credits - clientCredits} кр.');
    }
    if (creditBookingsInMonth(salonId, dateTime, excludeBookingId: excludeBookingId) >=
        maxCreditBookingsPerSalonMonth) {
      return const BookingError(
        BookingErrorCode.creditsLimit,
        'Лимит $maxCreditBookingsPerSalonMonth записи в месяц в этот салон',
      );
    }
    return null;
  }

  /// Подсказка для UI: почему нельзя оплатить кредитами (null — можно)
  String? creditsBlockReason({required String salonId, required int credits, required DateTime dateTime}) =>
      _creditsBlock(salonId: salonId, credits: credits, dateTime: dateTime)?.message;

  /// Не пересекается ли время с другими активными записями этого клиента
  bool _overlapsOwnBooking(DateTime startsAt, int durationMinutes, {String? excludeBookingId}) {
    final endsAt = startsAt.add(Duration(minutes: durationMinutes));
    return _store
        .forClient(clientId)
        .any((b) => b.id != excludeBookingId && b.status == BookingStatus.active && b.overlaps(startsAt, endsAt));
  }

  /// Общая проверка новой записи (используется и перед оплатой онлайн, и при создании):
  /// время в будущем, слот свободен у мастера, нет пересечения с другими записями клиента,
  /// а при оплате кредитами — хватает кредитов, нет заморозки и лимита K-03.
  Result<void, BookingError> validateNewBooking({
    required String salonId,
    String? masterId,
    required String serviceId,
    required DateTime startsAt,
    required int durationMinutes,
    required int baseCredits,
    required String paymentMethod,
  }) {
    if (startsAt.isBefore(AppClock.now().add(const Duration(minutes: minLeadMinutes)))) {
      return const Result.failure(
        BookingError(
          BookingErrorCode.inPast,
          'Это время уже прошло или начинается слишком скоро: записаться можно не позднее чем за $minLeadMinutes минут.',
        ),
      );
    }
    final available = _slots.isAvailable(
      salonId: salonId,
      masterId: masterId,
      serviceId: serviceId,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
    );
    if (!available) {
      return const Result.failure(
        BookingError(BookingErrorCode.slotUnavailable, 'Это время недоступно. Выберите другой слот.'),
      );
    }
    if (_overlapsOwnBooking(startsAt, durationMinutes)) {
      return const Result.failure(
        BookingError(BookingErrorCode.overlapsOwnBooking, 'У вас уже есть запись на это время.'),
      );
    }
    if (paymentMethod == PaymentMethods.credits) {
      final block = _creditsBlock(
        salonId: salonId,
        credits: SlotPricing.credits(baseCredits, startsAt),
        dateTime: startsAt,
      );
      if (block != null) return Result.failure(block);
    }
    return const Result.success(null);
  }

  /// Создание новой брони клиентом: все правила проверяются здесь заново.
  /// Для «Любой мастер» ([masterId] == null) подбирается свободный мастер салона.
  /// Кредиты резервируются при создании, списание по итогу визита (K-07).
  /// [BACKEND NOTE]: POST /api/v1/bookings
  Result<BookingItem, BookingError> createBooking({
    required String salonId,
    required String salonName,
    required String serviceId,
    required String serviceName,
    String? masterId,
    required String masterName,
    required DateTime dateTime,
    required int durationMinutes,
    required int baseCredits,
    required int sumPrice,
    required String paymentMethod,
    String? paymentReceiptId,
    int? paidAmount,
  }) {
    final check = validateNewBooking(
      salonId: salonId,
      masterId: masterId,
      serviceId: serviceId,
      startsAt: dateTime,
      durationMinutes: durationMinutes,
      baseCredits: baseCredits,
      paymentMethod: paymentMethod,
    );
    if (check case Failure(:final error)) return Result.failure(error);

    final resolvedMasterId =
        masterId ??
        _slots.resolveMasterId(
          salonId: salonId,
          serviceId: serviceId,
          startsAt: dateTime,
          durationMinutes: durationMinutes,
        );
    final resolvedMaster = resolvedMasterId == null ? null : MastersRepository().getMasterById(resolvedMasterId);
    final credits = SlotPricing.credits(baseCredits, dateTime);

    final booking = BookingItem(
      id: 'b-${Uuid.v4()}',
      clientId: clientId,
      clientName: clientName,
      clientAvatar: clientAvatar,
      salonId: salonId,
      salonName: salonName,
      serviceId: serviceId,
      serviceName: serviceName,
      masterId: resolvedMasterId,
      masterName: resolvedMaster?.shortName ?? masterName,
      durationMinutes: durationMinutes,
      startsAt: dateTime,
      baseCredits: baseCredits,
      credits: credits,
      sumPrice: sumPrice,
      paymentMethod: paymentMethod,
      paymentReceiptId: paymentReceiptId,
      paidAmount: paidAmount,
    );

    if (booking.isPaidWithCredits) clientCredits -= credits;
    _store.add(booking);
    notifyListeners();
    return Result.success(booking);
  }

  /// Запись текущего клиента или причина, почему с ней нельзя работать
  Result<BookingItem, BookingError> _ownActiveBooking(String bookingId) {
    final b = _store.byId(bookingId);
    if (b == null || b.clientId != clientId) {
      return const Result.failure(BookingError(BookingErrorCode.notFound, 'Запись не найдена.'));
    }
    if (b.status != BookingStatus.active) {
      return Result.failure(
        BookingError(
          BookingErrorCode.notActive,
          b.status == BookingStatus.cancelled ? 'Запись уже отменена.' : 'Визит уже состоялся.',
        ),
      );
    }
    return Result.success(b);
  }

  /// Отмена бронирования: только активная запись и не позднее чем за 2 часа.
  /// Повторный вызов не вернёт кредиты второй раз. Возврат онлайн-оплаты по квитанции записи делает «сервер»
  /// (`MockBookingsRepository`): здесь только состояние записи и кредиты.
  Result<BookingItem, BookingError> cancelBooking(String bookingId) {
    final own = _ownActiveBooking(bookingId);
    if (own case Failure()) return own;
    final b = own.valueOrNull!;

    if (!b.canCancel) {
      return const Result.failure(
        BookingError(BookingErrorCode.tooLate, 'Отмена возможна не позднее чем за 2 часа до визита.'),
      );
    }

    // Возврат кредитов по правилу ТЗ
    if (b.isPaidWithCredits) clientCredits += b.credits;
    final updated = b.copyWith(status: BookingStatus.cancelled);
    _store.replace(updated);
    notifyListeners();
    return Result.success(updated);
  }

  /// Перенос записи (M-10). Проходит те же проверки, что и создание: слот свободен у того же мастера,
  /// нет пересечений, время в будущем. Для оплаты кредитами цена пересчитывается по k_slot нового слота:
  /// доплата списывается (с проверкой баланса), разница возвращается.
  /// [BACKEND NOTE]: PATCH /api/v1/bookings/:id/reschedule
  Result<BookingItem, BookingError> rescheduleBooking({required String bookingId, required DateTime newDateTime}) {
    final own = _ownActiveBooking(bookingId);
    if (own case Failure()) return own;
    final b = own.valueOrNull!;

    if (!b.canReschedule) {
      return const Result.failure(
        BookingError(BookingErrorCode.tooLate, 'Перенос возможен не позднее чем за 2 часа до визита.'),
      );
    }
    if (newDateTime == b.startsAt) {
      return const Result.failure(BookingError(BookingErrorCode.slotUnavailable, 'Запись уже на это время.'));
    }
    if (newDateTime.isBefore(AppClock.now().add(const Duration(minutes: minLeadMinutes)))) {
      return const Result.failure(
        BookingError(BookingErrorCode.inPast, 'Это время уже прошло или начинается слишком скоро.'),
      );
    }
    final available = _slots.isAvailable(
      salonId: b.salonId,
      masterId: b.masterId,
      serviceId: b.serviceId,
      startsAt: newDateTime,
      durationMinutes: b.durationMinutes,
      excludeBookingId: b.id,
    );
    if (!available) {
      return const Result.failure(
        BookingError(BookingErrorCode.slotUnavailable, 'Это время недоступно. Выберите другой слот.'),
      );
    }
    if (_overlapsOwnBooking(newDateTime, b.durationMinutes, excludeBookingId: b.id)) {
      return const Result.failure(
        BookingError(BookingErrorCode.overlapsOwnBooking, 'У вас уже есть запись на это время.'),
      );
    }

    var newCredits = b.credits;
    if (b.isPaidWithCredits) {
      newCredits = SlotPricing.credits(b.baseCredits, newDateTime);
      final extra = newCredits - b.credits;
      // Лимит K-03 проверяем всегда (месяц мог смениться), заморозку и баланс — только если нужна доплата
      final block = _creditsBlock(
        salonId: b.salonId,
        credits: extra > 0 ? extra : 0,
        dateTime: newDateTime,
        excludeBookingId: b.id,
      );
      if (block != null && (extra > 0 || block.code == BookingErrorCode.creditsLimit)) {
        return Result.failure(block);
      }
      clientCredits -= extra;
    }

    final updated = b.copyWith(startsAt: newDateTime, credits: newCredits);
    _store.replace(updated);
    notifyListeners();
    return Result.success(updated);
  }

  /// Оценка и отзыв о визите (M-13): только завершённый визит, один отзыв, в течение 7 дней.
  /// [BACKEND NOTE]: POST /api/v1/bookings/:id/review  body: { rating, tags, comment }
  Result<BookingItem, BookingError> addReview({
    required String bookingId,
    required int rating,
    required List<String> tags,
    required String comment,
  }) {
    final b = _store.byId(bookingId);
    if (b == null || b.clientId != clientId) {
      return const Result.failure(BookingError(BookingErrorCode.notFound, 'Запись не найдена.'));
    }
    if (b.status != BookingStatus.completed) {
      return const Result.failure(
        BookingError(BookingErrorCode.notCompleted, 'Отзыв можно оставить только после визита.'),
      );
    }
    if (b.reviewRating != null) {
      return const Result.failure(BookingError(BookingErrorCode.alreadyReviewed, 'Вы уже оставили отзыв о визите.'));
    }
    if (!b.isReviewWindowOpen) {
      return const Result.failure(
        BookingError(
          BookingErrorCode.reviewClosed,
          'Отзыв можно оставить в течение $reviewWindowDays дней после визита.',
        ),
      );
    }
    final updated = b.copyWith(
      reviewRating: rating,
      reviewTags: tags,
      reviewComment: comment,
      reviewDate: AppClock.now(),
    );
    _store.replace(updated);
    notifyListeners();
    return Result.success(updated);
  }

  /// Подтверждение визита (после проверки QR): только активная запись
  Result<BookingItem, BookingError> completeVisit(String bookingId) {
    final b = _store.byId(bookingId);
    if (b == null) {
      return const Result.failure(BookingError(BookingErrorCode.notFound, 'Запись не найдена.'));
    }
    if (b.status != BookingStatus.active) {
      return Result.failure(
        BookingError(
          BookingErrorCode.notActive,
          b.status == BookingStatus.completed ? 'Этот визит уже подтверждён.' : 'Запись отменена.',
        ),
      );
    }
    final updated = b.copyWith(status: BookingStatus.completed);
    _store.replace(updated);
    notifyListeners();
    return Result.success(updated);
  }

  // ---------------------------------------------------------------------------
  // QR визита
  // ---------------------------------------------------------------------------

  /// Динамический токен QR визита: `GZL|bookingId|issuedAtMillis|nonce`.
  /// [BACKEND NOTE]: на сервере токен подписывается (HMAC), клиент лишь отображает его.
  /// Здесь подписи нет — это мок серверной логики; nonce делает код одноразовым.
  String visitQrToken(BookingItem booking) =>
      'GZL|${booking.id}|${AppClock.now().millisecondsSinceEpoch}|${Uuid.v4()}';

  /// Проверка QR мастером: формат, срок жизни кода, статус записи, салон, окно −30/+60 мин.
  /// При успехе визит отмечается выполненным и попадает в доход мастера.
  /// [ignoreTimeWindow] — только для демо-режима мока и тестов; репозиторий наружу его не отдаёт.
  VisitQrResult validateVisitQr(String raw, {bool ignoreTimeWindow = false}) {
    final parts = raw.split('|');
    if (parts.length != 4 || parts[0] != 'GZL') {
      return const VisitQrResult.failure('Это не QR-код визита Go\'zallik.');
    }
    final issuedAt = int.tryParse(parts[2]);
    if (issuedAt == null) {
      return const VisitQrResult.failure('QR-код повреждён. Попросите клиента открыть его заново.');
    }
    final age = AppClock.now().difference(DateTime.fromMillisecondsSinceEpoch(issuedAt)).inSeconds;
    if (age < -qrGraceSeconds) {
      // Код «из будущего» — признак подделки или сбитых часов; принимать его нельзя
      return const VisitQrResult.failure('QR-код не прошёл проверку времени. Попросите клиента открыть код заново.');
    }
    if (age > qrLifetimeSeconds + qrGraceSeconds) {
      return const VisitQrResult.failure('QR-код устарел. Попросите клиента показать обновлённый код.');
    }
    if (_usedQrNonces.contains(parts[3])) {
      return const VisitQrResult.failure('Этот QR-код уже использован. Попросите клиента показать обновлённый код.');
    }

    final booking = _store.byId(parts[1]);
    if (booking == null) {
      return const VisitQrResult.failure('Запись не найдена.');
    }
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

    return switch (completeVisit(booking.id)) {
      Success(:final value) => () {
        _usedQrNonces.add(parts[3]);
        return VisitQrResult.success(value);
      }(),
      Failure(:final error) => VisitQrResult.failure(error.message),
    };
  }

  // ---------------------------------------------------------------------------
  // Уведомления клиента
  // ---------------------------------------------------------------------------

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
