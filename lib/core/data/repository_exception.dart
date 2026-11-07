/// Сбой при обращении к данным (нет сети, ошибка сервера, таймаут).
/// Бизнес-отказы («слот занят», «не хватает кредитов») сюда НЕ относятся — они приходят как `Result.failure`.
class RepositoryException implements Exception {
  final String message;
  final Object? cause;

  const RepositoryException(this.message, [this.cause]);

  @override
  String toString() => 'RepositoryException: $message';
}
