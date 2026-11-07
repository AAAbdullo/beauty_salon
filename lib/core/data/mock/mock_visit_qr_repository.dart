import '../../models/booking_rules.dart';
import '../../services/app_state_service.dart';
import '../../utils/clock.dart';
import '../repository_exception.dart';
import '../repositories/visit_qr_repository.dart';
import 'mock_network.dart';

/// Мок QR визита. Токен выдаётся и проверяется «на сервере» (`AppStateService`):
/// срок жизни 60 секунд, одноразовый nonce, проверка салона и окна визита.
class MockVisitQrRepository implements VisitQrRepository {
  MockVisitQrRepository({MockNetwork? network, AppStateService? state})
    : _network = network ?? MockNetwork(),
      _state = state ?? AppStateService();

  final MockNetwork _network;
  final AppStateService _state;

  @override
  Future<VisitQrToken> issueToken(String bookingId) => _network(() {
    final booking = _state.bookingById(bookingId);
    if (booking == null) throw const RepositoryException('Запись не найдена. Обновите список записей.');
    return VisitQrToken(
      value: _state.visitQrToken(booking),
      expiresAt: AppClock.now().add(const Duration(seconds: BookingRules.qrLifetimeSeconds)),
    );
  });

  @override
  Future<VisitQrResult> verifyAndConfirm(String raw, {bool ignoreTimeWindow = false}) =>
      _network(() => _state.validateVisitQr(raw, ignoreTimeWindow: ignoreTimeWindow));
}
