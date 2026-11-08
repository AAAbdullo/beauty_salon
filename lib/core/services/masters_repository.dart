/// Модель мастера салона по ТЗ (M-07: Usta sahifasi)
///
/// БЭКЕНД-ИНТЕГРАЦИЯ:
/// В будущем данные будут приходить с эндпоинта GET /api/v1/catalog/masters/:id
class MasterProfileModel {
  final String id;
  final String name;
  final String salonId;
  final String salonName;
  final String specialty;
  final double rating;
  final int reviewsCount;
  final int experienceYears;
  final String about;
  final String avatarAsset;
  final List<String> portfolioImages;
  final List<MasterServiceItem> services;
  final List<MasterReviewItem> reviews;

  const MasterProfileModel({
    required this.id,
    required this.name,
    required this.salonId,
    required this.salonName,
    required this.specialty,
    required this.rating,
    required this.reviewsCount,
    required this.experienceYears,
    required this.about,
    this.avatarAsset = 'assets/images/masters/master_alena.jpg',
    required this.portfolioImages,
    required this.services,
    required this.reviews,
  });

  /// Короткое имя («Алена») — только для отображения. Ключом мастера служит [id].
  String get shortName => name.split(' ').first;

  /// Мастер оказывает услугу с таким id
  bool offers(String serviceId) => services.any((s) => s.id == serviceId);
}

class MasterServiceItem {
  final String id;
  final String name;
  final int durationMinutes;
  final int creditsPrice;
  final int sumPrice;

  const MasterServiceItem({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.creditsPrice,
    required this.sumPrice,
  });

  /// Подпись длительности для отображения: «60 мин»
  String get duration => '$durationMinutes мин';
}

class MasterReviewItem {
  final String authorName;
  final double rating;
  final String date;
  final String comment;

  const MasterReviewItem({required this.authorName, required this.rating, required this.date, required this.comment});
}

/// Репозиторий профиля мастера (МОК-ДАННЫЕ)
///
/// БЭКЕНД-ИНТЕГРАЦИЯ:
/// Метод [getMasterById] сейчас отдает моки. При подключении бэкенда
/// здесь будет один вызов `dio.get('/api/v1/masters/$id')`.
class MastersRepository {
  static final MastersRepository _instance = MastersRepository._internal();
  factory MastersRepository() => _instance;
  MastersRepository._internal();

  // МОК-ДАННЫЕ: Профили мастеров
  final Map<String, MasterProfileModel> _mockMasters = {
    'm-001': const MasterProfileModel(
      id: 'm-001',
      name: 'Алена Смирнова',
      salonId: 's-001',
      salonName: 'Nur Beauty',
      specialty: 'Топ-мастер маникюра и педикюра',
      rating: 4.9,
      reviewsCount: 124,
      experienceYears: 6,
      avatarAsset: 'assets/images/masters/master_alena.jpg',
      about:
          'Сертифицированный специалист по аппаратному и комбинированному маникюру, наращиванию и smart-педикюру. Работаю со сложной кутикулой и спа-уходом.',
      portfolioImages: [
        'assets/images/portfolio/portfolio_manicure_1.jpg',
        'assets/images/portfolio/portfolio_brows_1.jpg',
        'assets/images/portfolio/portfolio_hair_1.jpg',
      ],
      services: [
        MasterServiceItem(
          id: 'm-001-s1',
          name: 'Комбинированный маникюр + гель-лак',
          durationMinutes: 60,
          creditsPrice: 34,
          sumPrice: 150000,
        ),
        MasterServiceItem(
          id: 'm-001-s2',
          name: 'Smart-педикюр с обработкой стопы',
          durationMinutes: 75,
          creditsPrice: 42,
          sumPrice: 190000,
        ),
        MasterServiceItem(
          id: 'm-001-s3',
          name: 'Снятие + Укрепление ногтей гелем',
          durationMinutes: 45,
          creditsPrice: 20,
          sumPrice: 90000,
        ),
        MasterServiceItem(
          id: 'm-001-s4',
          name: 'Френч / Кастомный дизайн ногтей',
          durationMinutes: 30,
          creditsPrice: 15,
          sumPrice: 60000,
        ),
      ],
      reviews: [
        MasterReviewItem(
          authorName: 'Малика У.',
          rating: 5.0,
          date: 'Вчера',
          comment: 'Алена — лучший мастер города! Маникюр держится 4 недели без сколов. Очень аккуратная и вежливая.',
        ),
        MasterReviewItem(
          authorName: 'Диана К.',
          rating: 5.0,
          date: '3 дня назад',
          comment: 'Идеальный френч, стерильные инструменты открывали прямо при мне. Однозначно рекомендую!',
        ),
        MasterReviewItem(
          authorName: 'Шахло М.',
          rating: 4.8,
          date: '10 октября',
          comment: 'Очень быстро и качественно. Салон Nur Beauty как всегда на высоте.',
        ),
      ],
    ),
    'm-002': const MasterProfileModel(
      id: 'm-002',
      name: 'Сабина Рахимова',
      salonId: 's-001',
      salonName: 'Nur Beauty',
      specialty: 'Бровист & Ламимейкер',
      rating: 4.8,
      reviewsCount: 92,
      experienceYears: 4,
      avatarAsset: 'assets/images/masters/master_sabina.jpg',
      about:
          'Эксперт по архитектуре бровей, ламинированию ресниц и долговременной укладке. Подбираю форму строго под анатомию лица.',
      portfolioImages: [
        'assets/images/portfolio/portfolio_brows_1.jpg',
        'assets/images/portfolio/portfolio_manicure_1.jpg',
      ],
      services: [
        MasterServiceItem(
          id: 'm-002-s1',
          name: 'Архитектура бровей + окрашивание',
          durationMinutes: 45,
          creditsPrice: 24,
          sumPrice: 110000,
        ),
        MasterServiceItem(
          id: 'm-002-s2',
          name: 'Ламинирование ресниц с ботоксом',
          durationMinutes: 60,
          creditsPrice: 38,
          sumPrice: 170000,
        ),
      ],
      reviews: [
        MasterReviewItem(
          authorName: 'Зарина Т.',
          rating: 5.0,
          date: 'Неделю назад',
          comment: 'Бровки естественные, без черных перетемнений. Спасибо Сабине!',
        ),
      ],
    ),
    'm-003': const MasterProfileModel(
      id: 'm-003',
      name: 'Дилноза Каримова',
      salonId: 's-003',
      salonName: 'Mira Hair',
      specialty: 'Топ-стилист по волосам',
      rating: 4.9,
      reviewsCount: 145,
      experienceYears: 7,
      avatarAsset: 'assets/images/masters/master_dilnoza.jpg',
      about: 'Колорист-эксперт: аиртач, балаяж, сложное окрашивание, авторские женские стрижки и салонный уход.',
      portfolioImages: [
        'assets/images/portfolio/portfolio_hair_1.jpg',
        'assets/images/portfolio/portfolio_brows_1.jpg',
      ],
      services: [
        MasterServiceItem(
          id: 'm-003-s1',
          name: 'Женская стрижка + брашинг',
          durationMinutes: 60,
          creditsPrice: 32,
          sumPrice: 140000,
        ),
        MasterServiceItem(
          id: 'm-003-s2',
          name: 'Сложное окрашивание Balayage',
          durationMinutes: 180,
          creditsPrice: 85,
          sumPrice: 420000,
        ),
        MasterServiceItem(
          id: 'm-003-s3',
          name: 'Женская стрижка',
          durationMinutes: 45,
          creditsPrice: 26,
          sumPrice: 110000,
        ),
      ],
      reviews: [
        MasterReviewItem(
          authorName: 'Нилуфар Х.',
          rating: 5.0,
          date: '2 дня назад',
          comment: 'Цвет волос получился именно такой, как на фото из Pinterest! Дилноза — супер профи.',
        ),
      ],
    ),
    'm-004': const MasterProfileModel(
      id: 'm-004',
      name: 'Мадина Умарова',
      salonId: 's-001',
      salonName: 'Nur Beauty',
      specialty: 'Косметолог-эстетист',
      rating: 4.9,
      reviewsCount: 78,
      experienceYears: 5,
      avatarAsset: 'assets/images/masters/master_madina.jpg',
      about:
          'Медицинское образование. Уходовые процедуры, ультразвуковая чистка, безинъекционная мезотерапия и пилинги.',
      portfolioImages: ['assets/images/portfolio/portfolio_brows_1.jpg'],
      services: [
        MasterServiceItem(
          id: 'm-004-s1',
          name: 'Комбинированная чистка лица',
          durationMinutes: 90,
          creditsPrice: 45,
          sumPrice: 200000,
        ),
      ],
      reviews: [
        MasterReviewItem(
          authorName: 'Елена П.',
          rating: 5.0,
          date: 'Вчера',
          comment: 'Кожа после процедуры сияет! Очень деликатный подход.',
        ),
      ],
    ),
  };

  /// Получить всех мастеров
  /// [BACKEND NOTE]: GET /api/v1/masters
  List<MasterProfileModel> getMasters() {
    return _mockMasters.values.toList();
  }

  /// Мастера конкретного салона
  /// [BACKEND NOTE]: GET /api/v1/salons/:id/masters
  List<MasterProfileModel> getMastersForSalon(String salonId) {
    return _mockMasters.values.where((m) => m.salonId == salonId).toList();
  }

  /// Мастер по id; `null`, если такого нет — подставлять «похожего» нельзя.
  /// [BACKEND NOTE]: GET /api/v1/masters/:id
  MasterProfileModel? getMasterById(String id) => _mockMasters[id];
}
