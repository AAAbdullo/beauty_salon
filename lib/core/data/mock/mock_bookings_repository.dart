import '../../services/app_state_service.dart';
import '../../utils/result.dart';
import '../idempotency.dart';
import '../repositories/bookings_repository.dart';
import 'mock_network.dart';
import 'mock_payments_repository.dart';
import 'mock_slots_repository.dart';

/// Мок операций с записями. «Сервер» — это `AppStateService` (правила) и удержания слотов.
/// Каждая изменяющая операция выполняется один раз на ключ идемпотентности.
class MockBookingsRepository implements BookingsRepository {
  MockBookingsRepository({
    required MockSlotsRepository slots,
    MockNetwork? network,
    AppStateService? state,
    MockPaymentsRepository? payments,
  }) : _slots = slots,
       _network = network ?? MockNetwork(),
       _state = state ?? AppStateService(),
       _payments = payments;

  /// «Сервер» знает платежи: по квитанции записи он берёт сумму и сам возвращает деньги при отмене
  final MockPaymentsRepository? _payments;
  final MockSlotsRepository _slots;
  final MockNetwork _network;
  final AppStateService _state;
  final IdempotencyGuard _guard = IdempotencyGuard();

  @override
  Future<Result<void, BookingError>> validate({
    required String salonId,
    String? masterId,
    required String serviceId,
    required DateTime startsAt,
    required int durationMinutes,
    required int baseCredits,
    required String paymentMethod,
  }) => _network(
    () => _state.validateNewBooking(
      salonId: salonId,
      masterId: masterId,
      serviceId: serviceId,
      startsAt: startsAt,
      durationMinutes: durationMinutes,
      baseCredits: baseCredits,
      paymentMethod: paymentMethod,
    ),
  );

  @override
  Future<Result<BookingItem, BookingError>> create(CreateBookingRequest r) => _guard.run(
    'create:${r.idempotencyKey}',
    () => _network<Result<BookingItem, BookingError>>(() {
      final hold = _slots.activeHold(r.holdId);
      if (hold == null) {
        return const Result.failure(
          BookingError(BookingErrorCode.holdExpired, 'Время удержания слота истекло. Выберите время заново.'),
        );
      }
      if (hold.salonId != r.salonId || hold.serviceId != r.serviceId || hold.startsAt != r.startsAt) {
        return const Result.failure(
          BookingError(BookingErrorCode.slotUnavailable, 'Выбранное время изменилось. Выберите слот заново.'),
        );
      }

      final result = _state.createBooking(
        salonId: r.salonId,
        salonName: r.salonName,
        serviceId: r.serviceId,
        serviceName: r.serviceName,
        // Мастер закреплён за слотом при удержании («Любой мастер» уже заменён конкретным)
        masterId: hold.masterId ?? r.masterId,
        masterName: r.masterName,
        dateTime: r.startsAt,
        durationMinutes: r.durationMinutes,
        baseCredits: r.baseCredits,
        sumPrice: r.sumPrice,
        paymentMethod: r.paymentMethod,
        paymentReceiptId: r.paymentReceiptId,
        paidAmount: r.paymentReceiptId == null ? null : _payments?.receiptById(r.paymentReceiptId!)?.amount,
      );
      if (result.isSuccess) _slots.consumeHold(r.holdId);
      return result;
    }),
  );

  @override
  Future<Result<BookingItem, BookingError>> cancel({required String bookingId, required String idempotencyKey}) =>
      _guard.run(
        'cancel:$idempotencyKey',
        () => _network<Result<BookingItem, BookingError>>(() {
          final result = _state.cancelBooking(bookingId);
          // Отмена и возврат оплаты — одна операция на сервере: нельзя отменить и не вернуть деньги
          final receiptId = result.valueOrNull?.paymentReceiptId;
          if (receiptId != null) _payments?.refundOnServer(receiptId);
          return result;
        }),
      );

  @override
  Future<Result<BookingItem, BookingError>> reschedule({
    required String bookingId,
    required DateTime newStartsAt,
    required String idempotencyKey,
  }) => _guard.run(
    'reschedule:$idempotencyKey',
    () => _network(() => _state.rescheduleBooking(bookingId: bookingId, newDateTime: newStartsAt)),
  );
}
