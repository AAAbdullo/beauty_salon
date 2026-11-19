import '../../models/portfolio_work.dart';
import '../../utils/result.dart';

export '../../models/portfolio_work.dart';

/// Портфолио мастера: работы с фото, привязанные к услугам. Клиент видит их в профиле мастера и записывается
/// на услугу прямо с фото; мастер ведёт их в кабинете («Мои работы»).
///
/// Правила (лимиты, закрепление, подпись, согласие, размер файла) проверяет сервер.
///
/// [BACKEND NOTE]:
///   GET    /api/v1/masters/:id/portfolio
///   POST   /api/v1/masters/me/portfolio        — multipart: file, serviceId, caption (Idempotency-Key)
///   PATCH  /api/v1/masters/me/portfolio/:id    — serviceId, caption, pinned
///   DELETE /api/v1/masters/me/portfolio/:id
abstract interface class PortfolioRepository {
  /// Работы мастера для клиентов: сначала закреплённые, потом свежие
  Future<List<PortfolioWork>> works(String masterId);

  /// Превью для карточки мастера на странице салона: закреплённые работы или три свежих
  Future<List<PortfolioWork>> preview(String masterId);

  /// Работы текущего мастера (по сессии)
  Future<List<PortfolioWork>> myWorks();

  /// Одноразовое согласие «Фото сделаны мной…» уже дано в этой сессии мастера
  Future<bool> consentGiven();

  /// Добавить работу. Повтор с тем же [idempotencyKey] не создаёт дубль.
  /// [consentAccepted] — галочка согласия; после первой публикации она больше не нужна.
  Future<Result<PortfolioWork, PortfolioError>> add({
    required String localPath,
    required String serviceId,
    String caption = '',
    bool consentAccepted = false,
    required String idempotencyKey,
  });

  Future<Result<PortfolioWork, PortfolioError>> update(
    String workId, {
    String? serviceId,
    String? caption,
    bool? pinned,
  });

  Future<Result<void, PortfolioError>> remove(String workId);
}
