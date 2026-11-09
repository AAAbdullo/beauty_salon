import 'dart:async';
import 'dart:convert';
import '../../services/app_state_service.dart';
import '../../utils/clock.dart';
import '../../utils/result.dart';
import '../../utils/uuid.dart';
import '../repositories/auth_repository.dart';
import 'mock_network.dart';

/// Мок авторизации. Токен — «JWT без подписи»: роль и id пользователя лежат внутри токена,
/// приложение читает их оттуда, а не из формы входа. Настоящий токен подпишет сервер.
class MockAuthRepository implements AuthRepository, DemoOtpHint {
  MockAuthRepository({TokenStorage? storage, MockNetwork? network})
    : _storage = storage ?? InMemoryTokenStorage(),
      _network = network ?? MockNetwork();

  final TokenStorage _storage;
  final MockNetwork _network;
  AuthSession? _session;
  final _expired = StreamController<void>.broadcast();

  /// Демо-аккаунты: логин → (пароль, роль, id пользователя)
  static const _accounts = <String, (String, UserRole, String)>{
    'client': ('12345678', UserRole.client, 'c-001'),
    'master': ('12345678', UserRole.master, 'm-002'),
  };

  static const tokenLifetime = Duration(hours: 12);

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<void> get sessionExpired => _expired.stream;

  /// Имитация ответа сервера «сессия истекла» (в тестах и демо): токен стирается, подписчики уведомляются
  Future<void> expireSession() async {
    await _storage.clear();
    _session = null;
    _expired.add(null);
  }

  static String _b64(Map<String, Object?> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  static Map<String, Object?>? _decode(String part) {
    try {
      final padded = part.padRight(part.length + (4 - part.length % 4) % 4, '=');
      return jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, Object?>;
    } catch (_) {
      return null;
    }
  }

  /// Выпустить токен вида `header.payload.signature`
  static String issueToken({required String userId, required UserRole role, required DateTime expiresAt}) {
    final header = _b64({'alg': 'none', 'typ': 'JWT'});
    final payload = _b64({'sub': userId, 'role': role.name, 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000});
    return '$header.$payload.mock-unsigned';
  }

  /// Прочитать сессию из токена; `null`, если токен испорчен или истёк
  static AuthSession? sessionFromToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = _decode(parts[1]);
    if (payload == null) return null;
    final role = UserRole.values.where((r) => r.name == payload['role']).firstOrNull;
    final sub = payload['sub'];
    final exp = payload['exp'];
    if (role == null || sub is! String || exp is! int) return null;
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if (!AppClock.now().isBefore(expiresAt)) return null;
    return AuthSession(userId: sub, role: role, accessToken: token, expiresAt: expiresAt);
  }

  Future<AuthSession> _startSession(String userId, UserRole role) async {
    final token = issueToken(userId: userId, role: role, expiresAt: AppClock.now().add(tokenLifetime));
    await _storage.write(token);
    // Роль берём из токена — так же поступит приложение при восстановлении сессии
    return _session = sessionFromToken(token)!;
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final token = await _storage.read();
    if (token == null) return null;
    final session = sessionFromToken(token);
    if (session == null) {
      await _storage.clear();
      return null;
    }
    return _session = session;
  }

  @override
  Future<Result<AuthSession, AuthError>> login({required String login, required String password}) async {
    final account = await _network(() => _accounts[login.trim()]);
    if (account == null || account.$1 != password) {
      return const Result.failure(AuthError('Неверный логин или пароль.'));
    }
    return Result.success(await _startSession(account.$3, account.$2));
  }

  // ── Регистрация по SMS ────────────────────────────────────────────────────

  /// В моке «SMS» всегда содержит этот код
  @override
  String get demoOtpCode => '1234';

  static const resendInterval = Duration(seconds: 45);
  static const otpLifetime = Duration(minutes: 5);
  static const maxOtpAttempts = 5;

  final Map<String, _SentOtp> _otps = {};
  final Map<String, String> _verifiedTokens = {};

  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  @override
  Future<Result<OtpChallenge, AuthError>> requestOtp({required String phone}) => _network(() {
    final digits = _digits(phone);
    if (digits.length != 12 || !digits.startsWith('998')) {
      return const Result.failure(AuthError('Введите корректный номер телефона.'));
    }
    final now = AppClock.now();
    final previous = _otps[digits];
    if (previous != null) {
      final wait = previous.sentAt.add(resendInterval).difference(now);
      if (wait > Duration.zero) {
        return Result.failure(AuthError('Повторно отправить код можно через ${wait.inSeconds + 1} с.'));
      }
    }
    _otps[digits] = _SentOtp(sentAt: now, expiresAt: now.add(otpLifetime));
    return const Result.success(OtpChallenge(resendAfter: resendInterval));
  });

  @override
  Future<Result<PhoneVerification, AuthError>> verifyOtp({required String phone, required String code}) =>
      _network(() {
        final digits = _digits(phone);
        final otp = _otps[digits];
        if (otp == null) return const Result.failure(AuthError('Сначала запросите код.'));
        if (!AppClock.now().isBefore(otp.expiresAt)) {
          _otps.remove(digits);
          return const Result.failure(AuthError('Код устарел. Запросите новый.'));
        }
        if (otp.attempts >= maxOtpAttempts) {
          return const Result.failure(AuthError('Слишком много попыток. Запросите новый код.'));
        }
        if (code.trim() != demoOtpCode) {
          otp.attempts++;
          final left = maxOtpAttempts - otp.attempts;
          return Result.failure(
            AuthError(left > 0 ? 'Неверный код. Осталось попыток: $left.' : 'Слишком много попыток. Запросите новый код.'),
          );
        }
        _otps.remove(digits);
        final token = 'reg_${Uuid.v4()}';
        _verifiedTokens[token] = digits;
        return Result.success(PhoneVerification(token: token, phone: phone));
      });

  @override
  Future<Result<AuthSession, AuthError>> completeRegistration({
    required PhoneVerification verification,
    required RegistrationProfile profile,
  }) async {
    final failure = await _network<AuthError?>(() {
      final verified = _verifiedTokens[verification.token];
      if (verified == null || verified != _digits(profile.phone)) {
        return const AuthError('Номер не подтверждён. Пройдите проверку по SMS заново.');
      }
      if (profile.firstName.trim().isEmpty) return const AuthError('Укажите имя.');
      _verifiedTokens.remove(verification.token); // токен одноразовый
      // «Сервер» заводит нового клиента: без кредитов, записей и избранного
      AppStateService().startNewClient(
        name: profile.fullName,
        phone: profile.phone,
        birthDate: profile.birthDate,
        gender: profile.gender,
      );
      return null;
    });
    if (failure != null) return Result.failure(failure);
    return Result.success(await _startSession(AppStateService().clientId, UserRole.client));
  }

  @override
  Future<void> logout() async {
    await _storage.clear();
    _session = null;
  }
}

class _SentOtp {
  _SentOtp({required this.sentAt, required this.expiresAt});

  final DateTime sentAt;
  final DateTime expiresAt;
  int attempts = 0;
}
