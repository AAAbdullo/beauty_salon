import '../../models/master_review.dart';
import '../../models/salon_filter_params.dart';
import '../../services/masters_repository.dart';
import '../../services/salons_repository.dart';

/// Всё, что нужно странице салона, одним ответом
class SalonDetails {
  final SalonModel salon;
  final List<MasterServiceItem> services;
  final List<MasterProfileModel> masters;
  /// Свежие отзывы о мастерах салона (первая страница)
  final List<MasterReview> reviews;
  final List<String> photos;

  const SalonDetails({
    required this.salon,
    required this.services,
    required this.masters,
    required this.reviews,
    required this.photos,
  });
}

/// Каталог салонов и мастеров.
/// Методы бросают `RepositoryException` при сбое сети; «не найдено» — это `null`, а не подстановка другого объекта.
/// [BACKEND NOTE]: GET /api/v1/catalog/salons, /salons/:id, /masters, /masters/:id
abstract interface class CatalogRepository {
  Future<List<SalonModel>> getSalons([SalonFilterParams? params]);
  Future<SalonDetails?> getSalonDetails(String salonId);
  Future<List<MasterProfileModel>> getMasters();
  Future<MasterProfileModel?> getMaster(String masterId);
}
