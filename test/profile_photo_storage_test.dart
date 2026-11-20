import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beauty_salons/core/services/profile_photo_storage.dart';

/// Хранилище фото профиля: операции идут по очереди и не стирают актуальное фото.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory sandbox;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sandbox = await Directory.systemTemp.createTemp('photo_storage_test');
    messenger.setMockMethodCallHandler(channel, (call) async => sandbox.path);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await sandbox.delete(recursive: true);
  });

  Future<String> source(String name) async {
    final file = File('${sandbox.path}/$name');
    await file.writeAsString(name);
    return file.path;
  }

  test('два выбора подряд: остаётся второе фото, первое удалено, указатель не битый', () async {
    final a = await source('a.jpg');
    final b = await source('b.jpg');

    // Не дожидаясь первого: именно так бывает при быстрых нажатиях
    final first = ProfilePhotoStorage.save(a);
    final second = ProfilePhotoStorage.save(b);
    final firstPath = await first;
    final secondPath = await second;

    expect(firstPath, isNot(secondPath));
    expect(await ProfilePhotoStorage.restore(), secondPath);
    expect(File(secondPath).existsSync(), isTrue);
    expect(File(firstPath).existsSync(), isFalse);
  });

  test('выход: clearAll ждёт очистку, а новое фото после быстрого входа не стирается', () async {
    final a = await source('a.jpg');
    final saved = await ProfilePhotoStorage.save(a);
    expect(await ProfilePhotoStorage.restore(), saved);

    // Выход и сразу новое фото: очистка не должна задеть новый файл
    final clearing = ProfilePhotoStorage.clearAll();
    final b = await source('b.jpg');
    final newer = ProfilePhotoStorage.save(b);
    await clearing;
    final newerPath = await newer;

    expect(File(saved).existsSync(), isFalse);
    expect(await ProfilePhotoStorage.restore(), newerPath);
    expect(File(newerPath).existsSync(), isTrue);
  });

  test('фото клиента и мастера хранятся и очищаются независимо', () async {
    final a = await source('a.jpg');
    final b = await source('b.jpg');
    final client = await ProfilePhotoStorage.save(a);
    final master = await ProfilePhotoStorage.save(b, owner: PhotoOwner.master);

    await ProfilePhotoStorage.clear(owner: PhotoOwner.client);
    expect(await ProfilePhotoStorage.restore(), isNull);
    expect(await ProfilePhotoStorage.restore(owner: PhotoOwner.master), master);
    expect(File(client).existsSync(), isFalse);
  });
}
