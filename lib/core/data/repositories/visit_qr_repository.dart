import '../../services/app_state_service.dart';

/// Токен QR визита, который клиент показывает мастеру
class VisitQrToken {
  final String value;
  final DateTime expiresAt;

  const VisitQrToken({required this.value, required this.expiresAt});
}

/// QR визита.
///
/// Контракт с сервером: токен выдаёт и подписывает сервер (HMAC) и кладёт в него одноразовый nonce;
/// мастер отправляет на сервер сырую строку, а проверку (подпись, срок, салон, окно визита,
/// повторное использование) и подтверждение визита делает сервер. Клиент ничего не решает сам.
/// [BACKEND NOTE]: POST /api/v1/bookings/:id/qr, POST /api/v1/visits/confirm
abstract interface class VisitQrRepository {
  Future<VisitQrToken> issueToken(String bookingId);

  /// Проверить отсканированный код и подтвердить визит
  Future<VisitQrResult> verifyAndConfirm(String raw, {bool ignoreTimeWindow = false});
}
