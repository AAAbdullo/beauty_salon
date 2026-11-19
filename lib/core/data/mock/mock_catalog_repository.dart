import '../../models/salon_filter_params.dart';
import '../../services/app_state_service.dart';
import '../../services/masters_repository.dart';
import '../../services/review_store.dart';
import '../../services/salons_repository.dart';
import '../repositories/catalog_repository.dart';
import 'mock_network.dart';

/// Мок каталога: отдаёт локальные мок-данные через асинхронный интерфейс.
/// Рейтинг и число отзывов мастеров и салонов не берутся из мок-данных: их считает «сервер» по отзывам.
class MockCatalogRepository implements CatalogRepository {
  MockCatalogRepository({MockNetwork? network, SalonsRepository? salons, MastersRepository? masters, AppStateService? state})
    : _network = network ?? MockNetwork(),
      _salons = salons ?? SalonsRepository(),
      _masters = masters ?? MastersRepository(),
      _state = state ?? AppStateService();

  final MockNetwork _network;
  final SalonsRepository _salons;
  final MastersRepository _masters;
  final AppStateService _state;

  /// Мастер с рейтингом из сводки отзывов
  MasterProfileModel _master(MasterProfileModel m) {
    final t = _state.reviews.totals(m.id);
    return m.withRating(rating: ReviewStore.averageOf(t.sum, t.count), reviewsCount: t.count);
  }

  /// Рейтинг салона — по отзывам всех его мастеров; салон без мастеров остаётся с мок-значением
  SalonModel _salon(SalonModel s) {
    var count = 0;
    var sum = 0;
    for (final m in _masters.getMastersForSalon(s.id)) {
      final t = _state.reviews.totals(m.id);
      count += t.count;
      sum += t.sum;
    }
    if (count == 0) return s;
    return s.withRating(rating: ReviewStore.averageOf(sum, count), reviewsCount: count);
  }

  @override
  Future<List<SalonModel>> getSalons([SalonFilterParams? params]) =>
      _network(() => _salons.getSalons(params, _salon));

  @override
  Future<SalonDetails?> getSalonDetails(String salonId) => _network<SalonDetails?>(() {
    final salon = _salons.getSalonById(salonId);
    if (salon == null) return null;
    return SalonDetails(
      salon: _salon(salon),
      services: _salons.getSalonServices(salonId),
      masters: _masters.getMastersForSalon(salonId).map(_master).toList(),
      reviews: _state.salonReviews(salonId),
      photos: _salons.getSalonPhotos(salonId),
    );
  });

  @override
  Future<List<MasterProfileModel>> getMasters() => _network(() => _masters.getMasters().map(_master).toList());

  @override
  Future<MasterProfileModel?> getMaster(String masterId) => _network<MasterProfileModel?>(() {
    final master = _masters.getMasterById(masterId);
    return master == null ? null : _master(master);
  });
}
