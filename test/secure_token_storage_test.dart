import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beauty_salons/core/data/repositories/auth_repository.dart';
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
    expect(SecureTokenStorage.decode(data['access_token'])?.access, 'abc'); // Keychain не дал удалить

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
    expect(SecureTokenStorage.decode(data['access_token'])?.access, 'new-session');
  });

  test('пара токенов access+refresh сохраняется и читается', () async {
    final data = installStorage();
    final storage = SecureTokenStorage();
    await storage.writeTokens(const AuthTokens(access: 'a1', refresh: 'r1'));
    expect(await storage.readTokens(), const AuthTokens(access: 'a1', refresh: 'r1'));
    expect(await storage.read(), 'a1');
    expect(data['access_token'], startsWith('{'));

    await storage.write('only-access'); // без refresh
    expect(await storage.readTokens(), const AuthTokens(access: 'only-access'));
  });

  test('токен, записанный старой версией простой строкой, читается без миграции', () async {
    final data = installStorage();
    data['access_token'] = 'legacy-plain-token';
    final storage = SecureTokenStorage();
    expect(await storage.readTokens(), const AuthTokens(access: 'legacy-plain-token'));
  });

  test('повреждённый JSON в хранилище — «нет сессии»', () async {
    final data = installStorage();
    data['access_token'] = '{broken';
    expect(await SecureTokenStorage().readTokens(), isNull);
    data['access_token'] = '{"refresh":"r"}'; // нет access
    expect(await SecureTokenStorage().readTokens(), isNull);
  });
}
