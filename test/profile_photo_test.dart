import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';
import 'helpers/test_fonts.dart';

import 'package:beauty_salons/core/data/app_dependencies.dart';
import 'package:beauty_salons/core/data/app_scope.dart';
import 'package:beauty_salons/core/data/mock/mock_network.dart';
import 'package:beauty_salons/core/services/app_state_service.dart';
import 'package:beauty_salons/core/services/booking_seed.dart';
import 'package:beauty_salons/core/widgets/avatars/avatar_image.dart';
import 'package:beauty_salons/features/profile_settings/profile_sheets.dart';

/// Фото профиля: выбор источника, показ файла и ресурса, сброс при выходе.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestFonts);

  late AppStateService state;

  setUp(() => state = AppStateService()..resetSession());
  tearDown(() => state.resetSession());

  test('avatarProvider: ресурс приложения или файл пользователя', () {
    expect(avatarProvider('assets/images/clients/client_wazow.jpg'), isA<AssetImage>());
    expect(avatarProvider('/data/user/0/app/profile_photo_1.jpg'), isA<FileImage>());
    expect(isCustomAvatar('assets/images/clients/client_wazow.jpg'), isFalse);
    expect(isCustomAvatar('/data/user/0/app/profile_photo_1.jpg'), isTrue);
  });

  test('смена и сброс фото оповещают слушателей; выход из аккаунта возвращает стандартный аватар', () {
    var notified = 0;
    void listener() => notified++;
    state.addListener(listener);
    addTearDown(() => state.removeListener(listener));

    state.updateClientAvatar('/tmp/me.jpg');
    expect(state.clientAvatar, '/tmp/me.jpg');
    expect(notified, 1);

    state.resetClientAvatar();
    expect(state.clientAvatar, seedClientAvatar);

    state.updateClientAvatar('/tmp/me.jpg');
    state.resetSession();
    expect(state.clientAvatar, seedClientAvatar);
  });

  test('фото мастера хранится отдельно от фото клиента и сбрасывается при выходе', () {
    state.updateMasterAvatar('/tmp/master.jpg');
    expect(state.masterAvatar, '/tmp/master.jpg');
    expect(state.clientAvatar, seedClientAvatar); // фото клиента не затронуто

    state.resetMasterAvatar();
    expect(state.masterAvatar, seedMasterAvatar);

    state.updateMasterAvatar('/tmp/master.jpg');
    state.resetSession();
    expect(state.masterAvatar, seedMasterAvatar);
  });

  testWidgets('форма профиля: фото можно сменить, «Удалить» есть только у своего фото', (tester) async {
    useBigPhone(tester);
    await tester.pumpWidget(
      AppScope(
        dependencies: AppDependencies.mock(network: MockNetwork()),
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(onPressed: () => ProfileSheets.editProfile(context), child: const Text('Открыть')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await settle(tester);

    expect(find.text('Изменить фото'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera), findsOneWidget); // значок на аватаре

    await tester.tap(find.text('Изменить фото'));
    await settle(tester);
    expect(find.text('Фото профиля'), findsOneWidget);
    expect(find.text('Выбрать из галереи'), findsOneWidget);
    expect(find.text('Сделать фото'), findsOneWidget);
    expect(find.text('Удалить фото'), findsNothing); // стандартный аватар удалять нечего

    // Файла нет, но пункт должен появиться, как только фото пользователя установлено
    await tester.tapAt(const Offset(10, 10)); // закрыть шторку
    await settle(tester);
    state.updateClientAvatar(File('/tmp/none.jpg').path);
    await tester.tap(find.text('Изменить фото'));
    await settle(tester);
    expect(find.text('Удалить фото'), findsOneWidget);
  });
}
