import '../../services/app_state_service.dart';
import '../../utils/result.dart';
import '../idempotency.dart';
import '../repositories/subscription_repository.dart';
import 'mock_network.dart';

/// Мок абонемента. Покупка и заморозка выполняются один раз на ключ идемпотентности —
/// двойной тап по «Оплатить» не начислит кредиты дважды.
class MockSubscriptionRepository implements SubscriptionRepository {
  MockSubscriptionRepository({MockNetwork? network, AppStateService? state})
    : _network = network ?? MockNetwork(),
      _state = state ?? AppStateService();

  final MockNetwork _network;
  final AppStateService _state;
  final IdempotencyGuard _guard = IdempotencyGuard();

  @override
  Future<Result<void, BookingError>> purchasePackage({
    required String planName,
    required int credits,
    required String idempotencyKey,
  }) => _guard.run(
    'purchase:$idempotencyKey',
    () => _network<Result<void, BookingError>>(() {
      _state.purchasePackage(planName, credits);
      return const Result.success(null);
    }),
  );

  @override
  Future<Result<void, BookingError>> freeze({required int days, required String idempotencyKey}) => _guard.run(
    'freeze:$idempotencyKey',
    () => _network<Result<void, BookingError>>(() {
      if (_state.freezeSubscription(days)) return const Result.success(null);
      return Result.failure(
        BookingError(BookingErrorCode.freezeNotAllowed, _state.freezeBlockReason ?? 'Не удалось заморозить абонемент'),
      );
    }),
  );

  @override
  Future<Result<void, BookingError>> unfreeze({required String idempotencyKey}) => _guard.run(
    'unfreeze:$idempotencyKey',
    () => _network<Result<void, BookingError>>(() {
      _state.unfreezeSubscription();
      return const Result.success(null);
    }),
  );
}
