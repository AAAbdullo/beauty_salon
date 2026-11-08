import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'repositories/auth_repository.dart';

/// Токен сессии в защищённом хранилище устройства (Keychain / Keystore).
/// Сбой хранилища не должен ронять приложение: чтение даёт «нет сессии», запись и очистка молча пропускаются.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
