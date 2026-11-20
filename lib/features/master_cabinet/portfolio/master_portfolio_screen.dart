import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import '../../../core/data/app_scope.dart';
import '../../../core/data/repository_exception.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/l10n/app_text.dart';
import '../../../core/models/portfolio_work.dart';
import '../../../core/services/masters_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/uuid.dart';
import '../../../core/widgets/avatars/avatar_image.dart';
import '../../../core/widgets/buttons/app_gradient_button.dart';
import '../../../core/widgets/sheets/app_sheet.dart';

/// Выбор фото для работы: путь к файлу или `null`, если мастер закрыл выбор
typedef PortfolioPhotoPicker = Future<String?> Function(ImageSource source);

Future<String?> _pickWithImagePicker(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: PortfolioRules.pickMaxWidth,
    imageQuality: PortfolioRules.pickQuality,
  );
  return picked?.path;
}

/// Кабинет мастера → «Мои работы»: витрина, которая приводит записи. Каждая работа привязана к услуге мастера,
/// с фото клиент записывается на неё в одно нажатие. Закрепить можно до 3 работ, всего — до 30.
class MasterPortfolioScreen extends StatefulWidget {
  final VoidCallback onBack;

  /// Выбор фото; в тестах подменяется
  final PortfolioPhotoPicker pickPhoto;

  const MasterPortfolioScreen({super.key, required this.onBack, this.pickPhoto = _pickWithImagePicker});

  @override
  State<MasterPortfolioScreen> createState() => _MasterPortfolioScreenState();
}

class _MasterPortfolioScreenState extends State<MasterPortfolioScreen> {
  List<PortfolioWork> _works = const [];
  List<MasterServiceItem> _services = const [];
  bool _consentGiven = false;
  bool _loading = true;
  String? _error;
  int _loadId = 0; // ответ на устаревший запрос игнорируется

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final id = ++_loadId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deps = AppScope.read(context);
      final works = await deps.portfolio.myWorks();
      final consent = await deps.portfolio.consentGiven();
      final master = await deps.catalog.getMaster(deps.appState.masterId);
      if (!mounted || id != _loadId) return;
      setState(() {
        _works = works;
        _services = master?.services ?? const [];
        _consentGiven = consent;
        _loading = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted || id != _loadId) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  /// Тихо перечитать список после изменения (без индикатора загрузки)
  Future<void> _refresh() async {
    try {
      final deps = AppScope.read(context);
      final works = await deps.portfolio.myWorks();
      final consent = await deps.portfolio.consentGiven();
      if (!mounted) return;
      setState(() {
        _works = works;
        _consentGiven = consent;
      });
    } on RepositoryException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  // ── Добавление ────────────────────────────────────────────────────────────

  void _startAdd() {
    if (_works.length >= PortfolioRules.maxWorks) {
      showAppSnack(context, PortfolioRules.limitReachedMessage);
      return;
    }
    showAppSheet<void>(
      context: context,
      title: 'Новая работа',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Выбрать из галереи'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickAndEdit(ImageSource.gallery));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Сделать фото'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickAndEdit(ImageSource.camera));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndEdit(ImageSource source) async {
    final String? path;
    try {
      path = await widget.pickPhoto(source);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Не удалось получить фото. Проверьте доступ к камере и фото в настройках телефона.');
      }
      return;
    }
    if (path == null || !mounted) return; // мастер закрыл выбор
    final saved = await showModalBottomSheet<PortfolioWork>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkEditorSheet(photoPath: path, services: _services, consentNeeded: !_consentGiven),
    );
    if (saved != null && mounted) {
      showAppSnack(context, 'Работа опубликована.');
      unawaited(_refresh());
    }
  }

  // ── Действия с работой ────────────────────────────────────────────────────

  void _showActions(PortfolioWork work) {
    showAppSheet<void>(
      context: context,
      title: work.serviceName,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
              title: const Text('Изменить'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_edit(work));
              },
            ),
            ListTile(
              leading: Icon(work.pinned ? Icons.push_pin : Icons.push_pin_outlined, color: AppColors.primary),
              title: Text(work.pinned ? 'Открепить' : 'Закрепить'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_togglePin(work));
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.primaryText),
              title: const Text('Удалить'),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_confirmDelete(work));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(PortfolioWork work) async {
    final saved = await showModalBottomSheet<PortfolioWork>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkEditorSheet(work: work, services: _services, consentNeeded: false),
    );
    if (saved != null && mounted) {
      showAppSnack(context, 'Изменения сохранены.');
      unawaited(_refresh());
    }
  }

  Future<void> _togglePin(PortfolioWork work) async {
    try {
      final result = await AppScope.read(context).portfolio.update(work.id, pinned: !work.pinned);
      if (!mounted) return;
      if (result case Failure(:final error)) {
        showAppSnack(context, error.message);
        return;
      }
      unawaited(_refresh());
    } on RepositoryException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  Future<void> _confirmDelete(PortfolioWork work) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить работу?'),
        content: const Text('Фото пропадёт из вашего портфолио. Отменить это нельзя.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final result = await AppScope.read(context).portfolio.remove(work.id);
      if (!mounted) return;
      if (result case Failure(:final error)) {
        showAppSnack(context, error.message);
      }
      unawaited(_refresh());
    } on RepositoryException catch (e) {
      if (mounted) showAppSnack(context, e.message);
    }
  }

  // ── Вёрстка ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.ink),
          tooltip: tr('Назад'),
          onPressed: widget.onBack,
        ),
        title: Text('Мои работы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.page),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.screenPadding * 1.5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      AppGradientButton(text: 'Повторить', onPressed: _load),
                    ],
                  ),
                ),
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 8, AppSizes.screenPadding, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_works.length} из ${PortfolioRules.maxWorks}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                if (_works.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте 3–5 лучших работ: клиенты чаще записываются к мастерам с фото',
                    style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSizes.screenPadding, 0, AppSizes.screenPadding, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == 0) return _addTile();
              return _workTile(_works[index - 1]);
            }, childCount: _works.length + 1),
          ),
        ),
      ],
    );
  }

  Widget _addTile() {
    return InkWell(
      onTap: _startAdd,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 32),
            const SizedBox(height: 6),
            Text(
              '+ Добавить работу',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workTile(PortfolioWork work) {
    return GestureDetector(
      onLongPress: () => _showActions(work),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: ResizeImage.resizeIfNeeded(600, null, avatarProvider(work.imageRef)),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.primaryTint,
                child: const Icon(Icons.photo_camera_back_outlined, size: 40, color: AppColors.primary),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (work.serviceId == null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.soft(const Color(0xFFFFF3E0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Услуга больше не оказывается',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSoft(const Color(0xFFB45F06)),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      work.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            if (work.pinned)
              const Positioned(top: 10, left: 10, child: Icon(Icons.push_pin, size: 16, color: Colors.white)),
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                tooltip: tr('Действия'),
                onPressed: () => _showActions(work),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Лист добавления или правки работы: превью, услуга мастера, подпись, согласие (перед первой публикацией).
/// Повтор «Опубликовать» после обрыва связи использует тот же ключ идемпотентности: дубль не создаётся.
class _WorkEditorSheet extends StatefulWidget {
  /// Новая работа: путь к выбранному фото
  final String? photoPath;

  /// Правка существующей работы (фото не меняется)
  final PortfolioWork? work;
  final List<MasterServiceItem> services;
  final bool consentNeeded;

  const _WorkEditorSheet({this.photoPath, this.work, required this.services, required this.consentNeeded});

  @override
  State<_WorkEditorSheet> createState() => _WorkEditorSheetState();
}

class _WorkEditorSheetState extends State<_WorkEditorSheet> {
  late String? _serviceId = widget.work?.serviceId;
  late final TextEditingController _caption = TextEditingController(text: widget.work?.caption ?? '');
  final String _initialKey = Uuid.v4();
  late String _key = _initialKey;
  bool _consent = false;
  bool _sending = false;
  String? _error;

  bool get _isEdit => widget.work != null;

  bool get _canSubmit =>
      !_sending && _serviceId != null && (_isEdit || !widget.consentNeeded || _consent);

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final repo = AppScope.read(context).portfolio;
      final result = _isEdit
          ? await repo.update(widget.work!.id, serviceId: _serviceId, caption: _caption.text)
          : await repo.add(
              localPath: widget.photoPath!,
              serviceId: _serviceId!,
              caption: _caption.text,
              consentAccepted: _consent,
              idempotencyKey: _key,
            );
      if (!mounted) return;
      switch (result) {
        case Success(:final value):
          Navigator.pop(context, value);
        case Failure(:final error):
          setState(() {
            _sending = false;
            _error = error.message;
            _key = Uuid.v4(); // следующая попытка — новый запрос
          });
      }
    } on RepositoryException catch (e) {
      // Связь оборвалась: ключ сохраняется, повтор не создаст работу дважды
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Material, а не Container: чекбокс согласия (ListTile) рисует фон и всплески на ближайшем Material
    return Material(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Изменить работу' : 'Новая работа',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                if (!_isEdit && widget.photoPath != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: Image(
                        image: ResizeImage.resizeIfNeeded(800, null, avatarProvider(widget.photoPath!)),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.primaryTint,
                          child: const Icon(Icons.photo_outlined, color: AppColors.primary, size: 40),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('Услуга', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in widget.services)
                      ChoiceChip(
                        label: Text(s.name),
                        selected: _serviceId == s.id,
                        onSelected: _sending ? null : (_) => setState(() => _serviceId = s.id),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _serviceId == s.id ? Colors.white : AppColors.ink,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Подпись (по желанию)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _caption,
                  maxLines: 2,
                  maxLength: PortfolioRules.maxCaptionLength,
                  enabled: !_sending,
                  decoration: InputDecoration(
                    hintText: tr('Например: Френч + укрепление гелем'),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
                if (!_isEdit && widget.consentNeeded)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                    value: _consent,
                    onChanged: _sending ? null : (v) => setState(() => _consent = v ?? false),
                    title: Text(
                      'Фото сделаны мной. Если в кадре лицо клиента, у меня есть его согласие',
                      style: TextStyle(fontSize: 12, color: AppColors.ink),
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.handle,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _isEdit ? 'Сохранить' : 'Опубликовать',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }
}
