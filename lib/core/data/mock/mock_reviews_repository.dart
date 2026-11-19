import '../../services/app_state_service.dart';
import '../../services/review_store.dart';
import '../../utils/result.dart';
import '../idempotency.dart';
import '../repositories/auth_repository.dart';
import '../repositories/reviews_repository.dart';
import 'mock_network.dart';

/// Мок отзывов. «Сервер» — `AppStateService` (правила) и `ReviewStore` (данные).
class MockReviewsRepository implements ReviewsRepository {
  MockReviewsRepository({MockNetwork? network, AppStateService? state, AuthRepository? auth})
    : _network = network ?? MockNetwork(),
      _state = state ?? AppStateService(),
      _auth = auth;

  final MockNetwork _network;
  final AppStateService _state;
  final AuthRepository? _auth;
  final IdempotencyGuard _guard = IdempotencyGuard();

  ReviewStore get _store => _state.reviews;

  /// Кто «я» как мастер: из сессии мастера, иначе мастер демо-кабинета
  String get _myMasterId {
    final session = _auth?.currentSession;
    return session != null && session.role == UserRole.master ? session.userId : _state.masterId;
  }

  @override
  Future<ReviewPage> masterReviews(String masterId, {String? cursor}) =>
      _network(() => _store.page(masterId, cursor: cursor));

  @override
  Future<ReviewSummary> masterSummary(String masterId) => _network(() => _store.summary(masterId));

  @override
  Future<List<MasterReview>> salonReviews(String salonId, {int limit = 20}) =>
      _network(() => _state.salonReviews(salonId, limit: limit));

  @override
  Future<Result<MasterReview, ReviewError>> submit({
    required String bookingId,
    required int rating,
    required List<String> tags,
    required String comment,
    required String idempotencyKey,
  }) => _guard.run(
    'review:$idempotencyKey',
    () => _network(
      () => _state.submitReview(bookingId: bookingId, rating: rating, tags: tags, comment: comment),
    ),
  );

  @override
  Future<Result<MasterReview, ReviewError>> edit({
    required String reviewId,
    required int rating,
    required List<String> tags,
    required String comment,
  }) => _network(() => _state.editReview(reviewId: reviewId, rating: rating, tags: tags, comment: comment));

  @override
  Future<ReviewPage> myReviewsAsMaster({String? cursor}) =>
      _network(() => _store.page(_myMasterId, cursor: cursor));

  @override
  Future<Result<MasterReview, ReviewError>> reply({required String reviewId, required String text}) =>
      _network(() => _state.replyToReview(reviewId: reviewId, text: text, asMasterId: _myMasterId));
}
