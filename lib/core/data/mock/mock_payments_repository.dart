import '../../utils/clock.dart';
import '../../utils/result.dart';
import '../../utils/uuid.dart';
import '../idempotency.dart';
import '../repositories/payments_repository.dart';
import 'mock_network.dart';
import 'mock_slots_repository.dart';

/// Мок онлайн-оплаты. Платёж «привязан» к удержанию слота: нет действующего удержания — нет оплаты,
/// а пока оплата идёт, удержание продлевается, чтобы слот не пропал между оплатой и созданием записи.
class MockPaymentsRepository implements PaymentsRepository {
  MockPaymentsRepository({required MockSlotsRepository slots, MockNetwork? network})
    : _slots = slots,
      _network = network ?? MockNetwork();

  final MockSlotsRepository _slots;
  final MockNetwork _network;
  final IdempotencyGuard _guard = IdempotencyGuard();

  /// На сколько продлевается удержание на время оплаты
  static const paymentWindow = Duration(minutes: 5);

  /// Платёж отклонит провайдер (для тестов)
  bool declineNext = false;

  final Set<String> _refunded = {};

  /// Все выданные квитанции (для тестов: проверить, что платёж без записи вернули)
  final List<PaymentReceipt> receipts = [];

  bool wasRefunded(String receiptId) => _refunded.contains(receiptId);

  PaymentReceipt? receiptById(String receiptId) => receipts.where((r) => r.id == receiptId).firstOrNull;

  /// Возврат, который «сервер» делает сам (например, при отмене записи): без сетевого вызова клиента
  void refundOnServer(String receiptId) => _refunded.add(receiptId);

  @override
  Future<Result<PaymentReceipt, PaymentError>> pay({
    required int amount,
    required String provider,
    String? holdId,
    required String idempotencyKey,
  }) => _guard.run(
    'pay:$idempotencyKey',
    () => _network<Result<PaymentReceipt, PaymentError>>(() {
      if (holdId != null && _slots.extendHold(holdId, paymentWindow) == null) {
        return const Result.failure(PaymentError('Время удержания слота истекло. Оплата не выполнена.'));
      }
      if (declineNext) {
        declineNext = false;
        return Result.failure(PaymentError('Платёж отклонён ($provider). Попробуйте другой способ оплаты.'));
      }
      final receipt = PaymentReceipt(id: 'pay_${Uuid.v4()}', amount: amount, provider: provider, paidAt: AppClock.now());
      receipts.add(receipt);
      return Result.success(receipt);
    }),
  );

  @override
  Future<void> refund({required String receiptId, required String idempotencyKey}) =>
      _guard.run('refund:$idempotencyKey', () => _network(() => _refunded.add(receiptId)));
}
