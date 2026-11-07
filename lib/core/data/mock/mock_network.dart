import 'dart:async';
import '../repository_exception.dart';

/// Имитация сети для мок-репозиториев: задержка ответа и сбои.
/// Нужна, чтобы экраны уже сейчас проходили состояния loading / error, как с настоящим бэкендом.
class MockNetwork {
  MockNetwork({this.latency = Duration.zero});

  /// Задержка каждого ответа (в приложении ~150 мс, в тестах — ноль)
  Duration latency;

  int _pendingFailures = 0;

  /// Следующие [count] запросов завершатся ошибкой сети
  void failNext([int count = 1]) => _pendingFailures += count;

  Future<T> call<T>(FutureOr<T> Function() action) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (_pendingFailures > 0) {
      _pendingFailures--;
      throw const RepositoryException('Нет соединения с сервером. Проверьте интернет и повторите.');
    }
    return action();
  }
}
