import 'package:flutter/foundation.dart';

/// Правила портфолио мастера (единственное место с числами)
class PortfolioRules {
  PortfolioRules._();

  /// Работ на мастера
  static const maxWorks = 30;

  /// Закреплённых работ (они идут первыми и попадают в превью на странице салона)
  static const maxPinned = 3;

  static const maxCaptionLength = 150;

  /// Файл тяжелее отклоняется
  static const maxFileBytes = 10 * 1024 * 1024;

  /// Параметры выбора фото
  static const pickMaxWidth = 1600.0;
  static const pickQuality = 85;

  /// Сколько миниатюр закреплённых (или свежих) работ показывается в карточке мастера на странице салона
  static const previewCount = 3;

  /// Сообщение, когда лимит работ исчерпан (его же показывает кабинет, не дожидаясь выбора фото)
  static const limitReachedMessage = 'В портфолио уже $maxWorks работ. Удалите старые, чтобы добавить новую.';
}

/// Работа в портфолио мастера: фото, привязанное к услуге, с подписью
@immutable
class PortfolioWork {
  final String id;
  final String masterId;

  /// Ресурс приложения (сид), путь к файлу (мок) или URL (бэкенд)
  final String imageRef;

  /// `null` — мастер больше не оказывает эту услугу: работа остаётся, но записаться с неё нельзя
  final String? serviceId;
  final String serviceName;
  final String caption;
  final bool pinned;
  final DateTime createdAt;

  const PortfolioWork({
    required this.id,
    required this.masterId,
    required this.imageRef,
    required this.serviceId,
    required this.serviceName,
    this.caption = '',
    this.pinned = false,
    required this.createdAt,
  });

  bool get isAsset => imageRef.startsWith('assets/');

  PortfolioWork copyWith({String? serviceId, String? serviceName, String? caption, bool? pinned}) => PortfolioWork(
    id: id,
    masterId: masterId,
    imageRef: imageRef,
    serviceId: serviceId ?? this.serviceId,
    serviceName: serviceName ?? this.serviceName,
    caption: caption ?? this.caption,
    pinned: pinned ?? this.pinned,
    createdAt: createdAt,
  );

  /// Без привязки к услуге (её убрали у мастера)
  PortfolioWork withoutService() => PortfolioWork(
    id: id,
    masterId: masterId,
    imageRef: imageRef,
    serviceId: null,
    serviceName: serviceName,
    caption: caption,
    pinned: pinned,
    createdAt: createdAt,
  );
}

enum PortfolioErrorCode {
  limitReached,
  pinLimitReached,
  unknownService,
  fileTooLarge,
  captionTooLong,
  contactsInText,
  notFound,
  consentRequired,
}

class PortfolioError {
  final PortfolioErrorCode code;
  final String message;

  const PortfolioError(this.code, this.message);

  @override
  bool operator ==(Object other) => other is PortfolioError && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'PortfolioError($code: $message)';
}
