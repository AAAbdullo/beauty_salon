import 'package:flutter/foundation.dart';

/// Правила отзывов о мастере (единственное место с числами)
class ReviewRules {
  ReviewRules._();

  static const maxCommentLength = 500;
  static const maxReplyLength = 500;

  /// Оценка 1–2 ★ без тегов требует комментарий не короче этого
  static const minReasonCommentLength = 10;

  /// Размер страницы списка отзывов
  static const pageSize = 20;

  /// Низкой считается оценка до этого значения включительно
  static const lowRatingMax = 2;

  /// Положительные теги показываются при оценке от этого значения
  static const positiveFrom = 4;
}

/// Теги отзыва: две группы, у каждой положительные и проблемные
class ReviewTags {
  ReviewTags._();

  static const masterPositive = ['Отличный результат', 'Аккуратная работа', 'Пунктуальность', 'Приятное общение'];
  static const masterProblem = ['Результат не устроил', 'Неаккуратная работа', 'Опоздание', 'Грубое общение'];
  static const salonPositive = ['Чистота', 'Уютная атмосфера', 'Без ожидания'];
  static const salonProblem = ['Недостаточная чистота', 'Шумно и неуютно', 'Долгое ожидание'];

  static List<String> master(int rating) => rating >= ReviewRules.positiveFrom ? masterPositive : masterProblem;
  static List<String> salon(int rating) => rating >= ReviewRules.positiveFrom ? salonPositive : salonProblem;
}

/// Проверка текста на контакты и ссылки (отзывы, ответы мастера, подписи работ). Проверку делает «сервер».
class ContactsInText {
  ContactsInText._();

  static final _phoneRun = RegExp(r'\+?[\d\s\-().]{7,}');
  static final _other = RegExp(r'https?://|www\.|@\w{2,}|\b[\w-]+\.(com|ru|uz|org|net|me|io|ly|info)\b', caseSensitive: false);

  static bool found(String text) {
    if (_other.hasMatch(text)) return true;
    for (final m in _phoneRun.allMatches(text)) {
      final digits = m.group(0)!.replaceAll(RegExp(r'\D'), '').length;
      if (digits >= 7) return true;
    }
    return false;
  }
}

/// Публичный ответ мастера на отзыв
@immutable
class ReviewReply {
  final String text;
  final DateTime createdAt;

  const ReviewReply({required this.text, required this.createdAt});

  @override
  bool operator ==(Object other) => other is ReviewReply && other.text == text && other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(text, createdAt);
}

/// Отзыв клиента о мастере после подтверждённого визита. Других отзывов не бывает.
@immutable
class MasterReview {
  final String id;

  /// Запись, по которой оставлен отзыв (пусто у общих отзывов салонов без мастеров)
  final String bookingId;
  final String masterId;

  /// «Алена С.» — имя мастера уже сокращено сервером
  final String masterName;
  final String salonId;
  final String serviceName;

  /// Кто автор (нужно серверу для проверки права на правку; клиентам не показывается)
  final String authorId;

  /// «Гульнора А.» — имя и первая буква фамилии
  final String authorName;
  final int rating;
  final List<String> tags;
  final String comment;
  final DateTime createdAt;
  final DateTime? editedAt;
  final ReviewReply? reply;

  MasterReview({
    required this.id,
    required this.bookingId,
    required this.masterId,
    this.masterName = '',
    required this.salonId,
    required this.serviceName,
    this.authorId = '',
    required this.authorName,
    required this.rating,
    List<String> tags = const [],
    required this.comment,
    required this.createdAt,
    this.editedAt,
    this.reply,
  }) : tags = List.unmodifiable(tags);

  MasterReview copyWith({int? rating, List<String>? tags, String? comment, DateTime? editedAt, ReviewReply? reply}) {
    return MasterReview(
      id: id,
      bookingId: bookingId,
      masterId: masterId,
      masterName: masterName,
      salonId: salonId,
      serviceName: serviceName,
      authorId: authorId,
      authorName: authorName,
      rating: rating ?? this.rating,
      tags: tags ?? this.tags,
      comment: comment ?? this.comment,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      reply: reply ?? this.reply,
    );
  }
}

/// Сводка по отзывам мастера
@immutable
class ReviewSummary {
  /// Среднее, округлённое до одного знака; 0, если отзывов нет
  final double average;
  final int count;

  /// Количество отзывов по звёздам (ключи 5…1)
  final Map<int, int> byStars;

  const ReviewSummary({required this.average, required this.count, required this.byStars});

  static const empty = ReviewSummary(average: 0, count: 0, byStars: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0});
}

/// Страница списка отзывов
@immutable
class ReviewPage {
  final List<MasterReview> items;

  /// `null` — больше страниц нет
  final String? nextCursor;

  const ReviewPage({required this.items, this.nextCursor});
}

enum ReviewErrorCode {
  notCompleted,
  alreadyReviewed,
  windowClosed,
  ratingRequired,
  reasonRequired,
  tooLong,
  contactsInText,
  notAuthor,
  notYourReview,
  textRequired,
  notFound,
}

class ReviewError {
  final ReviewErrorCode code;
  final String message;

  const ReviewError(this.code, this.message);

  @override
  bool operator ==(Object other) => other is ReviewError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'ReviewError($code: $message)';
}

/// «Гульнора Алиева» → «Гульнора А.»; одно слово остаётся как есть
String shortPersonName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length < 2) return parts.isEmpty ? '' : parts.first;
  return '${parts.first} ${parts[1][0].toUpperCase()}.';
}
