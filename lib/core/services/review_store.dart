import '../models/booking_item.dart';
import '../models/master_review.dart';
import '../utils/clock.dart';
import 'masters_repository.dart';

/// Хранилище отзывов — часть мок-«сервера». Правила (кто и когда может оставить отзыв) проверяет
/// `AppStateService`, здесь только данные и расчёт сводок.
///
/// Рейтинг мастера не хранится числом: он считается по отзывам. Чтобы в моке сохранились «124 отзыва»,
/// у мастера есть «старые» отзывы вне списка (количество и сумма оценок) — они входят в среднее и счётчик,
/// но не показываются.
class ReviewStore {
  ReviewStore._(this._byId, this._base);

  final Map<String, MasterReview> _byId;
  final Map<String, _Base> _base;

  /// Начальные отзывы: из сидов мастеров и из уже оценённых записей клиента
  factory ReviewStore.seed({required List<MasterProfileModel> masters, required List<BookingItem> bookings}) {
    final now = AppClock.now();
    final byId = <String, MasterReview>{};
    final base = <String, _Base>{};
    final byMaster = {for (final m in masters) m.id: m};

    for (final m in masters) {
      var sum = 0;
      for (var i = 0; i < m.reviewSeeds.length; i++) {
        final seed = m.reviewSeeds[i];
        sum += seed.rating;
        final id = 'r-${m.id}-${i + 1}';
        byId[id] = MasterReview(
          id: id,
          bookingId: '',
          masterId: m.id,
          masterName: shortPersonName(m.name),
          salonId: m.salonId,
          serviceName: m.services.isEmpty ? '' : m.services.first.name,
          authorId: 'seed',
          authorName: seed.authorName,
          rating: seed.rating,
          comment: seed.comment,
          createdAt: now.subtract(Duration(days: seed.daysAgo)),
        );
      }
      final oldCount = m.reviewsCount - m.reviewSeeds.length;
      if (oldCount > 0) base[m.id] = _Base(oldCount, (m.rating * m.reviewsCount).round() - sum);
    }

    for (final b in bookings) {
      final reviewId = b.reviewId;
      final rating = b.reviewRating;
      final masterId = b.masterId;
      if (reviewId == null || rating == null || masterId == null) continue;
      final master = byMaster[masterId];
      byId[reviewId] = MasterReview(
        id: reviewId,
        bookingId: b.id,
        masterId: masterId,
        masterName: master == null ? b.masterName : shortPersonName(master.name),
        salonId: b.salonId,
        serviceName: b.serviceName,
        authorId: b.clientId,
        authorName: shortPersonName(b.clientName),
        rating: rating,
        tags: b.reviewTags ?? const [],
        comment: b.reviewComment ?? '',
        createdAt: b.reviewDate ?? b.startsAt,
      );
    }
    return ReviewStore._(byId, base);
  }

  MasterReview? byId(String id) => _byId[id];

  MasterReview? byBooking(String bookingId) {
    if (bookingId.isEmpty) return null;
    for (final r in _byId.values) {
      if (r.bookingId == bookingId) return r;
    }
    return null;
  }

  void put(MasterReview review) => _byId[review.id] = review;

  static int _newestFirst(MasterReview a, MasterReview b) {
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  /// Все отзывы мастера, свежие сверху
  List<MasterReview> forMaster(String masterId) =>
      _byId.values.where((r) => r.masterId == masterId).toList()..sort(_newestFirst);

  /// Страница отзывов мастера. Курсор — смещение в упорядоченном списке.
  ReviewPage page(String masterId, {String? cursor, int size = ReviewRules.pageSize}) {
    final all = forMaster(masterId);
    final start = (int.tryParse(cursor ?? '') ?? 0).clamp(0, all.length);
    final end = (start + size).clamp(0, all.length);
    return ReviewPage(items: all.sublist(start, end), nextCursor: end < all.length ? '$end' : null);
  }

  /// Отзывы всех мастеров салона, свежие сверху
  List<MasterReview> forSalon(String salonId, {int limit = ReviewRules.pageSize}) {
    final all = _byId.values.where((r) => r.salonId == salonId).toList()..sort(_newestFirst);
    return all.take(limit).toList();
  }

  /// Количество и сумма оценок мастера (с «старыми» отзывами вне списка)
  ({int count, int sum}) totals(String masterId) {
    var count = 0;
    var sum = 0;
    for (final r in _byId.values) {
      if (r.masterId != masterId) continue;
      count++;
      sum += r.rating;
    }
    final base = _base[masterId];
    return (count: count + (base?.count ?? 0), sum: sum + (base?.sum ?? 0));
  }

  static double averageOf(int sum, int count) => count == 0 ? 0 : (sum * 10 / count).round() / 10;

  ReviewSummary summary(String masterId) {
    final t = totals(masterId);
    if (t.count == 0) return ReviewSummary.empty;
    final byStars = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in _byId.values) {
      if (r.masterId == masterId) byStars[r.rating] = byStars[r.rating]! + 1;
    }
    final base = _base[masterId];
    if (base != null) {
      // «Старые» отзывы распределяются между двумя соседними оценками так, чтобы сохранить их среднее
      final low = (base.sum / base.count).floor().clamp(1, 5);
      if (low == 5) {
        byStars[5] = byStars[5]! + base.count;
      } else {
        final high = base.sum - low * base.count;
        byStars[low + 1] = byStars[low + 1]! + high;
        byStars[low] = byStars[low]! + (base.count - high);
      }
    }
    return ReviewSummary(average: averageOf(t.sum, t.count), count: t.count, byStars: byStars);
  }

  /// Общие отзывы салона без мастеров в каталоге (мок): у такого салона нет отзывов о мастерах
  static List<MasterReview> legacySalonReviews(String salonId) {
    final now = AppClock.now();
    return [
      MasterReview(
        id: 'r-$salonId-1',
        bookingId: '',
        masterId: '',
        salonId: salonId,
        serviceName: '',
        authorName: 'Гульнора А.',
        rating: 5,
        comment: 'Уютно, чисто, мастера внимательные. Записалась по кредитам без проблем.',
        createdAt: now.subtract(const Duration(days: 8)),
      ),
      MasterReview(
        id: 'r-$salonId-2',
        bookingId: '',
        masterId: '',
        salonId: salonId,
        serviceName: '',
        authorName: 'Камила Р.',
        rating: 5,
        comment: 'Хороший сервис, приняли точно по времени. Приду ещё.',
        createdAt: now.subtract(const Duration(days: 14)),
      ),
    ];
  }
}

class _Base {
  final int count;
  final int sum;

  const _Base(this.count, this.sum);
}
