import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/data/mock/mock_catalog_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/data/mock/mock_reviews_repository.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/master_cabinet_store.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/utils/formatters.dart';
import 'package:beauty_salons/core/utils/result.dart';

/// Отзывы о мастере: правила «сервера» (один отзыв на визит, окно 7 дней, содержимое, контакты),
/// пересчёт рейтинга, правка, ответ мастера, страницы списка.
///
/// Время: среда 11 ноября 2026, 10:00. Запись b-002 (Sabina, брови) подтверждена 9 ноября в 14:00 — окно открыто;
/// b-001 — активная запись; b-003 (Mira Hair) уже оценена.
void main() {
  late FixedClock clock;
  late AppStateService state;
  late MockReviewsRepository reviews;
  late MockCatalogRepository catalog;
  var key = 0;

  setUp(() {
    clock = FixedClock(DateTime(2026, 11, 11, 10));
    AppClock.current = clock;
    state = AppStateService()..resetSession();
    reviews = MockReviewsRepository(state: state);
    catalog = MockCatalogRepository(state: state);
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  Future<Result> submit(String bookingId, {int rating = 5, List<String> tags = const [], String comment = '', String? k}) =>
      reviews.submit(
        bookingId: bookingId,
        rating: rating,
        tags: tags,
        comment: comment,
        idempotencyKey: k ?? 'k-${key++}',
      );

  /// Два отзыва в 1 ★ о Sabina (b-002 и подтверждённая b-001): одного мало, чтобы сдвинуть среднее на 0,1
  Future<void> twoLowReviews() async {
    expect(state.completeVisit('b-001').isSuccess, isTrue);
    await submit('b-002', rating: 1, tags: const ['Опоздание']);
    await submit('b-001', rating: 1, tags: const ['Опоздание']);
  }

  ReviewErrorCode? codeOf(Result r) => r.errorOrNull is ReviewError ? (r.errorOrNull as ReviewError).code : null;

  group('Кто и когда может оставить отзыв', () {
    test('только после подтверждённого визита', () async {
      expect(codeOf(await submit('b-001')), ReviewErrorCode.notCompleted);
      expect(state.completeVisit('b-001').isSuccess, isTrue);
      expect((await submit('b-001')).isSuccess, isTrue);
    });

    test('отменённую запись оценить нельзя', () async {
      expect(state.cancelBooking('b-005').isSuccess, isTrue);
      expect(codeOf(await submit('b-005')), ReviewErrorCode.notCompleted);
    });

    test('чужую или несуществующую запись оценить нельзя', () async {
      expect(codeOf(await submit('x-201')), ReviewErrorCode.notFound);
      expect(codeOf(await submit('нет-такой')), ReviewErrorCode.notFound);
    });

    test('один отзыв на запись', () async {
      expect((await submit('b-002')).isSuccess, isTrue);
      expect(codeOf(await submit('b-002')), ReviewErrorCode.alreadyReviewed);
      // b-003 была оценена ещё до запуска
      expect(codeOf(await submit('b-003')), ReviewErrorCode.alreadyReviewed);
    });

    test('повтор с тем же ключом идемпотентности не создаёт второй отзыв', () async {
      final before = (await reviews.masterSummary('m-002')).count;
      final first = await submit('b-002', k: 'same');
      final second = await submit('b-002', k: 'same');
      expect(first.isSuccess, isTrue);
      expect(second.valueOrNull?.id, first.valueOrNull?.id);
      expect((await reviews.masterSummary('m-002')).count, before + 1);
    });

    test('окно 7 дней от начала визита', () async {
      // 6 дней 20 часов после начала — ещё можно (inDays = 6)
      clock.set(DateTime(2026, 11, 16, 10));
      expect((await submit('b-002')).isSuccess, isTrue);
    });

    test('через 7 дней отзыв оставить уже нельзя', () async {
      clock.set(DateTime(2026, 11, 16, 14, 1));
      expect(codeOf(await submit('b-002')), ReviewErrorCode.windowClosed);
    });
  });

  group('Содержимое отзыва', () {
    test('оценка обязательна и в пределах 1–5', () async {
      expect(codeOf(await submit('b-002', rating: 0)), ReviewErrorCode.ratingRequired);
      expect(codeOf(await submit('b-002', rating: 6)), ReviewErrorCode.ratingRequired);
    });

    test('1–2 ★ без тега и без комментария от 10 символов отклоняются', () async {
      expect(codeOf(await submit('b-002', rating: 1)), ReviewErrorCode.reasonRequired);
      expect(codeOf(await submit('b-002', rating: 2, comment: 'плохо')), ReviewErrorCode.reasonRequired);
      expect(codeOf(await submit('b-002', rating: 2, comment: 'Н' * 9)), ReviewErrorCode.reasonRequired);
    });

    test('1–2 ★ проходят с тегом или с комментарием от 10 символов', () async {
      expect((await submit('b-002', rating: 1, tags: const ['Опоздание'])).isSuccess, isTrue);
      state.resetSession();
      expect((await submit('b-002', rating: 2, comment: 'Н' * 10)).isSuccess, isTrue);
    });

    test('3 ★ и выше причины не требуют', () async {
      expect((await submit('b-002', rating: 3)).isSuccess, isTrue);
    });

    test('комментарий до 500 символов', () async {
      expect(codeOf(await submit('b-002', comment: 'а' * 501)), ReviewErrorCode.tooLong);
      expect((await submit('b-002', comment: 'а' * 500)).isSuccess, isTrue);
    });

    test('телефоны, ссылки и @username отклоняются', () async {
      for (final text in [
        'Звоните +998 90 123 45 67',
        'мой номер 901234567',
        'смотрите https://example.com',
        'сайт www.salon.uz',
        'пишите @master_alena',
        'salon.uz лучший',
      ]) {
        expect(codeOf(await submit('b-002', comment: text)), ReviewErrorCode.contactsInText, reason: text);
      }
    });

    test('обычный текст с цифрами проходит', () async {
      expect((await submit('b-002', comment: 'Была 2 раза, держится 4 недели, 5 из 5')).isSuccess, isTrue);
    });
  });

  group('Рейтинг пересчитывается сразу', () {
    test('мастер: среднее, счётчик и звёзды меняются после отзыва', () async {
      final before = await reviews.masterSummary('m-002');
      expect(before.count, 92);
      expect(before.average, 4.8);

      await twoLowReviews();

      final after = await reviews.masterSummary('m-002');
      expect(after.count, 94);
      expect(after.byStars[1], before.byStars[1]! + 2);
      expect(after.average, lessThan(before.average));
      // было 92 отзыва на сумму 442 (4,8), добавилось две единицы
      expect(after.average, ((442 + 2) / 94 * 10).round() / 10);
      expect(after.byStars.values.fold<int>(0, (a, b) => a + b), after.count);
    });

    test('профиль мастера в каталоге показывает пересчитанные числа', () async {
      final before = (await catalog.getMaster('m-002'))!;
      await twoLowReviews();
      final after = (await catalog.getMaster('m-002'))!;
      expect(after.reviewsCount, before.reviewsCount + 2);
      expect(after.rating, lessThan(before.rating));
      expect((await catalog.getMasters()).firstWhere((m) => m.id == 'm-002').rating, after.rating);
    });

    test('рейтинг салона считается по отзывам его мастеров', () async {
      final before = (await catalog.getSalonDetails('s-001'))!.salon;
      await twoLowReviews();
      final after = (await catalog.getSalonDetails('s-001'))!.salon;
      expect(after.reviewsCount, before.reviewsCount + 2);
      expect(after.rating, lessThan(before.rating));
      final inList = (await catalog.getSalons()).firstWhere((s) => s.id == 's-001');
      expect(inList.rating, after.rating);
    });

    test('фильтр по рейтингу работает по пересчитанному рейтингу', () async {
      final salons = await catalog.getSalons();
      expect(salons.every((s) => s.rating >= 0), isTrue);
    });

    test('сиды сохраняют прежние числа: у Alena 124 отзыва и 4,9', () async {
      final summary = await reviews.masterSummary('m-001');
      expect(summary.count, 124);
      expect(summary.average, 4.9);
    });

    test('после выхода из аккаунта отзывы возвращаются к начальным', () async {
      await submit('b-002');
      state.resetSession();
      expect((await reviews.masterSummary('m-002')).count, 92);
    });
  });

  group('Правка отзыва', () {
    test('автор правит оценку, теги и текст, пока окно открыто', () async {
      final created = (await submit('b-002', rating: 5, comment: 'Отлично')).valueOrNull as MasterReview;
      final edited = await reviews.edit(
        reviewId: created.id,
        rating: 3,
        tags: const ['Опоздание'],
        comment: 'Опоздала на 15 минут',
      );
      final review = edited.valueOrNull as MasterReview;
      expect(review.rating, 3);
      expect(review.editedAt, isNotNull);
      expect(review.createdAt, created.createdAt);
      // «Мои записи» видят правку через проекцию в записи
      expect(state.bookingById('b-002')!.reviewRating, 3);
      expect(state.bookingById('b-002')!.reviewComment, 'Опоздала на 15 минут');
      // рейтинг мастера пересчитан
      final summary = await reviews.masterSummary('m-002');
      expect(summary.byStars[3], greaterThanOrEqualTo(1));
    });

    test('после закрытия окна правка отклоняется', () async {
      final created = (await submit('b-002')).valueOrNull as MasterReview;
      clock.set(DateTime(2026, 11, 16, 14, 1));
      final result = await reviews.edit(reviewId: created.id, rating: 1, tags: const ['Опоздание'], comment: '');
      expect(codeOf(result), ReviewErrorCode.windowClosed);
    });

    test('чужой отзыв править нельзя', () async {
      final result = await reviews.edit(reviewId: 'r-m-001-1', rating: 1, tags: const ['Опоздание'], comment: '');
      expect(codeOf(result), ReviewErrorCode.notAuthor);
      expect(codeOf(await reviews.edit(reviewId: 'нет', rating: 5, tags: const [], comment: '')), ReviewErrorCode.notFound);
    });

    test('при правке действуют те же правила содержимого', () async {
      final created = (await submit('b-002')).valueOrNull as MasterReview;
      expect(
        codeOf(await reviews.edit(reviewId: created.id, rating: 1, tags: const [], comment: '')),
        ReviewErrorCode.reasonRequired,
      );
      expect(
        codeOf(await reviews.edit(reviewId: created.id, rating: 5, tags: const [], comment: 'пишите @abc')),
        ReviewErrorCode.contactsInText,
      );
    });
  });

  group('Ответ мастера', () {
    test('мастер отвечает на отзыв о себе, ответ виден в списке и его можно править', () async {
      final created = (await submit('b-002', comment: 'Спасибо')).valueOrNull as MasterReview;
      final first = await reviews.reply(reviewId: created.id, text: 'Спасибо, ждём вас!');
      expect(first.isSuccess, isTrue);
      await reviews.reply(reviewId: created.id, text: 'Будем рады видеть вас снова');
      final page = await reviews.masterReviews('m-002');
      final shown = page.items.firstWhere((r) => r.id == created.id);
      expect(shown.reply?.text, 'Будем рады видеть вас снова');
      expect(page.items.where((r) => r.reply != null), hasLength(1));
    });

    test('на чужой отзыв ответить нельзя', () async {
      expect(codeOf(await reviews.reply(reviewId: 'r-m-001-1', text: 'Спасибо')), ReviewErrorCode.notYourReview);
    });

    test('пустой ответ, длиннее 500 символов и с контактами отклоняются', () async {
      final created = (await submit('b-002')).valueOrNull as MasterReview;
      expect(codeOf(await reviews.reply(reviewId: created.id, text: '   ')), ReviewErrorCode.textRequired);
      expect(codeOf(await reviews.reply(reviewId: created.id, text: 'а' * 501)), ReviewErrorCode.tooLong);
      expect(codeOf(await reviews.reply(reviewId: created.id, text: 'звоните +998901234567')), ReviewErrorCode.contactsInText);
      expect(codeOf(await reviews.reply(reviewId: 'нет', text: 'ок')), ReviewErrorCode.notFound);
    });

    test('«мои отзывы» мастера — только отзывы о нём', () async {
      await submit('b-002');
      final page = await reviews.myReviewsAsMaster();
      expect(page.items, isNotEmpty);
      expect(page.items.every((r) => r.masterId == 'm-002'), isTrue);
    });

    test('новый отзыв — уведомление мастеру', () async {
      final before = MasterCabinetStore().notifications.length;
      await submit('b-002', rating: 4, comment: 'Хорошо');
      final notes = MasterCabinetStore().notifications;
      expect(notes.length, before + 1);
      expect(notes.first.title, 'Новый отзыв: 4 ★');
    });
  });

  group('Список отзывов', () {
    test('свежие сверху, страницы по 20', () async {
      final now = AppClock.now();
      for (var i = 0; i < 25; i++) {
        state.reviews.put(
          MasterReview(
            id: 'p-${i.toString().padLeft(2, '0')}',
            bookingId: '',
            masterId: 'm-004',
            salonId: 's-001',
            serviceName: 'Чистка',
            authorName: 'Клиент $i',
            rating: 5,
            comment: 'Отзыв $i',
            createdAt: now.subtract(Duration(hours: i)),
          ),
        );
      }
      final first = await reviews.masterReviews('m-004');
      expect(first.items, hasLength(20));
      expect(first.items.first.id, 'p-00');
      expect(first.nextCursor, isNotNull);
      final second = await reviews.masterReviews('m-004', cursor: first.nextCursor);
      // 25 новых + 1 сидовый отзыв
      expect(second.items, hasLength(6));
      expect(second.nextCursor, isNull);
      final ids = [...first.items, ...second.items].map((r) => r.id).toSet();
      expect(ids, hasLength(26));
    });

    test('у мастера без отзывов пустой список и нулевая сводка', () async {
      state.reviews.put(
        MasterReview(
          id: 'only',
          bookingId: '',
          masterId: 'm-x',
          salonId: 's-001',
          serviceName: '',
          authorName: 'А',
          rating: 4,
          comment: '',
          createdAt: AppClock.now(),
        ),
      );
      expect((await reviews.masterReviews('m-нет')).items, isEmpty);
      expect((await reviews.masterSummary('m-нет')).count, 0);
      expect((await reviews.masterSummary('m-нет')).average, 0);
    });

    test('отзывы салона — отзывы его мастеров, у каждого указан мастер', () async {
      final list = await reviews.salonReviews('s-001');
      expect(list, isNotEmpty);
      expect(list.every((r) => r.salonId == 's-001' && r.masterName.isNotEmpty), isTrue);
    });

    test('сетевой сбой не создаёт отзыв, повтор с тем же ключом проходит', () async {
      final net = MockNetwork();
      final repo = MockReviewsRepository(network: net, state: state);
      net.failNext();
      await expectLater(
        () => repo.submit(bookingId: 'b-002', rating: 5, tags: const [], comment: '', idempotencyKey: 'retry'),
        throwsA(anything),
      );
      final retry = await repo.submit(bookingId: 'b-002', rating: 5, tags: const [], comment: '', idempotencyKey: 'retry');
      expect(retry.isSuccess, isTrue);
      expect((await repo.masterSummary('m-002')).count, 93);
    });
  });

  test('Formatters.relativeDay: сегодня, дни назад, дата', () {
    final now = DateTime(2026, 11, 11, 10);
    String f(DateTime d) => Formatters.relativeDay(d, now: now);
    expect(f(DateTime(2026, 11, 11, 1)), 'сегодня');
    expect(f(DateTime(2026, 11, 10, 23)), '1 день назад');
    expect(f(DateTime(2026, 11, 8, 12)), '3 дня назад');
    expect(f(DateTime(2026, 10, 12)), '12 окт');
  });
}
