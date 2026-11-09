import '../../models/booking_error.dart';
import '../../models/credit_package.dart';
import '../../utils/result.dart';

/// Абонемент: покупка пакета и заморозка.
/// [BACKEND NOTE]: POST /api/v1/subscriptions, POST /subscriptions/freeze, DELETE /subscriptions/freeze
abstract interface class SubscriptionRepository {
  /// Пакеты кредитов, которые можно купить
  Future<List<CreditPackage>> packages();

  /// Купить пакет [planName] по квитанции онлайн-оплаты [paymentReceiptId]. Объём и цену знает сервер:
  /// клиент их не передаёт, а квитанция должна быть на полную цену пакета и использоваться один раз.
  Future<Result<void, BookingError>> purchasePackage({
    required String planName,
    required String paymentReceiptId,
    required String idempotencyKey,
  });

  Future<Result<void, BookingError>> freeze({required int days, required String idempotencyKey});

  Future<Result<void, BookingError>> unfreeze({required String idempotencyKey});
}
