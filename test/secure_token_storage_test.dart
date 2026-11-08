import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beauty_salons/core/data/secure_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('токен сохраняется, читается и очищается', () async {
    final data = <String, String>{};
    messenger.setMockMethodCallHandler(channel, (call) async {
      final key = call.arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          data[key!] = call.arguments['value'] as String;
          return null;
        case 'read':
          return data[key];
        case 'delete':
          data.remove(key);
          return null;
      }
      return null;
    });
    final storage = SecureTokenStorage();
    expect(await storage.read(), isNull);
    await storage.write('abc');
    expect(await storage.read(), 'abc');
    await storage.clear();
    expect(await storage.read(), isNull);
  });

  test('сбой хранилища не бросает исключение', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'fail'));
    final storage = SecureTokenStorage();
    expect(await storage.read(), isNull);
    await storage.write('x');
    await storage.clear();
  });

  /// Хранилище в памяти; первые [failDeletes] удалений завершаются ошибкой (сбой Keychain)
  Map<String, String> installStorage({int failDeletes = 0}) {
    final data = <String, String>{};
    var failures = failDeletes;
    messenger.setMockMethodCallHandler(channel, (call) async {
      final key = call.arguments['key'] as String?;
      switch (call.method) {
        case 'write':
          data[key!] = call.arguments['value'] as String;
          return null;
        case 'read':
          return data[key];
        case 'delete':
          if (failures > 0) {
            failures--;
            throw PlatformException(code: 'keychain');
          }
          data.remove(key);
          return null;
      }
      return null;
    });
    return data;
  }

  test('очистка повторяется: одиночный сбой Keychain не оставляет токен', () async {
    SharedPreferences.setMockInitialValues({});
    final data = installStorage(failDeletes: 1);
    final storage = SecureTokenStorage();
    await storage.write('abc');

    await storage.clear();
    expect(data, isEmpty);
    expect(await storage.read(), isNull);
  });

  test('очистка не удалась совсем: токен не отдаётся и стирается при следующем чтении', () async {
    SharedPreferences.setMockInitialValues({});
    final data = installStorage(failDeletes: 2); // обе попытки очистки при выходе неудачны
    final storage = SecureTokenStorage();
    await storage.write('abc');

    await storage.clear();
    expect(data['access_token'], 'abc'); // Keychain не дал удалить

    // Следующий запуск: Keychain снова работает — токен стирается до чтения и не восстанавливает сессию
    expect(await storage.read(), isNull);
    expect(data, isEmpty);
  });

  test('первый запуск после установки стирает токен прошлой установки, повторные запуски — нет', () async {
    SharedPreferences.setMockInitialValues({});
    final data = installStorage();
    data['access_token'] = 'left-in-keychain'; // остался в Keychain после переустановки
    final storage = SecureTokenStorage();

    await storage.clearIfFreshInstall();
    expect(data, isEmpty);

    await storage.write('new-session');
    await storage.clearIfFreshInstall(); // уже не первый запуск
    expect(data['access_token'], 'new-session');
  });
}
