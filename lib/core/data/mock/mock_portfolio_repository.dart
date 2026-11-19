import '../../services/app_state_service.dart';
import '../../services/portfolio_store.dart';
import '../../utils/result.dart';
import '../idempotency.dart';
import '../repositories/auth_repository.dart';
import '../repositories/portfolio_repository.dart';
import 'mock_network.dart';

/// Мок портфолио. «Сервер» — `PortfolioStore` (данные и правила), кто «я» — из сессии мастера.
class MockPortfolioRepository implements PortfolioRepository {
  MockPortfolioRepository({MockNetwork? network, AppStateService? state, AuthRepository? auth})
    : _network = network ?? MockNetwork(),
      _state = state ?? AppStateService(),
      _auth = auth;

  final MockNetwork _network;
  final AppStateService _state;
  final AuthRepository? _auth;
  final IdempotencyGuard _guard = IdempotencyGuard();

  PortfolioStore get _store => _state.portfolio;

  /// Кто «я» как мастер: из сессии мастера, иначе мастер демо-кабинета
  String get _myMasterId {
    final session = _auth?.currentSession;
    return session != null && session.role == UserRole.master ? session.userId : _state.masterId;
  }

  @override
  Future<List<PortfolioWork>> works(String masterId) => _network(() => _store.works(masterId));

  @override
  Future<List<PortfolioWork>> preview(String masterId) => _network(() => _store.preview(masterId));

  @override
  Future<List<PortfolioWork>> myWorks() => _network(() => _store.works(_myMasterId));

  @override
  Future<bool> consentGiven() => _network(() => _store.consentGiven);

  @override
  Future<Result<PortfolioWork, PortfolioError>> add({
    required String localPath,
    required String serviceId,
    String caption = '',
    bool consentAccepted = false,
    required String idempotencyKey,
  }) => _guard.run(
    'portfolio:$idempotencyKey',
    () => _network(
      () => _store.add(
        masterId: _myMasterId,
        localPath: localPath,
        serviceId: serviceId,
        caption: caption,
        consentAccepted: consentAccepted,
      ),
    ),
  );

  @override
  Future<Result<PortfolioWork, PortfolioError>> update(
    String workId, {
    String? serviceId,
    String? caption,
    bool? pinned,
  }) => _network(() => _store.update(_myMasterId, workId, serviceId: serviceId, caption: caption, pinned: pinned));

  @override
  Future<Result<void, PortfolioError>> remove(String workId) => _network(() => _store.remove(_myMasterId, workId));
}
