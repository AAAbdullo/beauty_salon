/// Результат операции: либо значение [Success], либо ошибка [Failure].
///
/// Нужен, чтобы сервисы возвращали причину отказа («не хватает кредитов», «запись уже отменена»),
/// а не молчаливый `false`. Благодаря `sealed` компилятор требует разобрать оба случая:
///
/// ```dart
/// switch (result) {
///   case Success(:final value): ...
///   case Failure(:final error): ...
/// }
/// ```
sealed class Result<T, E> {
  const Result();

  const factory Result.success(T value) = Success<T, E>;
  const factory Result.failure(E error) = Failure<T, E>;

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  /// Значение или `null`, если операция не удалась
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  /// Ошибка или `null`, если операция удалась
  E? get errorOrNull => switch (this) {
    Success() => null,
    Failure(:final error) => error,
  };

  /// Свернуть результат в одно значение
  R fold<R>({required R Function(T value) onSuccess, required R Function(E error) onFailure}) => switch (this) {
    Success(:final value) => onSuccess(value),
    Failure(:final error) => onFailure(error),
  };

  /// Преобразовать значение успешного результата, ошибку оставить как есть
  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
    Success(:final value) => Result<R, E>.success(transform(value)),
    Failure(:final error) => Result<R, E>.failure(error),
  };
}

final class Success<T, E> extends Result<T, E> {
  final T value;

  const Success(this.value);

  @override
  bool operator ==(Object other) => other is Success<T, E> && other.value == value;

  @override
  int get hashCode => Object.hash(Success, value);

  @override
  String toString() => 'Success($value)';
}

final class Failure<T, E> extends Result<T, E> {
  final E error;

  const Failure(this.error);

  @override
  bool operator ==(Object other) => other is Failure<T, E> && other.error == error;

  @override
  int get hashCode => Object.hash(Failure, error);

  @override
  String toString() => 'Failure($error)';
}
