import '../../models/booking_error.dart';
import '../../utils/result.dart';

/// Абонемент: покупка пакета и заморозка.
/// [BACKEND NOTE]: POST /api/v1/subscriptions, POST /subscriptions/freeze, DELETE /subscriptions/freeze
abstract interface class SubscriptionRepository {
  Future<Result<void, BookingError>> purchasePackage({
    required String planName,
    required int credits,
    required String idempotencyKey,
  });

  Future<Result<void, BookingError>> freeze({required int days, required String idempotencyKey});

  Future<Result<void, BookingError>> unfreeze({required String idempotencyKey});
}
