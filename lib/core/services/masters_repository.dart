/// Модель мастера салона по ТЗ (M-07: Usta sahifasi)
///
/// БЭКЕНД-ИНТЕГРАЦИЯ:
/// В будущем данные будут приходить с эндпоинта GET /api/v1/catalog/masters/:id
class MasterProfileModel {
  final String id;
  final String name;
  final String salonName;
  final String specialty;
  final double rating;
  final int reviewsCount;
  final int experienceYears;
  final String about;
  final List<String> portfolioImages;
  final List<MasterServiceItem> services;
  final List<MasterReviewItem> reviews;

  const MasterProfileModel({
    required this.id,
    required this.name,
    required this.salonName,
    required this.specialty,
    required this.rating,
    required this.reviewsCount,
    required this.experienceYears,
    required this.about,
    required this.portfolioImages,
    required this.services,
    required this.reviews,
  });
}

class MasterServiceItem {
  final String name;
  final String duration;
  final int creditsPrice;
  final int sumPrice;

  const MasterServiceItem({
    required this.name,
    required this.duration,
    required this.creditsPrice,
    required this.sumPrice,
  });
}

class MasterReviewItem {
  final String authorName;
  final double rating;
  final String date;
  final String comment;

  const MasterReviewItem({
    required this.authorName,
    required this.rating,
    required this.date,
    required this.comment,
  });
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
    'Алена': const MasterProfileModel(
      id: 'm-001',
      name: 'Алена Смирнова',
      salonName: 'Nur Beauty',
      specialty: 'Топ-мастер маникюра и педикюра',
      rating: 4.9,
      reviewsCount: 124,
      experienceYears: 6,
      about:
          'Сертифицированный специалист по аппаратному и комбинированному маникюру, наращиванию и smart-педикюру. Работаю со сложной кутикулой и спа-уходом.',
      portfolioImages: [
        'web/icons/Icon-192.png',
        'web/icons/Icon-512.png',
        'web/icons/Icon-192.png',
        'web/icons/Icon-512.png',
      ],
      services: [
        MasterServiceItem(
          name: 'Комбинированный маникюр + гель-лак',
          duration: '60 мин',
          creditsPrice: 34,
          sumPrice: 150000,
        ),
        MasterServiceItem(
          name: 'Smart-педикюр с обработкой стопы',
          duration: '75 мин',
          creditsPrice: 42,
          sumPrice: 190000,
        ),
        MasterServiceItem(
          name: 'Снятие + Укрепление ногтей гелем',
          duration: '45 мин',
          creditsPrice: 20,
          sumPrice: 90000,
        ),
        MasterServiceItem(
          name: 'Френч / Кастомный дизайн ногтей',
          duration: '30 мин',
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
    'Сабина': const MasterProfileModel(
      id: 'm-002',
      name: 'Сабина Рахимова',
      salonName: 'Nur Beauty',
      specialty: 'Бровист & Ламимейкер',
      rating: 4.8,
      reviewsCount: 92,
      experienceYears: 4,
      about:
          'Эксперт по архитектуре бровей, ламинированию ресниц и долговременной укладке. Подбираю форму строго под анатомию лица.',
      portfolioImages: [
        'web/icons/Icon-192.png',
        'web/icons/Icon-512.png',
      ],
      services: [
        MasterServiceItem(
          name: 'Архитектура бровей + окрашивание',
          duration: '45 мин',
          creditsPrice: 24,
          sumPrice: 110000,
        ),
        MasterServiceItem(
          name: 'Ламинирование ресниц с ботоксом',
          duration: '60 мин',
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
  };

  /// Получить всех мастеров
  /// [BACKEND NOTE]: GET /api/v1/masters
  List<MasterProfileModel> getMasters() {
    return _mockMasters.values.toList();
  }

  MasterProfileModel getMaster(String name) {
    if (_mockMasters.containsKey(name)) {
      return _mockMasters[name]!;
    }
    // Фоллбэк если мастер другой
    return MasterProfileModel(
      id: 'm-default',
      name: name,
      salonName: 'Nur Beauty',
      specialty: 'Стилист-эксперт',
      rating: 4.8,
      reviewsCount: 65,
      experienceYears: 5,
      about: 'Профессиональный мастер индустрии красоты с международным опытом.',
      portfolioImages: ['web/icons/Icon-192.png'],
      services: const [
        MasterServiceItem(
          name: 'Комплексная услуга эксперта',
          duration: '60 мин',
          creditsPrice: 35,
          sumPrice: 160000,
        ),
      ],
      reviews: const [
        MasterReviewItem(
          authorName: 'Клиент Go\'zallik',
          rating: 5.0,
          date: 'Недавно',
          comment: 'Очень довольна качеством обслуживания!',
        ),
      ],
    );
  }
}
