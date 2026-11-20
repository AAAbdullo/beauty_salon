import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/master_review.dart';
import '../models/portfolio_work.dart';
import '../utils/clock.dart';
import '../utils/result.dart';
import '../utils/uuid.dart';
import 'masters_repository.dart';

/// Файлы портфолио на устройстве (мок «сервера»): выбранное фото копируется в папку приложения.
/// Исходник может исчезнуть из галереи или кэша пикера.
abstract interface class PortfolioFiles {
  /// Размер файла в байтах; `null`, если файла нет
  Future<int?> sizeOf(String path);

  /// Копия файла в папке приложения; возвращает новый путь
  Future<String> copyIn(String sourcePath);

  Future<void> delete(String path);

  /// Удалить все сохранённые файлы (выход из аккаунта)
  Future<void> deleteAll();
}

/// Файлы в Application Support/portfolio (не видны пользователю в «Файлах»)
class AppSupportPortfolioFiles implements PortfolioFiles {
  const AppSupportPortfolioFiles();

  static int _counter = 0;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/portfolio');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<int?> sizeOf(String path) async {
    try {
      final file = File(path);
      return await file.exists() ? await file.length() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> copyIn(String sourcePath) async {
    final dir = await _dir();
    // Новое имя на каждую работу: Flutter не показывает прежнюю картинку из кэша
    final target = '${dir.path}/work_${DateTime.now().millisecondsSinceEpoch}_${_counter++}.jpg';
    await File(sourcePath).copy(target);
    return target;
  }

  @override
  Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  @override
  Future<void> deleteAll() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/portfolio');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// Хранилище портфолио — часть мок-«сервера»: данные и правила (лимиты, закрепление, согласие, подпись).
/// Работы между запусками приложения не сохраняются: при каждом запуске берутся сиды из `portfolioImages`.
class PortfolioStore {
  PortfolioStore._(this._works, this._storedService, this._serviceIdsOf, this._files);

  final List<PortfolioWork> _works;

  /// Услуга, к которой работа была привязана; работа показывается с ней, пока мастер её оказывает
  final Map<String, String> _storedService;
  final Set<String> Function(String masterId) _serviceIdsOf;
  final PortfolioFiles _files;

  bool _consentGiven = false;

  /// Согласие «Фото сделаны мной…» запоминается на сессию мастера
  bool get consentGiven => _consentGiven;

  /// Сиды: каждая работа привязана к первой подходящей услуге мастера
  factory PortfolioStore.seed({
    required List<MasterProfileModel> masters,
    PortfolioFiles files = const AppSupportPortfolioFiles(),
    Set<String> Function(String masterId)? serviceIdsOf,
  }) {
    final now = AppClock.now();
    final byMaster = {for (final m in masters) m.id: m};
    final works = <PortfolioWork>[];
    final stored = <String, String>{};
    for (final m in masters) {
      for (var i = 0; i < m.portfolioImages.length; i++) {
        final service = _serviceFor(m, m.portfolioImages[i]);
        if (service == null) continue;
        final id = 'w-${m.id}-${i + 1}';
        works.add(
          PortfolioWork(
            id: id,
            masterId: m.id,
            imageRef: m.portfolioImages[i],
            serviceId: service.id,
            serviceName: service.name,
            createdAt: now.subtract(Duration(days: i + 1)),
          ),
        );
        stored[id] = service.id;
      }
    }
    return PortfolioStore._(
      works,
      stored,
      serviceIdsOf ?? (masterId) => {...?byMaster[masterId]?.services.map((s) => s.id)},
      files,
    );
  }

  /// Первая услуга мастера, подходящая по названию файла (маникюр, брови, волосы); иначе первая услуга
  static MasterServiceItem? _serviceFor(MasterProfileModel m, String asset) {
    if (m.services.isEmpty) return null;
    const keywords = {
      'manicure': ['маникюр', 'педикюр', 'ногт', 'френч'],
      'brows': ['бров', 'ресниц'],
      'hair': ['стриж', 'окраш', 'волос', 'balayage'],
    };
    for (final entry in keywords.entries) {
      if (!asset.contains(entry.key)) continue;
      for (final s in m.services) {
        final name = s.name.toLowerCase();
        if (entry.value.any(name.contains)) return s;
      }
    }
    return m.services.first;
  }

  PortfolioWork _view(PortfolioWork w) {
    final id = _storedService[w.id];
    return id != null && _serviceIdsOf(w.masterId).contains(id) ? w.copyWith(serviceId: id) : w.withoutService();
  }

  static int _order(PortfolioWork a, PortfolioWork b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    final byDate = b.createdAt.compareTo(a.createdAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  }

  /// Работы мастера: сначала закреплённые, потом свежие
  List<PortfolioWork> works(String masterId) =>
      _works.where((w) => w.masterId == masterId).map(_view).toList()..sort(_order);

  /// Превью для карточки мастера: закреплённые работы, а если их нет, самые свежие (до [PortfolioRules.previewCount])
  List<PortfolioWork> preview(String masterId) {
    final all = works(masterId);
    final pinned = all.where((w) => w.pinned).toList();
    return (pinned.isNotEmpty ? pinned : all).take(PortfolioRules.previewCount).toList();
  }

  PortfolioWork? _mine(String masterId, String workId) {
    for (final w in _works) {
      if (w.id == workId && w.masterId == masterId) return w;
    }
    return null;
  }

  PortfolioError? _validateCaption(String caption) {
    if (caption.trim().length > PortfolioRules.maxCaptionLength) {
      return const PortfolioError(
        PortfolioErrorCode.captionTooLong,
        'Подпись не длиннее ${PortfolioRules.maxCaptionLength} символов.',
      );
    }
    if (ContactsInText.found(caption)) {
      return const PortfolioError(PortfolioErrorCode.contactsInText, 'Уберите из подписи контакты и ссылки.');
    }
    return null;
  }

  MasterServiceItem? _service(String masterId, String serviceId) {
    if (!_serviceIdsOf(masterId).contains(serviceId)) return null;
    return MastersRepository().getMasterById(masterId)?.services.where((s) => s.id == serviceId).firstOrNull;
  }

  /// Записать согласие «Фото сделаны мной…» (запоминается до выхода из аккаунта)
  void giveConsent() => _consentGiven = true;

  Future<Result<PortfolioWork, PortfolioError>> add({
    required String masterId,
    required String localPath,
    required String serviceId,
    String caption = '',
    bool consentAccepted = false,
  }) async {
    if (!_consentGiven && !consentAccepted) {
      return const Result.failure(
        PortfolioError(PortfolioErrorCode.consentRequired, 'Подтвердите, что фото сделаны вами.'),
      );
    }
    if (_works.where((w) => w.masterId == masterId).length >= PortfolioRules.maxWorks) {
      return const Result.failure(
        PortfolioError(PortfolioErrorCode.limitReached, PortfolioRules.limitReachedMessage),
      );
    }
    final service = _service(masterId, serviceId);
    if (service == null) {
      return const Result.failure(
        PortfolioError(PortfolioErrorCode.unknownService, 'Выберите услугу из своего списка услуг.'),
      );
    }
    final invalid = _validateCaption(caption);
    if (invalid != null) return Result.failure(invalid);

    final size = await _files.sizeOf(localPath);
    if (size == null) {
      return const Result.failure(PortfolioError(PortfolioErrorCode.notFound, 'Файл не найден. Выберите фото заново.'));
    }
    if (size > PortfolioRules.maxFileBytes) {
      return const Result.failure(
        PortfolioError(PortfolioErrorCode.fileTooLarge, 'Фото тяжелее 10 МБ. Выберите другое.'),
      );
    }
    final path = await _files.copyIn(localPath);
    // Пока шло копирование, параллельный add мог занять последнее место: проверяем лимит ещё раз
    if (_works.where((w) => w.masterId == masterId).length >= PortfolioRules.maxWorks) {
      await _files.delete(path);
      return const Result.failure(
        PortfolioError(PortfolioErrorCode.limitReached, PortfolioRules.limitReachedMessage),
      );
    }
    if (consentAccepted) _consentGiven = true;
    final work = PortfolioWork(
      id: 'w-${Uuid.v4()}',
      masterId: masterId,
      imageRef: path,
      serviceId: service.id,
      serviceName: service.name,
      caption: caption.trim(),
      createdAt: AppClock.now(),
    );
    _works.add(work);
    _storedService[work.id] = service.id;
    return Result.success(_view(work));
  }

  Result<PortfolioWork, PortfolioError> update(
    String masterId,
    String workId, {
    String? serviceId,
    String? caption,
    bool? pinned,
  }) {
    final work = _mine(masterId, workId);
    if (work == null) return const Result.failure(PortfolioError(PortfolioErrorCode.notFound, 'Работа не найдена.'));

    MasterServiceItem? service;
    if (serviceId != null) {
      service = _service(masterId, serviceId);
      if (service == null) {
        return const Result.failure(
          PortfolioError(PortfolioErrorCode.unknownService, 'Выберите услугу из своего списка услуг.'),
        );
      }
    }
    if (caption != null) {
      final invalid = _validateCaption(caption);
      if (invalid != null) return Result.failure(invalid);
    }
    if (pinned == true && !work.pinned) {
      final pinnedCount = _works.where((w) => w.masterId == masterId && w.pinned).length;
      if (pinnedCount >= PortfolioRules.maxPinned) {
        return const Result.failure(
          PortfolioError(
            PortfolioErrorCode.pinLimitReached,
            'Можно закрепить не больше ${PortfolioRules.maxPinned} работ.',
          ),
        );
      }
    }

    final updated = work.copyWith(
      serviceId: service?.id,
      serviceName: service?.name,
      caption: caption?.trim(),
      pinned: pinned,
    );
    _works[_works.indexOf(work)] = updated;
    if (service != null) _storedService[workId] = service.id;
    return Result.success(_view(updated));
  }

  Future<Result<void, PortfolioError>> remove(String masterId, String workId) async {
    final work = _mine(masterId, workId);
    if (work == null) return const Result.failure(PortfolioError(PortfolioErrorCode.notFound, 'Работа не найдена.'));
    _works.remove(work);
    _storedService.remove(workId);
    if (!work.isAsset) await _files.delete(work.imageRef);
    return const Result.success(null);
  }

  /// Выход из аккаунта: загруженные файлы удаляются вместе с портфолио
  Future<void> clearFiles() => _files.deleteAll();
}
