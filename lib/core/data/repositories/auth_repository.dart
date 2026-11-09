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

/// Ответ на запрос SMS-кода
class OtpChallenge {
  /// Через сколько можно запросить код повторно
  final Duration resendAfter;

  const OtpChallenge({required this.resendAfter});
}

/// Подтверждённый по SMS номер: одноразовый токен, который принимает завершение регистрации
class PhoneVerification {
  final String token;
  final String phone;

  const PhoneVerification({required this.token, required this.phone});
}

/// Анкета нового клиента
class RegistrationProfile {
  final String phone;
  final String firstName;
  final String lastName;
  final String birthDate;
  final String gender;

  const RegistrationProfile({
    required this.phone,
    required this.firstName,
    this.lastName = '',
    required this.birthDate,
    required this.gender,
  });

  String get fullName => lastName.isEmpty ? firstName : '$firstName $lastName';
}

/// Только для мока: показать тестировщику, какой код «пришёл по SMS». У настоящего сервера этого нет.
abstract interface class DemoOtpHint {
  String get demoOtpCode;
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

  /// Регистрация клиента в три шага: [requestOtp] (SMS на номер) → [verifyOtp] (проверка кода) →
  /// [completeRegistration] (анкета). Номер должен быть подтверждён: без [PhoneVerification] анкету не принимают.
  /// [BACKEND NOTE]: POST /auth/register/otp, POST /auth/register/otp/verify, POST /auth/register/confirm
  ///
  /// Отправить SMS-код на [phone] (формат «+998 90 123 45 67»). В ответе — через сколько можно запросить новый.
  Future<Result<OtpChallenge, AuthError>> requestOtp({required String phone});

  /// Проверить код. Неверный код ограниченное число раз, потом нужно запросить новый.
  Future<Result<PhoneVerification, AuthError>> verifyOtp({required String phone, required String code});

  /// Завершить регистрацию анкетой; возвращает сессию нового клиента.
  /// Профиль нового клиента пустой: без кредитов, записей и избранного.
  Future<Result<AuthSession, AuthError>> completeRegistration({
    required PhoneVerification verification,
    required RegistrationProfile profile,
  });

  Future<void> logout();
}
