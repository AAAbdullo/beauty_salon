import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'helpers/fake_portfolio_files.dart';
import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/masters_repository.dart';
import 'package:beauty_salons/core/services/portfolio_store.dart';
import 'package:beauty_salons/core/utils/clock.dart';
import 'package:beauty_salons/features/master_cabinet/portfolio/master_portfolio_screen.dart';

/// Кабинет мастера → «Мои работы»: добавление (согласие, услуга, подпись, ошибки сервера, обрыв связи без дубля),
/// закрепление, правка, удаление, пометка «Услуга больше не оказывается», лимит.
/// Мастер демо-кабинета — Sabina (m-002): две работы из сидов, услуги m-002-s1 и m-002-s2.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  late AppStateService state;
  late FakeFiles files;

  setUp(() {
    AppClock.current = FixedClock(DateTime(2026, 11, 11, 10));
    state = AppStateService()..resetSession();
    files = FakeFiles();
    state.portfolio = PortfolioStore.seed(masters: MastersRepository().getMasters(), files: files);
  });

  tearDown(() {
    AppClock.reset();
    state.resetSession();
  });

  Future<AppDependencies> pumpScreen(WidgetTester tester, {MockNetwork? network}) async {
    useBigPhone(tester);
    final deps = AppDependencies.mock(network: network ?? MockNetwork());
    await tester.pumpWidget(
      AppScope(
        dependencies: deps,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Scaffold(
            body: MasterPortfolioScreen(onBack: () {}, pickPhoto: (ImageSource source) async => 'photo.jpg'),
          ),
        ),
      ),
    );
    await settle(tester);
    return deps;
  }

  Future<void> startAdd(WidgetTester tester) async {
    await tester.tap(find.text('+ Добавить работу'));
    await settle(tester);
    await tester.tap(find.text('Выбрать из галереи'));
    await settle(tester, frames: 12);
  }

  Finder publishButton() => find.widgetWithText(ElevatedButton, 'Опубликовать');

  testWidgets('счётчик «2 из 30», первой идёт плитка «+ Добавить работу»', (tester) async {
    await pumpScreen(tester);
    expect(find.text('2 из 30'), findsOneWidget);
    expect(find.text('+ Добавить работу'), findsOneWidget);
    expect(find.text('Добавьте 3–5 лучших работ: клиенты чаще записываются к мастерам с фото'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('пустое портфолио: подсказка «Добавьте 3–5 лучших работ…»', (tester) async {
    state.portfolio = PortfolioStore.seed(masters: const [], files: files);
    await pumpScreen(tester);
    expect(find.text('0 из 30'), findsOneWidget);
    expect(find.text('Добавьте 3–5 лучших работ: клиенты чаще записываются к мастерам с фото'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('добавление: согласие спрашивается один раз, «Опубликовать» ждёт услугу и галочку', (tester) async {
    final deps = await pumpScreen(tester);
    await startAdd(tester);

    expect(find.text('Новая работа'), findsWidgets);
    expect(tester.widget<ElevatedButton>(publishButton()).onPressed, isNull); // нет услуги и согласия
    await tester.tap(find.text('Ламинирование ресниц с ботоксом'));
    await settle(tester);
    expect(tester.widget<ElevatedButton>(publishButton()).onPressed, isNull); // нет галочки
    await tester.tap(find.byType(Checkbox));
    await settle(tester);
    expect(tester.widget<ElevatedButton>(publishButton()).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField), 'Ламинирование + окрашивание');
    await tester.tap(publishButton());
    await settle(tester, frames: 14);

    expect(find.text('3 из 30'), findsOneWidget);
    final mine = await deps.portfolio.myWorks();
    expect(mine.first.caption, 'Ламинирование + окрашивание');
    expect(mine.first.serviceId, 'm-002-s2');

    // второй раз галочки уже нет
    await startAdd(tester);
    expect(find.byType(Checkbox), findsNothing);
    await tester.tap(find.text('Архитектура бровей + окрашивание').last);
    await settle(tester);
    expect(tester.widget<ElevatedButton>(publishButton()).onPressed, isNotNull);
    await disposeTree(tester);
  });

  testWidgets('сервер отклонил подпись с контактами: причина на экране, работа не создана', (tester) async {
    final deps = await pumpScreen(tester);
    await startAdd(tester);
    await tester.tap(find.text('Ламинирование ресниц с ботоксом'));
    await tester.tap(find.byType(Checkbox));
    await tester.enterText(find.byType(TextField), 'пишите @alena_nails');
    await settle(tester);
    await tester.tap(publishButton());
    await settle(tester, frames: 12);

    expect(find.text('Уберите из подписи контакты и ссылки.'), findsOneWidget);
    expect(await deps.portfolio.myWorks(), hasLength(2));
    await disposeTree(tester);
  });

  testWidgets('обрыв связи при публикации: повтор не создаёт дубль', (tester) async {
    final net = MockNetwork();
    final deps = await pumpScreen(tester, network: net);
    await startAdd(tester);
    await tester.tap(find.text('Ламинирование ресниц с ботоксом'));
    await tester.tap(find.byType(Checkbox));
    await settle(tester);

    net.failNext();
    await tester.tap(publishButton());
    await settle(tester, frames: 12);
    expect(find.textContaining('Нет соединения'), findsOneWidget);
    expect(await deps.portfolio.myWorks(), hasLength(2));

    await tester.tap(publishButton());
    await settle(tester, frames: 14);
    expect(await deps.portfolio.myWorks(), hasLength(3));
    await disposeTree(tester);
  });

  testWidgets('закрепление: «Закрепить» → значок, четвёртую закрепить нельзя', (tester) async {
    final deps = await pumpScreen(tester);
    for (var i = 0; i < 2; i++) {
      await deps.portfolio.add(
        localPath: 'photo.jpg',
        serviceId: 'm-002-s1',
        consentAccepted: true,
        idempotencyKey: 'seed-$i',
      );
    }
    final ids = (await deps.portfolio.myWorks()).map((w) => w.id).toList();
    for (final id in ids.take(3)) {
      await deps.portfolio.update(id, pinned: true);
    }
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester);
    expect(find.byIcon(Icons.push_pin), findsNWidgets(3));

    // четвёртая работа (последняя в списке) — закрепить нельзя
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await settle(tester);
    await tester.tap(find.text('Закрепить'));
    await settle(tester, frames: 12);
    expect(find.text('Можно закрепить не больше 3 работ.'), findsOneWidget);
    expect(find.byIcon(Icons.push_pin), findsNWidgets(3));

    // открепить закреплённую (первая в списке)
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await settle(tester);
    await tester.tap(find.text('Открепить'));
    await settle(tester, frames: 12);
    expect(find.byIcon(Icons.push_pin), findsNWidgets(2));
    await disposeTree(tester);
  });

  testWidgets('долгое нажатие открывает то же меню; «Изменить» меняет услугу и подпись', (tester) async {
    final deps = await pumpScreen(tester);
    final first = (await deps.portfolio.myWorks()).first;
    await tester.longPress(find.byType(Image).first);
    await settle(tester);
    expect(find.text('Изменить'), findsOneWidget);
    expect(find.text('Закрепить'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);

    await tester.tap(find.text('Изменить'));
    await settle(tester);
    expect(find.text('Изменить работу'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing); // согласие нужно только при добавлении
    await tester.tap(find.text('Ламинирование ресниц с ботоксом'));
    await tester.enterText(find.byType(TextField), 'Новая подпись');
    await settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Сохранить'));
    await settle(tester, frames: 12);

    final changed = (await deps.portfolio.myWorks()).firstWhere((w) => w.id == first.id);
    expect(changed.serviceId, 'm-002-s2');
    expect(changed.caption, 'Новая подпись');
    await disposeTree(tester);
  });

  testWidgets('удаление с подтверждением: «Отмена» оставляет работу, «Удалить» убирает', (tester) async {
    final deps = await pumpScreen(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await settle(tester);
    await tester.tap(find.text('Удалить'));
    await settle(tester);
    expect(find.text('Удалить работу?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await settle(tester);
    expect(await deps.portfolio.myWorks(), hasLength(2));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await settle(tester);
    await tester.tap(find.text('Удалить'));
    await settle(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
    await settle(tester, frames: 12);
    expect(await deps.portfolio.myWorks(), hasLength(1));
    expect(find.text('1 из 30'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('услугу убрали: на работе пометка «Услуга больше не оказывается»', (tester) async {
    state.portfolio = PortfolioStore.seed(
      masters: MastersRepository().getMasters(),
      files: files,
      serviceIdsOf: (_) => const {},
    );
    await pumpScreen(tester);
    expect(find.text('Услуга больше не оказывается'), findsNWidgets(2));
    await disposeTree(tester);
  });

  testWidgets('лимит 30 работ: вместо выбора фото — сообщение', (tester) async {
    final deps = await pumpScreen(tester);
    for (var i = 2; i < PortfolioRules.maxWorks; i++) {
      await deps.portfolio.add(
        localPath: 'photo.jpg',
        serviceId: 'm-002-s1',
        consentAccepted: true,
        idempotencyKey: 'fill-$i',
      );
    }
    await tester.pumpWidget(const SizedBox());
    await pumpScreen(tester);
    expect(find.text('30 из 30'), findsOneWidget);
    await tester.tap(find.text('+ Добавить работу'));
    await settle(tester);
    expect(find.text('В портфолио уже 30 работ. Удалите старые, чтобы добавить новую.'), findsOneWidget);
    expect(find.text('Выбрать из галереи'), findsNothing);
    await disposeTree(tester);
  });
}
