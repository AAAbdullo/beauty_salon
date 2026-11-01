import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../models/salon_filter_params.dart';

/// Модель салона красоты с полным набором атрибутов по ТЗ
class SalonModel {
  final String id;
  final String name;
  final String district; // Район Ташкента
  final String address;
  final String services;
  final double rating;
  final int reviewsCount;
  final String distance;
  final String workingHours;
  final bool onlyWomen; // ТЗ: Faqat ayollar uchun
  final bool homeVisit; // ТЗ: Uyga chiqish
  final bool creditsAccepted; // ТЗ: Kredit bilan
  final bool availableToday; // ТЗ: Bugun bo'sh
  final int minPriceSum;
  final int minCredits;
  final Point point; // Гео-координаты для Yandex MapKit

  const SalonModel({
    required this.id,
    required this.name,
    required this.district,
    required this.address,
    required this.services,
    required this.rating,
    required this.reviewsCount,
    required this.distance,
    required this.workingHours,
    this.onlyWomen = false,
    this.homeVisit = false,
    this.creditsAccepted = true,
    this.availableToday = true,
    required this.minPriceSum,
    required this.minCredits,
    required this.point,
  });

  /// Для будущего парсинга из JSON ответа бэкенда
  factory SalonModel.fromJson(Map<String, dynamic> json) {
    return SalonModel(
      id: json['id'] as String,
      name: json['name'] as String,
      district: json['district'] as String,
      address: json['address'] as String,
      services: json['services'] as String,
      rating: (json['rating'] as num).toDouble(),
      reviewsCount: json['reviews_count'] as int,
      distance: json['distance'] as String,
      workingHours: json['working_hours'] as String,
      onlyWomen: json['only_women'] as bool? ?? false,
      homeVisit: json['home_visit'] as bool? ?? false,
      creditsAccepted: json['credits_accepted'] as bool? ?? true,
      availableToday: json['available_today'] as bool? ?? true,
      minPriceSum: json['min_price_sum'] as int,
      minCredits: json['min_credits'] as int,
      point: Point(
        latitude: (json['lat'] as num).toDouble(),
        longitude: (json['lng'] as num).toDouble(),
      ),
    );
  }
}

/// Репозиторий каталога салонов (Абстракция данных)
///
/// БЭКЕНД-ИНТЕГРАЦИЯ:
/// Сейчас метод [getSalons] фильтрует локальные данные [_mockSalons].
/// При подключении бэкенда здесь будет вызов:
/// `final response = await dio.get('/api/v1/catalog/salons', queryParameters: params?.toQueryParams());`
class SalonsRepository {
  static final SalonsRepository _instance = SalonsRepository._internal();
  factory SalonsRepository() => _instance;
  SalonsRepository._internal();

  // МОК-ДАННЫЕ: Салоны Ташкента с атрибутами по ТЗ (M-04)
  final List<SalonModel> _mockSalons = const [
    SalonModel(
      id: 's-001',
      name: 'Nur Beauty',
      district: 'Мирзо-Улугбекский',
      address: 'ул. Мустакиллик, 42',
      services: 'Маникюр · Педикюр · Брови · Макияж',
      rating: 4.8,
      reviewsCount: 126,
      distance: '0,6 км',
      workingHours: 'Открыто до 21:00',
      onlyWomen: true, // Женский зал
      homeVisit: false,
      creditsAccepted: true,
      availableToday: true,
      minPriceSum: 150000,
      minCredits: 34,
      point: Point(latitude: 41.314500, longitude: 69.285000),
    ),
    SalonModel(
      id: 's-002',
      name: 'Lola Studio',
      district: 'Яшнабадский',
      address: 'ул. Махтумкули, 18',
      services: 'Стрижки · Окрашивание · Укладка',
      rating: 4.7,
      reviewsCount: 98,
      distance: '1,2 км',
      workingHours: 'Открыто до 20:00',
      onlyWomen: false,
      homeVisit: true, // Мастер выезжает на дом
      creditsAccepted: true,
      availableToday: true,
      minPriceSum: 120000,
      minCredits: 28,
      point: Point(latitude: 41.305000, longitude: 69.292000),
    ),
    SalonModel(
      id: 's-003',
      name: 'Mira Hair',
      district: 'Шайхантахурский',
      address: 'ул. Навои, 8',
      services: 'Стрижки · Укладка · Окрашивание',
      rating: 4.9,
      reviewsCount: 210,
      distance: '1,9 км',
      workingHours: 'Открыто до 22:00',
      onlyWomen: false,
      homeVisit: false,
      creditsAccepted: true,
      availableToday: false, // Сегодня все занято
      minPriceSum: 180000,
      minCredits: 40,
      point: Point(latitude: 41.318000, longitude: 69.262000),
    ),
    SalonModel(
      id: 's-004',
      name: 'Glow & Go',
      district: 'Яккасарайский',
      address: 'ул. Шота Руставели, 54',
      services: 'Макияж · Косметология · Уход',
      rating: 4.9,
      reviewsCount: 84,
      distance: '2,4 км',
      workingHours: 'Открыто до 21:00',
      onlyWomen: true, // Женский зал
      homeVisit: true, // Выезд на дом
      creditsAccepted: true,
      availableToday: true,
      minPriceSum: 220000,
      minCredits: 50,
      point: Point(latitude: 41.299000, longitude: 69.268000),
    ),
    SalonModel(
      id: 's-005',
      name: 'Zara Beauty Lab',
      district: 'Юнусабадский',
      address: 'квартал 4, д. 12',
      services: 'Ресницы · Ногти · Макияж',
      rating: 4.6,
      reviewsCount: 55,
      distance: '3,1 км',
      workingHours: 'Открыто до 20:00',
      onlyWomen: false,
      homeVisit: false,
      creditsAccepted: false, // Оплата только деньгами
      availableToday: true,
      minPriceSum: 100000,
      minCredits: 0,
      point: Point(latitude: 41.332000, longitude: 69.289000),
    ),
    SalonModel(
      id: 's-006',
      name: 'Chilonzor Grace',
      district: 'Чиланзарский',
      address: 'квартал 9, д. 2',
      services: 'Маникюр · Педикюр · Окрашивание',
      rating: 4.8,
      reviewsCount: 140,
      distance: '4,2 км',
      workingHours: 'Открыто до 21:00',
      onlyWomen: true, // Женский салон
      homeVisit: true,
      creditsAccepted: true,
      availableToday: true,
      minPriceSum: 130000,
      minCredits: 30,
      point: Point(latitude: 41.285000, longitude: 69.215000),
    ),
    SalonModel(
      id: 's-007',
      name: 'Bella Donna',
      district: 'Мирабадский',
      address: 'ул. Тараса Шевченко, 21',
      services: 'Маникюр · Педикюр · Косметология · Спа',
      rating: 4.9,
      reviewsCount: 175,
      distance: '0,8 км',
      workingHours: 'Открыто до 22:00',
      onlyWomen: true,
      homeVisit: false,
      creditsAccepted: true,
      availableToday: true,
      minPriceSum: 160000,
      minCredits: 36,
      point: Point(latitude: 41.301500, longitude: 69.278500),
    ),
    SalonModel(
      id: 's-008',
      name: 'Elite Barber & Style',
      district: 'Алмазарский',
      address: 'ул. Себзар, 33',
      services: 'Стрижки · Борода · Укладка',
      rating: 4.7,
      reviewsCount: 118,
      distance: '3,8 км',
      workingHours: 'Открыто до 21:00',
      onlyWomen: false,
      homeVisit: false,
      creditsAccepted: true,
      availableToday: true,
      minPriceSum: 110000,
      minCredits: 26,
      point: Point(latitude: 41.339000, longitude: 69.245000),
    ),
    SalonModel(
      id: 's-009',
      name: 'Aura Spa & Salon',
      district: 'Сергелийский',
      address: 'массив Сергели-4, д. 15',
      services: 'Массаж · Спа · Уход за волосами · Ногти',
      rating: 4.8,
      reviewsCount: 92,
      distance: '5,5 км',
      workingHours: 'Открыто до 20:00',
      onlyWomen: false,
      homeVisit: true,
      creditsAccepted: true,
      availableToday: true,
      minPriceSum: 140000,
      minCredits: 32,
      point: Point(latitude: 41.229000, longitude: 69.221000),
    ),
    SalonModel(
      id: 's-010',
      name: 'Estetika Uchtepa',
      district: 'Учтепинский',
      address: 'ул. Лутфий, 57',
      services: 'Макияж · Ногти · Брови · Педикюр',
      rating: 4.6,
      reviewsCount: 64,
      distance: '6,2 км',
      workingHours: 'Открыто до 20:00',
      onlyWomen: true,
      homeVisit: true,
      creditsAccepted: true,
      availableToday: true,
      minPriceSum: 95000,
      minCredits: 22,
      point: Point(latitude: 41.289000, longitude: 69.178000),
    ),
  ];

  /// Список районов Ташкента для фильтрации
  static const List<String> tashkentDistricts = [
    'Мирабадский',
    'Чиланзарский',
    'Юнусабадский',
    'Яккасарайский',
    'Шайхантахурский',
    'Мирзо-Улугбекский',
    'Яшнабадский',
    'Алмазарский',
    'Сергелийский',
    'Учтепинский',
  ];

  /// Получение отфильтрованных салонов
  List<SalonModel> getSalons([SalonFilterParams? params]) {
    if (params == null) return List.unmodifiable(_mockSalons);

    return _mockSalons.where((s) {
      // 1. Фильтр по району
      if (params.district != null && s.district != params.district) {
        return false;
      }

      // 2. Фильтр по категории
      if (params.serviceCategory != null &&
          params.serviceCategory != 'Все' &&
          !s.services.toLowerCase().contains(params.serviceCategory!.toLowerCase())) {
        return false;
      }

      // 3. Только для женщин (ТЗ M-04: Faqat ayollar uchun)
      if (params.onlyWomen && !s.onlyWomen) {
        return false;
      }

      // 4. Выезд на дом (ТЗ M-04: Uyga chiqish)
      if (params.homeVisit && !s.homeVisit) {
        return false;
      }

      // 5. По кредитам (ТЗ M-04: Kredit bilan)
      if (params.creditsOnly && !s.creditsAccepted) {
        return false;
      }

      // 6. Свободно сегодня (ТЗ M-04: Bugun bo'sh)
      if (params.availableToday && !s.availableToday) {
        return false;
      }

      // 7. Минимальный рейтинг
      if (s.rating < params.minRating) {
        return false;
      }

      // 8. Ценовой диапазон
      if (s.minPriceSum < params.minPrice || s.minPriceSum > params.maxPrice) {
        return false;
      }

      return true;
    }).toList();
  }
}
