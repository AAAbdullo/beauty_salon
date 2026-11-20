import '../../models/master_review.dart';
import '../../utils/result.dart';

export '../../models/master_review.dart';

/// Отзывы клиентов о мастерах. Отзыв оставляют на подтверждённый визит (по QR), оценивается мастер;
/// рейтинг мастера и салона считается по отзывам и обновляется сразу.
///
/// Правила (один отзыв на запись, окно 7 дней, содержимое, контакты) проверяет сервер. Клиент их не дублирует,
/// а показывает причину отказа из [ReviewError].
///
/// [BACKEND NOTE]:
///   GET   /api/v1/masters/:id/reviews?cursor=   — список (по 20, свежие сверху)
///   GET   /api/v1/masters/:id/reviews/summary   — сводка
///   POST  /api/v1/bookings/:id/review           — создать (Idempotency-Key)
///   PATCH /api/v1/reviews/:id                   — изменить (автор, пока окно открыто)
///   GET   /api/v1/masters/me/reviews            — отзывы о себе (мастер)
///   PUT   /api/v1/reviews/:id/reply             — ответ мастера
abstract interface class ReviewsRepository {
  Future<ReviewPage> masterReviews(String masterId, {String? cursor});

  Future<ReviewSummary> masterSummary(String masterId);

  /// Отзывы всех мастеров салона, свежие сверху
  Future<List<MasterReview>> salonReviews(String salonId, {int limit = 20});

  /// Повтор с тем же [idempotencyKey] возвращает уже созданный отзыв
  Future<Result<MasterReview, ReviewError>> submit({
    required String bookingId,
    required int rating,
    required List<String> tags,
    required String comment,
    required String idempotencyKey,
  });

  Future<Result<MasterReview, ReviewError>> edit({
    required String reviewId,
    required int rating,
    required List<String> tags,
    required String comment,
  });

  /// Отзывы о текущем мастере (по сессии)
  Future<ReviewPage> myReviewsAsMaster({String? cursor});

  /// Публичный ответ мастера; повторный вызов заменяет текст
  Future<Result<MasterReview, ReviewError>> reply({required String reviewId, required String text});
}
