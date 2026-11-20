import '../../models/credit_package.dart';
import '../../services/app_state_service.dart';
import '../../utils/result.dart';
import '../idempotency.dart';
import '../repositories/subscription_repository.dart';
import 'mock_network.dart';
import 'mock_payments_repository.dart';

/// Мок абонемента. Покупка и заморозка выполняются один раз на ключ идемпотентности —
/// двойной тап по «Оплатить» не начислит кредиты дважды.
class MockSubscriptionRepository implements SubscriptionRepository {
  MockSubscriptionRepository({MockNetwork? network, AppStateService? state, MockPaymentsRepository? payments})
    : _network = network ?? MockNetwork(),
      _state = state ?? AppStateService(),
      _payments = payments;

  final MockNetwork _network;
  final AppStateService _state;

  /// «Сервер» знает платежи и сверяет квитанцию с ценой пакета
  final MockPaymentsRepository? _payments;
  final IdempotencyGuard _guard = IdempotencyGuard();
  final Set<String> _usedReceipts = {};

  @override
  Future<List<CreditPackage>> packages() => _network(() => mockCreditPackages);

  @override
  Future<Result<void, BookingError>> purchasePackage({
    required String planName,
    required String paymentReceiptId,
    required String idempotencyKey,
  }) => _guard.run(
    'purchase:$idempotencyKey',
    () => _network<Result<void, BookingError>>(() {
      final package = mockCreditPackages.where((p) => p.name == planName).firstOrNull;
      if (package == null) {
        return const Result.failure(BookingError(BookingErrorCode.unknownPackage, 'Такого пакета нет.'));
      }
      final payments = _payments;
      if (payments != null) {
        final receipt = payments.receiptById(paymentReceiptId);
        if (receipt == null || receipt.amount != package.price || _usedReceipts.contains(paymentReceiptId)) {
          return const Result.failure(
            BookingError(BookingErrorCode.paymentMismatch, 'Платёж не найден или не совпадает с ценой пакета.'),
          );
        }
      }
      _usedReceipts.add(paymentReceiptId);
      _state.purchasePackage(package.name, package.credits);
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
