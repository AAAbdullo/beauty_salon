import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'repositories/auth_repository.dart';

/// Токен сессии в защищённом хранилище устройства (Keychain / Keystore).
/// Сбой хранилища не должен ронять приложение: чтение даёт «нет сессии», запись молча пропускается.
/// Очистка при сбое повторяется, а если не удалась — запоминается и выполняется до следующего чтения токена,
/// чтобы токен прошлого пользователя не восстановил его сессию.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'access_token';
  static const _launchedKey = 'app_launched_before';
  static const _clearPendingKey = 'token_clear_pending';
  final FlutterSecureStorage _storage;

  /// Keychain на iOS переживает удаление приложения: после переустановки токен остался бы и вошёл без пароля.
  /// SharedPreferences при переустановке очищается, поэтому отсутствие флага значит «первый запуск после установки».
  Future<void> clearIfFreshInstall() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_launchedKey) ?? false) return;
      await clear();
      await prefs.setBool(_launchedKey, true);
    } catch (_) {}
  }

  @override
  Future<String?> read() async {
    // Прошлая очистка не удалась — завершаем её, а токен не отдаём
    if (await _isClearPending()) {
      try {
        await _storage.delete(key: _key);
        await _setClearPending(false);
      } catch (_) {
        return null;
      }
    }
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
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _storage.delete(key: _key);
        await _setClearPending(false);
        return;
      } catch (_) {}
    }
    await _setClearPending(true);
  }

  Future<bool> _isClearPending() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_clearPendingKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setClearPending(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        await prefs.setBool(_clearPendingKey, true);
      } else {
        await prefs.remove(_clearPendingKey);
      }
    } catch (_) {}
  }
}
