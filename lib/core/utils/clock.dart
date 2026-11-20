/// Источник «текущего времени» для бизнес-правил (отмена за 2 часа, срок жизни QR,
/// окно отзыва, заморозка абонемента).
///
/// Правила не должны читать `DateTime.now()` напрямую: так время можно подменить в тестах,
/// а позже — подправить на серверное (чтобы перевод часов на устройстве не обходил правила).
abstract interface class Clock {
  DateTime now();
}

/// Часы устройства — значение по умолчанию.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Управляемые часы для тестов: стоят на месте, пока их не сдвинули.
class FixedClock implements Clock {
  DateTime _now;

  FixedClock(this._now);

  @override
  DateTime now() => _now;

  void advance(Duration duration) => _now = _now.add(duration);

  void set(DateTime value) => _now = value;
}

/// Текущие часы приложения. Модели и сервисы берут время отсюда: `AppClock.now()`.
///
/// В тестах: `AppClock.current = FixedClock(...)`, а по окончании — `AppClock.reset()`.
class AppClock {
  AppClock._();

  /// Подменяемые часы (по умолчанию — часы устройства)
  static Clock current = const SystemClock();

  static void reset() => current = const SystemClock();

  static DateTime now() => current.now();
}
