import 'package:flutter_test/flutter_test.dart';

import 'package:beauty_salons/core/data/mock/mock_auth_repository.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/data/mock/mock_portfolio_repository.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/masters_repository.dart';
import 'package:beauty_salons/core/services/portfolio_store.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/core/utils/result.dart';

/// Файлы без диска: размеры задаются в тесте, копии и удаления запоминаются
class FakeFiles implements PortfolioFiles {
  final Map<String, int> sizes = {'photo.jpg': 1024};
  final List<String> deleted = [];
  var cleared = false;
  var _n = 0;

  @override
  Future<int?> sizeOf(String path) async => sizes[path];

  @override
  Future<String> copyIn(String sourcePath) async {
    final target = '/app/portfolio/copy_${_n++}.jpg';
    sizes[target] = sizes[sourcePath]!;
    return target;
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);

  @override
  Future<void> deleteAll() async => cleared = true;
}

/// Портфолио мастера: правила «сервера» (лимит 30, закрепление до 3, услуга из своего списка, подпись, файл, согласие).
/// Мастер демо-кабинета — Sabina (m-002): две работы из сидов и две услуги (m-002-s1 брови, m-002-s2 ресницы).
void main() {
  late FixedClock clock;
  late AppStateService state;
  late FakeFiles files;
  late MockPortfolioRepository repo;
  var key = 0;

  setUp(() {
    clock = FixedClock(DateTime(2026, 11, 11, 10));
    AppClock.current = clock;
    state = AppStateService()..resetSession();
    files = FakeFiles();
    state.portfolio = PortfolioStore.seed(masters: MastersRepository().getMasters(), files: files);
    repo = MockPortfolioRepository(state: state);
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  Future<Result<PortfolioWork, PortfolioError>> add({
    String path = 'photo.jpg',
    String serviceId = 'm-002-s1',
    String caption = '',
    bool consent = true,
    String? k,
  }) => repo.add(
    localPath: path,
    serviceId: serviceId,
    caption: caption,
    consentAccepted: consent,
    idempotencyKey: k ?? 'k-${key++}',
  );

  PortfolioErrorCode? codeOf(Result r) => r.errorOrNull is PortfolioError ? (r.errorOrNull as PortfolioError).code : null;

  group('Сиды', () {
    test('каждая работа из portfolioImages привязана к услуге своего мастера', () async {
      for (final m in MastersRepository().getMasters()) {
        final list = await repo.works(m.id);
        expect(list, hasLength(m.portfolioImages.length), reason: m.id);
        for (final w in list) {
          expect(m.services.map((s) => s.id), contains(w.serviceId), reason: '${m.id} ${w.id}');
          expect(w.serviceName, isNotEmpty);
          expect(w.imageRef, startsWith('assets/'));
        }
      }
    });

    test('подходящая услуга выбирается по названию файла: брови → услуга про брови, маникюр → про маникюр', () async {
      expect((await repo.works('m-002')).firstWhere((w) => w.imageRef.contains('brows')).serviceId, 'm-002-s1');
      expect((await repo.works('m-001')).firstWhere((w) => w.imageRef.contains('manicure')).serviceId, 'm-001-s1');
    });
  });

  group('Согласие на фото', () {
    test('без галочки первая публикация отклоняется, с галочкой проходит, дальше галочка не нужна', () async {
      expect(codeOf(await add(consent: false)), PortfolioErrorCode.consentRequired);
      expect(await repo.consentGiven(), isFalse);
      expect((await add()).isSuccess, isTrue);
      expect(await repo.consentGiven(), isTrue);
      expect((await add(consent: false)).isSuccess, isTrue);
    });

    test('согласие хранится в сессии: после выхода спрашивается снова', () async {
      await add();
      state.resetSession();
      expect(await repo.consentGiven(), isFalse);
    });
  });

  group('Лимиты', () {
    test('30 работ на мастера, на 31-й — ошибка; после удаления снова можно', () async {
      for (var i = (await repo.myWorks()).length; i < PortfolioRules.maxWorks; i++) {
        expect((await add()).isSuccess, isTrue, reason: 'работа $i');
      }
      expect(await repo.myWorks(), hasLength(30));
      final over = await add();
      expect(codeOf(over), PortfolioErrorCode.limitReached);
      expect((over.errorOrNull as PortfolioError).message, contains('30'));

      final first = (await repo.myWorks()).last;
      expect((await repo.remove(first.id)).isSuccess, isTrue);
      expect((await add()).isSuccess, isTrue);
    });

    test('закрепить можно не больше 3 работ', () async {
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        ids.add((await add()).valueOrNull!.id);
      }
      for (final id in ids) {
        expect((await repo.update(id, pinned: true)).isSuccess, isTrue);
      }
      final fourth = (await add()).valueOrNull!;
      final result = await repo.update(fourth.id, pinned: true);
      expect(codeOf(result), PortfolioErrorCode.pinLimitReached);
      expect((result.errorOrNull as PortfolioError).message, 'Можно закрепить не больше 3 работ.');

      // повторное закрепление уже закреплённой — не ошибка; открепив одну, можно закрепить другую
      expect((await repo.update(ids.first, pinned: true)).isSuccess, isTrue);
      expect((await repo.update(ids.first, pinned: false)).isSuccess, isTrue);
      expect((await repo.update(fourth.id, pinned: true)).isSuccess, isTrue);
    });
  });

  group('Работа', () {
    test('услуга обязательна и только из услуг этого мастера', () async {
      expect(codeOf(await add(serviceId: 'm-001-s1')), PortfolioErrorCode.unknownService);
      expect(codeOf(await add(serviceId: 'нет')), PortfolioErrorCode.unknownService);
      final work = (await add()).valueOrNull!;
      expect(codeOf(await repo.update(work.id, serviceId: 'm-001-s1')), PortfolioErrorCode.unknownService);
      final changed = await repo.update(work.id, serviceId: 'm-002-s2');
      expect(changed.valueOrNull!.serviceId, 'm-002-s2');
      expect(changed.valueOrNull!.serviceName, 'Ламинирование ресниц с ботоксом');
    });

    test('подпись до 150 символов, без контактов и ссылок', () async {
      expect(codeOf(await add(caption: 'а' * 151)), PortfolioErrorCode.captionTooLong);
      expect((await add(caption: 'а' * 150)).isSuccess, isTrue);
      for (final text in ['звоните +998901234567', 'мой сайт salon.uz', 'пишите @alena_nails', 'https://t.me/x']) {
        expect(codeOf(await add(caption: text)), PortfolioErrorCode.contactsInText, reason: text);
      }
      final work = (await add(caption: 'Френч + укрепление гелем')).valueOrNull!;
      expect(work.caption, 'Френч + укрепление гелем');
      expect(codeOf(await repo.update(work.id, caption: 'а' * 151)), PortfolioErrorCode.captionTooLong);
      expect(codeOf(await repo.update(work.id, caption: 'звоните 90 123 45 67')), PortfolioErrorCode.contactsInText);
      expect((await repo.update(work.id, caption: '')).valueOrNull!.caption, '');
    });

    test('файл тяжелее 10 МБ отклоняется, ровно 10 МБ проходит, отсутствующий файл — «не найден»', () async {
      files.sizes['big.jpg'] = PortfolioRules.maxFileBytes + 1;
      files.sizes['edge.jpg'] = PortfolioRules.maxFileBytes;
      expect(codeOf(await add(path: 'big.jpg')), PortfolioErrorCode.fileTooLarge);
      expect((await add(path: 'edge.jpg')).isSuccess, isTrue);
      expect(codeOf(await add(path: 'missing.jpg')), PortfolioErrorCode.notFound);
    });

    test('файл копируется в папку приложения, а удаление работы удаляет копию (сид-ассет не трогается)', () async {
      final work = (await add()).valueOrNull!;
      expect(work.imageRef, startsWith('/app/portfolio/'));
      expect(work.isAsset, isFalse);
      await repo.remove(work.id);
      expect(files.deleted, [work.imageRef]);

      final seed = (await repo.myWorks()).firstWhere((w) => w.isAsset);
      await repo.remove(seed.id);
      expect(files.deleted, hasLength(1));
    });

    test('порядок: сначала закреплённые, потом свежие', () async {
      final a = (await add()).valueOrNull!;
      clock.advance(const Duration(minutes: 1));
      final b = (await add()).valueOrNull!;
      final list = await repo.myWorks();
      expect(list.first.id, b.id); // свежая работа выше сидов
      await repo.update(a.id, pinned: true);
      expect((await repo.myWorks()).first.id, a.id);
      expect((await repo.myWorks()).first.pinned, isTrue);
    });

    test('чужие работы изменить и удалить нельзя', () async {
      expect(codeOf(await repo.update('w-m-001-1', caption: 'Моя')), PortfolioErrorCode.notFound);
      expect(codeOf(await repo.remove('w-m-001-1')), PortfolioErrorCode.notFound);
      expect(await repo.works('m-001'), hasLength(3));
      expect(codeOf(await repo.update('нет', caption: 'x')), PortfolioErrorCode.notFound);
    });

    test('повтор с тем же ключом идемпотентности не создаёт дубль, повтор после обрыва связи проходит', () async {
      final before = (await repo.myWorks()).length;
      await add(k: 'same');
      await add(k: 'same');
      expect(await repo.myWorks(), hasLength(before + 1));

      final net = MockNetwork();
      final flaky = MockPortfolioRepository(network: net, state: state);
      net.failNext();
      await expectLater(
        () => flaky.add(localPath: 'photo.jpg', serviceId: 'm-002-s1', consentAccepted: true, idempotencyKey: 'retry'),
        throwsA(anything),
      );
      expect(await flaky.myWorks(), hasLength(before + 1));
      await flaky.add(localPath: 'photo.jpg', serviceId: 'm-002-s1', consentAccepted: true, idempotencyKey: 'retry');
      expect(await flaky.myWorks(), hasLength(before + 2));
    });
  });

  group('Услугу убрали у мастера', () {
    test('работа остаётся, но без услуги (serviceId = null); название сохраняется', () async {
      final work = (await add()).valueOrNull!;
      state.portfolio = PortfolioStore.seed(
        masters: MastersRepository().getMasters(),
        files: files,
        serviceIdsOf: (masterId) => {'m-002-s2'}, // услугу «брови» мастер больше не оказывает
      );
      repo = MockPortfolioRepository(state: state);
      final list = await repo.works('m-002');
      final seed = list.firstWhere((w) => w.imageRef.contains('brows'));
      expect(seed.serviceId, isNull);
      expect(seed.serviceName, 'Архитектура бровей + окрашивание');
      expect(work.serviceId, 'm-002-s1');
    });

    test('мастер может привязать такую работу к другой услуге', () async {
      state.portfolio = PortfolioStore.seed(
        masters: MastersRepository().getMasters(),
        files: files,
        serviceIdsOf: (masterId) => {'m-002-s2'},
      );
      repo = MockPortfolioRepository(state: state);
      final orphan = (await repo.myWorks()).firstWhere((w) => w.serviceId == null);
      final fixed = await repo.update(orphan.id, serviceId: 'm-002-s2');
      expect(fixed.valueOrNull!.serviceId, 'm-002-s2');
    });
  });

  group('Превью на странице салона', () {
    test('закреплённые работы; если ничего не закреплено — три самых свежих', () async {
      for (var i = 0; i < 4; i++) {
        await add();
        clock.advance(const Duration(minutes: 1));
      }
      var preview = await repo.preview('m-002');
      expect(preview, hasLength(3));
      expect(preview.map((w) => w.id), (await repo.myWorks()).take(3).map((w) => w.id));

      final target = (await repo.myWorks()).last;
      await repo.update(target.id, pinned: true);
      preview = await repo.preview('m-002');
      expect(preview.map((w) => w.id), [target.id]);
    });
  });

  test('«я» берётся из сессии мастера', () async {
    final auth = MockAuthRepository();
    await auth.login(login: 'master', password: '12345678');
    final byAuth = MockPortfolioRepository(state: state, auth: auth);
    final work = (await byAuth.add(localPath: 'photo.jpg', serviceId: 'm-002-s1', consentAccepted: true, idempotencyKey: 's')).valueOrNull!;
    expect(work.masterId, 'm-002');
  });

  test('выход из аккаунта удаляет загруженные файлы', () async {
    await state.portfolio.clearFiles();
    expect(files.cleared, isTrue);
  });
}
