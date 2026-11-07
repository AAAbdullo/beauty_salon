import '../../utils/result.dart';

enum UserRole { client, master }

/// Сессия пользователя. Роль и id берутся из токена, а не из формы входа.
class AuthSession {
  final String userId;
  final UserRole role;
  final String accessToken;
  final DateTime expiresAt;

  const AuthSession({required this.userId, required this.role, required this.accessToken, required this.expiresAt});

  bool get isMaster => role == UserRole.master;
}

class AuthError {
  final String message;

  const AuthError(this.message);

  @override
  String toString() => 'AuthError($message)';
}

/// Хранилище токена. На устройстве — защищённое (Keychain / Keystore через flutter_secure_storage),
/// в моках — в памяти.
abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class InMemoryTokenStorage implements TokenStorage {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;

  @override
  Future<void> clear() async => _token = null;
}

/// Вход и сессия.
/// [BACKEND NOTE]: POST /api/v1/auth/login, POST /api/v1/auth/register/confirm, POST /api/v1/auth/logout
abstract interface class AuthRepository {
  /// Сессия, если пользователь уже вошёл (синхронно, из памяти)
  AuthSession? get currentSession;

  /// Восстановить сессию из сохранённого токена (при запуске приложения)
  Future<AuthSession?> restoreSession();

  Future<Result<AuthSession, AuthError>> login({required String login, required String password});

  /// Завершение регистрации клиента (после подтверждения телефона по SMS)
  Future<AuthSession> completeRegistration({required String phone});

  Future<void> logout();
}
