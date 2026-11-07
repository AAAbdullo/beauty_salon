import '../../models/salon_filter_params.dart';
import '../../services/masters_repository.dart';
import '../../services/salons_repository.dart';
import '../repositories/catalog_repository.dart';
import 'mock_network.dart';

/// Мок каталога: отдаёт локальные мок-данные через асинхронный интерфейс
class MockCatalogRepository implements CatalogRepository {
  MockCatalogRepository({MockNetwork? network, SalonsRepository? salons, MastersRepository? masters})
    : _network = network ?? MockNetwork(),
      _salons = salons ?? SalonsRepository(),
      _masters = masters ?? MastersRepository();

  final MockNetwork _network;
  final SalonsRepository _salons;
  final MastersRepository _masters;

  @override
  Future<List<SalonModel>> getSalons([SalonFilterParams? params]) => _network(() => _salons.getSalons(params));

  @override
  Future<SalonDetails?> getSalonDetails(String salonId) => _network<SalonDetails?>(() {
    final salon = _salons.getSalonById(salonId);
    if (salon == null) return null;
    return SalonDetails(
      salon: salon,
      services: _salons.getSalonServices(salonId),
      masters: _masters.getMastersForSalon(salonId),
      reviews: _salons.getSalonReviews(salonId),
      photos: _salons.getSalonPhotos(salonId),
    );
  });

  @override
  Future<List<MasterProfileModel>> getMasters() => _network(_masters.getMasters);

  @override
  Future<MasterProfileModel?> getMaster(String masterId) =>
      _network<MasterProfileModel?>(() => _masters.getMasterById(masterId));
}
