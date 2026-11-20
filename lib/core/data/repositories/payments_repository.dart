import '../../utils/result.dart';

class PaymentReceipt {
  final String id;
  final int amount;
  final String provider;
  final DateTime paidAt;

  const PaymentReceipt({required this.id, required this.amount, required this.provider, required this.paidAt});
}

class PaymentError {
  final String message;

  const PaymentError(this.message);

  @override
  String toString() => 'PaymentError($message)';
}

/// Онлайн-оплата через Click / Payme / Uzum. Данные карты приложение не хранит.
/// [BACKEND NOTE]: POST /api/v1/payments (редирект на провайдера и webhook подтверждения), POST /payments/:id/refund
abstract interface class PaymentsRepository {
  /// Онлайн-оплата. Если платят за запись, передаётся [holdId]: пока идёт оплата, удержание слота продлевается,
  /// а если оно уже истекло — отказ. Для других покупок (пакет кредитов) [holdId] не нужен.
  Future<Result<PaymentReceipt, PaymentError>> pay({
    required int amount,
    required String provider,
    String? holdId,
    required String idempotencyKey,
  });

  /// Вернуть платёж (например, если запись после оплаты создать не удалось)
  Future<void> refund({required String receiptId, required String idempotencyKey});
}
