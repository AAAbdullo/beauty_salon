import 'dart:collection';

/// Защита изменяющих запросов от повтора: один и тот же ключ выполняется один раз.
///
/// Пока запрос идёт, повторный вызов с тем же ключом получает тот же `Future` (двойной тап,
/// повтор после обрыва связи). После завершения результат запоминается: повтор вернёт его же,
/// а не выполнит операцию второй раз. Если запрос упал исключением (сеть), ключ освобождается —
/// повторная попытка выполнится заново.
///
/// На бэкенде эту роль играет заголовок `Idempotency-Key`.
class IdempotencyGuard {
  IdempotencyGuard({this.maxEntries = 256});

  final int maxEntries;
  final LinkedHashMap<String, Future<Object?>> _calls = LinkedHashMap();

  bool contains(String key) => _calls.containsKey(key);

  Future<T> run<T>(String key, Future<T> Function() action) {
    final existing = _calls[key];
    if (existing != null) return existing.then((value) => value as T);

    final future = action();
    _calls[key] = future;
    if (_calls.length > maxEntries) _calls.remove(_calls.keys.first);

    // Сетевая ошибка не должна «залипнуть»: ключ освобождается, чтобы можно было повторить
    future.then<void>(
      (_) {},
      onError: (Object _) {
        _calls.remove(key);
      },
    );
    return future;
  }

  void clear() => _calls.clear();
}
