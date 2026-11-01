/// Модель параметров фильтрации каталога (ТЗ M-04)
///
/// БЭКЕНД-ИНТЕГРАЦИЯ:
/// Когда на NestJS появится бизнес-модуль каталога (`/api/v1/catalog/salons`),
/// этот объект напрямую сериализуется в GET query-параметры через [toQueryParams].
class SalonFilterParams {
  final String? district; // Район Ташкента (Mirabad, Chilanzar, Yunusabad, etc.)
  final String? serviceCategory; // Категория (Маникюр, Стрижки, Брови, etc.)
  final bool onlyWomen; // ТЗ: Faqat ayollar uchun (Только для женщин)
  final bool homeVisit; // ТЗ: Uyga chiqish (Выезд на дом)
  final bool creditsOnly; // ТЗ: Kredit bilan (Принимает кредиты)
  final bool availableToday; // ТЗ: Bugun bo'sh (Есть свободные слоты на сегодня)
  final double minRating; // Минимальный рейтинг (0.0, 4.0, 4.5, 4.8)
  final double minPrice; // Минимальная цена в сумах
  final double maxPrice; // Максимальная цена в сумах

  const SalonFilterParams({
    this.district,
    this.serviceCategory,
    this.onlyWomen = false,
    this.homeVisit = false,
    this.creditsOnly = false,
    this.availableToday = false,
    this.minRating = 0.0,
    this.minPrice = 0.0,
    this.maxPrice = 1000000.0,
  });

  bool get hasActiveFilters =>
      district != null ||
      onlyWomen ||
      homeVisit ||
      creditsOnly ||
      availableToday ||
      minRating > 0.0 ||
      minPrice > 0.0 ||
      maxPrice < 1000000.0;

  int get activeFiltersCount {
    int count = 0;
    if (district != null) count++;
    if (onlyWomen) count++;
    if (homeVisit) count++;
    if (creditsOnly) count++;
    if (availableToday) count++;
    if (minRating > 0.0) count++;
    if (minPrice > 0.0 || maxPrice < 1000000.0) count++;
    return count;
  }

  SalonFilterParams copyWith({
    String? district,
    String? serviceCategory,
    bool? onlyWomen,
    bool? homeVisit,
    bool? creditsOnly,
    bool? availableToday,
    double? minRating,
    double? minPrice,
    double? maxPrice,
    bool clearDistrict = false,
    bool clearCategory = false,
  }) {
    return SalonFilterParams(
      district: clearDistrict ? null : (district ?? this.district),
      serviceCategory: clearCategory ? null : (serviceCategory ?? this.serviceCategory),
      onlyWomen: onlyWomen ?? this.onlyWomen,
      homeVisit: homeVisit ?? this.homeVisit,
      creditsOnly: creditsOnly ?? this.creditsOnly,
      availableToday: availableToday ?? this.availableToday,
      minRating: minRating ?? this.minRating,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  /// Для будущего подключения NestJS эндпоинта GET /api/v1/catalog/salons
  Map<String, dynamic> toQueryParams() {
    return {
      if (district != null) 'district': district,
      if (serviceCategory != null && serviceCategory != 'Все') 'category': serviceCategory,
      if (onlyWomen) 'only_women': true,
      if (homeVisit) 'home_visit': true,
      if (creditsOnly) 'credits_only': true,
      if (availableToday) 'available_today': true,
      if (minRating > 0.0) 'min_rating': minRating,
      'min_price': minPrice.toInt(),
      'max_price': maxPrice.toInt(),
    };
  }
}
