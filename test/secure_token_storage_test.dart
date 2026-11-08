import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
