/// Причина отказа операции с записью или абонементом.
/// Код нужен тестам и UI (например, предложить «Пополнить кредиты»), текст — пользователю.
enum BookingErrorCode {
  notFound,
  notActive,
  tooLate,
  slotUnavailable,
  inPast,
  overlapsOwnBooking,
  creditsFrozen,
  notEnoughCredits,
  creditsLimit,
  notCompleted,
  reviewClosed,
  alreadyReviewed,
  freezeNotAllowed,
  holdExpired,
}

class BookingError {
  final BookingErrorCode code;
  final String message;

  const BookingError(this.code, this.message);

  @override
  bool operator ==(Object other) => other is BookingError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'BookingError($code: $message)';
}
