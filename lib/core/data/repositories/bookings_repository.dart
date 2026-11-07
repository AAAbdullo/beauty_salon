import '../../models/booking_error.dart';
import '../../models/booking_item.dart';
import '../../utils/result.dart';

/// Запрос на создание записи. [idempotencyKey] идентифицирует попытку: повтор с тем же ключом
/// (двойной тап, повтор после обрыва) не создаст вторую запись.
class CreateBookingRequest {
  final String idempotencyKey;

  /// Удержание слота, полученное на экране записи
  final String holdId;
  final String salonId;
  final String salonName;
  final String serviceId;
  final String serviceName;
  final String? masterId;
  final String masterName;
  final DateTime startsAt;
  final int durationMinutes;
  final int baseCredits;
  final int sumPrice;
  final String paymentMethod;

  /// Квитанция онлайн-оплаты, если оплачено заранее
  final String? paymentReceiptId;

  const CreateBookingRequest({
    required this.idempotencyKey,
    required this.holdId,
    required this.salonId,
    required this.salonName,
    required this.serviceId,
    required this.serviceName,
    this.masterId,
    required this.masterName,
    required this.startsAt,
    required this.durationMinutes,
    required this.baseCredits,
    required this.sumPrice,
    required this.paymentMethod,
    this.paymentReceiptId,
  });
}

/// Операции с записями клиента. Каждая изменяющая операция принимает ключ идемпотентности.
/// Список записей читается из `AppStateService` (локальный реактивный кэш), который репозиторий обновляет.
/// [BACKEND NOTE]: POST /api/v1/bookings, POST /bookings/:id/cancel, PATCH /bookings/:id/reschedule, POST /bookings/:id/review
abstract interface class BookingsRepository {
  /// Проверка возможности записи без создания (перед онлайн-оплатой)
  Future<Result<void, BookingError>> validate({
    required String salonId,
    String? masterId,
    required String serviceId,
    required DateTime startsAt,
    required int durationMinutes,
    required int baseCredits,
    required String paymentMethod,
  });

  Future<Result<BookingItem, BookingError>> create(CreateBookingRequest request);

  Future<Result<BookingItem, BookingError>> cancel({required String bookingId, required String idempotencyKey});

  Future<Result<BookingItem, BookingError>> reschedule({
    required String bookingId,
    required DateTime newStartsAt,
    required String idempotencyKey,
  });

  Future<Result<BookingItem, BookingError>> addReview({
    required String bookingId,
    required int rating,
    required List<String> tags,
    required String comment,
    required String idempotencyKey,
  });
}
