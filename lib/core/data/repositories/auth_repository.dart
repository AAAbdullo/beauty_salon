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

/// Пара токенов сессии: короткоживущий access и (когда появится бэкенд) долгоживущий refresh.
/// Refresh обновляет Dio-перехватчик в слое данных; экраны видят только [AuthRepository.sessionExpired].
class AuthTokens {
  final String access;
  final String? refresh;

  const AuthTokens({required this.access, this.refresh});

  @override
  bool operator ==(Object other) => other is AuthTokens && other.access == access && other.refresh == refresh;

  @override
  int get hashCode => Object.hash(access, refresh);
}

/// Хранилище токенов. На устройстве — защищённое (Keychain / Keystore через flutter_secure_storage),
/// в моках — в памяти. Реализации наследуют класс и определяют [readTokens]/[writeTokens]/[clear].
abstract class TokenStorage {
  Future<AuthTokens?> readTokens();
  Future<void> writeTokens(AuthTokens tokens);
  Future<void> clear();

  /// Только access-токен (пока refresh не нужен)
  Future<String?> read() async => (await readTokens())?.access;

  /// Сохранить access-токен без refresh
  Future<void> write(String token) => writeTokens(AuthTokens(access: token));
}

class InMemoryTokenStorage extends TokenStorage {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> readTokens() async => _tokens;

  @override
  Future<void> writeTokens(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}

/// Вход и сессия.
/// [BACKEND NOTE]: POST /api/v1/auth/login, POST /api/v1/auth/register/confirm, POST /api/v1/auth/logout
abstract interface class AuthRepository {
  /// Сессия, если пользователь уже вошёл (синхронно, из памяти)
  AuthSession? get currentSession;

  /// Событие «сессия истекла посреди работы» (сервер ответил 401 и обновить токен не удалось):
  /// приложение возвращает пользователя на экран входа.
  /// [BACKEND NOTE]: Dio-перехватчик на 401 пробует POST /auth/refresh, а при отказе сообщает сюда.
  Stream<void> get sessionExpired;

  /// Восстановить сессию из сохранённого токена (при запуске приложения)
  Future<AuthSession?> restoreSession();

  Future<Result<AuthSession, AuthError>> login({required String login, required String password});

  /// Завершение регистрации клиента (после подтверждения телефона по SMS)
  Future<AuthSession> completeRegistration({required String phone});

  Future<void> logout();
}
