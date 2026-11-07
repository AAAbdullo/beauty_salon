import 'dart:convert';
import '../../services/app_state_service.dart';
import '../../utils/clock.dart';
import '../../utils/result.dart';
import '../repositories/auth_repository.dart';
import 'mock_network.dart';

/// Мок авторизации. Токен — «JWT без подписи»: роль и id пользователя лежат внутри токена,
/// приложение читает их оттуда, а не из формы входа. Настоящий токен подпишет сервер.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({TokenStorage? storage, MockNetwork? network})
    : _storage = storage ?? InMemoryTokenStorage(),
      _network = network ?? MockNetwork();

  final TokenStorage _storage;
  final MockNetwork _network;
  AuthSession? _session;

  /// Демо-аккаунты: логин → (пароль, роль, id пользователя)
  static const _accounts = <String, (String, UserRole, String)>{
    'client': ('12345678', UserRole.client, 'c-001'),
    'master': ('12345678', UserRole.master, 'm-002'),
  };

  static const tokenLifetime = Duration(hours: 12);

  @override
  AuthSession? get currentSession => _session;

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

  @override
  Future<AuthSession> completeRegistration({required String phone}) async {
    await _network(() {});
    return _startSession(AppStateService().clientId, UserRole.client);
  }

  @override
  Future<void> logout() async {
    await _storage.clear();
    _session = null;
  }
}
