import 'package:flutter/foundation.dart';

/// Модель записи на услугу
class BookingItem {
  final String id;
  final String salonName;
  final String serviceName;
  final String masterName;
  String date;
  String time;
  final int credits;
  final int sumPrice;
  final String paymentMethod;
  String status; // 'active', 'completed', 'cancelled'
  int? reviewRating;
  List<String>? reviewTags;
  String? reviewComment;
  DateTime? reviewDate;

  BookingItem({
    required this.id,
    required this.salonName,
    required this.serviceName,
    required this.masterName,
    required this.date,
    required this.time,
    required this.credits,
    required this.sumPrice,
    required this.paymentMethod,
    this.status = 'active',
    this.reviewRating,
    this.reviewTags,
    this.reviewComment,
    this.reviewDate,
  });
}

/// Синглтон-сервис локального состояния (Mock Data Store)
class AppStateService extends ChangeNotifier {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  // Состояние клиента
  String clientName = 'Wazow';
  String clientPhone = '+998 90 123 45 67';
  int clientCredits = 86;
  int usedCredits = 14;
  int totalCreditsPlan = 20;
  String subscriptionPlan = 'Премиум';
  String subscriptionExpiry = '12 ноября 2026';
  String clientBirthDate = '14.05.1998';
  String clientGender = 'Женский';
  bool isFrozen = false;

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
      date: 'Сегодня',
      time: '16:30',
      credits: 34,
      sumPrice: 150000,
      paymentMethod: 'Кредиты',
      status: 'active',
    ),
    BookingItem(
      id: 'b-002',
      salonName: 'Lola Studio',
      serviceName: 'Окрашивание бровей',
      masterName: 'Сабина',
      date: '5 окт 2026',
      time: '14:00',
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
      credits: 25,
      sumPrice: 90000,
      paymentMethod: 'Онлайн оплата',
      status: 'completed',
      reviewRating: 5,
      reviewTags: ['Профессионализм мастера', 'Чистота и гигиена'],
      reviewComment: 'Очень понравилась стрижка! Мастер Дилноза учла все пожелания.',
      reviewDate: DateTime(2026, 9, 28, 12, 30),
    ),
  ];

  List<BookingItem> get bookings => List.unmodifiable(_bookings);
  List<BookingItem> get activeBookings => _bookings.where((b) => b.status == 'active').toList();
  List<BookingItem> get completedBookings => _bookings.where((b) => b.status == 'completed').toList();
  List<BookingItem> get cancelledBookings => _bookings.where((b) => b.status == 'cancelled').toList();

  /// Создание новой брони клиентом
  void createBooking({
    required String salonName,
    required String serviceName,
    required String masterName,
    required String date,
    required String time,
    required int credits,
    required int sumPrice,
    required String paymentMethod,
  }) {
    final newBooking = BookingItem(
      id: 'b-${DateTime.now().millisecondsSinceEpoch}',
      salonName: salonName,
      serviceName: serviceName,
      masterName: masterName,
      date: date,
      time: time,
      credits: credits,
      sumPrice: sumPrice,
      paymentMethod: paymentMethod,
      status: 'active',
    );

    _bookings.insert(0, newBooking);

    // Если оплачено кредитами, списываем с баланса
    if (paymentMethod == 'Кредиты') {
      if (clientCredits >= credits) {
        clientCredits -= credits;
      }
    }

    // Обновляем показатели мастера
    masterVisitsToday++;
    masterDailyRevenue += sumPrice;

    notifyListeners();
  }

  /// Отмена бронирования (возврат кредитов)
  void cancelBooking(String bookingId) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final b = _bookings[index];
      b.status = 'cancelled';

      // Возврат кредитов по правилу ТЗ
      if (b.paymentMethod == 'Кредиты') {
        clientCredits += b.credits;
      }

      notifyListeners();
    }
  }

  /// Перенос времени бронирования (M-10)
  /// [BACKEND NOTE]: При интеграции с NestJS заменяется на PATCH /api/v1/bookings/:id/reschedule
  void rescheduleBooking({
    required String bookingId,
    required String newDate,
    required String newTime,
  }) {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index].date = newDate;
      _bookings[index].time = newTime;
      notifyListeners();
    }
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

  /// Заморозка / разморозка абонемента
  void toggleFreeze() {
    isFrozen = !isFrozen;
    notifyListeners();
  }

  /// Покупка пакета кредитов
  void addCredits(int credits) {
    clientCredits += credits;
    notifyListeners();
  }
}
