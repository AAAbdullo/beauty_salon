import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/data/app_dependencies.dart';
import '../../core/data/app_scope.dart';
import '../../core/data/repositories/catalog_repository.dart';
import '../../core/data/repositories/slots_repository.dart';
import '../../core/data/repository_exception.dart';
import '../../core/models/booking_draft.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/masters_repository.dart';
import '../../core/services/salons_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../core/utils/slot_pricing.dart';
import '../../core/utils/uuid.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../../core/widgets/sheets/app_sheet.dart';
import '../../core/widgets/states/async_screen.dart';
import '../../core/widgets/states/not_found_screen.dart';

/// Экран бронирования слота (ТЗ M-08)
/// - Выбор услуги и мастера салона
/// - Выбор даты (7 ближайших дней) и свободного слота
/// - Слот закрепляется за клиентом на 10 минут (удержание на сервере); таймер идёт до срока удержания
/// - Способ оплаты: кредиты (с проверкой баланса, заморозки и лимита K-03), онлайн, в салоне
class BookingScreen extends StatelessWidget {
  final String salonId;

  /// `null` — «Любой мастер»
  final String? initialMasterId;
  final MasterServiceItem? initialService;
  final VoidCallback onBack;

  /// Клиент подтвердил запись выбранным способом оплаты ([PaymentMethods]).
  /// `true` — запись передана дальше (оплата или создана); `false` — отказ, экран остаётся открытым.
  final Future<bool> Function(BookingDraft draft, String paymentMethod) onConfirm;

  /// Переход к покупке кредитов, если их не хватает
  final VoidCallback? onTopUpCredits;

  const BookingScreen({
    super.key,
    required this.salonId,
    this.initialMasterId,
    this.initialService,
    required this.onBack,
    required this.onConfirm,
    this.onTopUpCredits,
  });

  @override
  Widget build(BuildContext context) {
    return AsyncScreen<SalonDetails?>(
      title: 'Запись на услугу',
      onBack: onBack,
      reloadKey: salonId,
      load: () => AppScope.read(context).catalog.getSalonDetails(salonId),
      builder: (context, details) {
        if (details == null) {
          return NotFoundScreen(
            title: 'Запись на услугу',
            message: 'Салон не найден. Возможно, он больше не принимает записи.',
            onBack: onBack,
          );
        }
        return _BookingView(
          details: details,
          initialMasterId: initialMasterId,
          initialService: initialService,
          onBack: onBack,
          onConfirm: onConfirm,
          onTopUpCredits: onTopUpCredits,
        );
      },
    );
  }
}

class _BookingView extends StatefulWidget {
  final SalonDetails details;
  final String? initialMasterId;
  final MasterServiceItem? initialService;
  final VoidCallback onBack;
  final Future<bool> Function(BookingDraft draft, String paymentMethod) onConfirm;
  final VoidCallback? onTopUpCredits;

  const _BookingView({
    required this.details,
    required this.initialMasterId,
    required this.initialService,
    required this.onBack,
    required this.onConfirm,
    required this.onTopUpCredits,
  });

  @override
  State<_BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends State<_BookingView> {
  static const _anyMaster = 'Любой мастер';

  final _appState = AppStateService();
  late final AppDependencies _deps;

  late final SalonModel _salon;
  late final List<MasterServiceItem> _services;
  late final List<MasterProfileModel> _salonMasters;
  late final List<DateTime> _days;

  String get _salonId => _salon.id;

  late MasterServiceItem? _service;

  /// Выбранный мастер; `null` — «Любой мастер»
  String? _masterId;
  int _selectedDayIndex = 0;
  DateTime? _selectedStart;
  String _paymentMethod = PaymentMethods.credits;

  // Свободные слоты по дням (ключ — дата без времени) и состояние их загрузки
  Map<DateTime, List<DateTime>> _slotsByDay = {};
  bool _slotsLoading = true;
  Object? _slotsError;
  int _slotsRequestId = 0;
  bool _firstSlotsLoad = true;

  // Удержание слота: выдаёт сервер, таймер лишь отсчитывает до его срока
  SlotHold? _hold;
  bool _holding = false;
  Timer? _holdTimer;
  int _holdSecondsLeft = 0;

  // Ключ идемпотентности попытки: повтор (двойной тап) не создаст вторую запись
  String _idempotencyKey = Uuid.v4();
  bool _submitting = false;

  // Удержание передано дальше (оплата / создание записи) — экран не должен его освобождать
  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _deps = AppScope.read(context);
    _salon = widget.details.salon;
    _services = widget.details.services;
    _salonMasters = widget.details.masters;

    final today = AppClock.now();
    _days = List.generate(7, (i) => DateTime(today.year, today.month, today.day + i));

    _service = widget.initialService ?? (_services.isNotEmpty ? _services.first : null);

    // Мастер подходит, только если он работает в этом салоне (проверка по id)
    final initialId = widget.initialMasterId;
    _masterId = initialId != null && _salonMasters.any((m) => m.id == initialId) ? initialId : null;
    _ensureMasterOffersService();

    if (!_creditsAvailableForSalon) _paymentMethod = PaymentMethods.online;
    unawaited(_reloadSlots());
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    final hold = _hold;
    // Ушли с экрана, не дойдя до записи — слот возвращается в продажу
    if (hold != null && !_handedOff) unawaited(_deps.slots.releaseHold(hold.id));
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Данные
  // ---------------------------------------------------------------------------

  bool get _creditsAvailableForSalon => _salon.creditsAccepted && (_service?.creditsPrice ?? 0) > 0;

  /// Мастера салона, оказывающие выбранную услугу
  List<MasterProfileModel> get _mastersForService {
    final service = _service;
    if (service == null) return const [];
    return _salonMasters.where((m) => m.offers(service.id)).toList();
  }

  void _ensureMasterOffersService() {
    if (_masterId == null) return;
    if (!_mastersForService.any((m) => m.id == _masterId)) _masterId = null;
  }

  /// Название салона для отображения
  String get _salonName => _salon.name;

  /// Подпись выбранного мастера для отображения
  String get _masterLabel {
    final id = _masterId;
    if (id == null) return _anyMaster;
    for (final m in _salonMasters) {
      if (m.id == id) return m.shortName;
    }
    return _anyMaster;
  }

  DateTime get _selectedDay => _days[_selectedDayIndex];

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Свободные слоты дня (загружаются с сервера: график мастера, перерывы, чужие записи, прошедшее время)
  List<DateTime> _slotsForDay(int dayIndex) => _slotsByDay[_dayKey(_days[dayIndex])] ?? const [];

  /// Загрузить слоты на все 7 дней. Устаревшие ответы (после смены мастера/услуги) отбрасываются.
  Future<void> _reloadSlots() async {
    final service = _service;
    if (service == null) {
      setState(() => _slotsLoading = false);
      return;
    }
    final requestId = ++_slotsRequestId;
    setState(() {
      _slotsLoading = true;
      _slotsError = null;
    });
    try {
      final result = await _deps.slots.availableSlotsForDays(
        salonId: _salonId,
        masterId: _masterId,
        serviceId: service.id,
        days: _days,
        durationMinutes: service.durationMinutes,
      );
      if (!mounted || requestId != _slotsRequestId) return;
      setState(() {
        _slotsByDay = result;
        _slotsLoading = false;
        // Открываем ближайший день, на который есть свободные слоты
        if (_firstSlotsLoad || _slotsForDay(_selectedDayIndex).isEmpty) {
          final firstFree = List.generate(_days.length, (i) => i).where((i) => _slotsForDay(i).isNotEmpty);
          if (firstFree.isNotEmpty) _selectedDayIndex = firstFree.first;
        }
        _firstSlotsLoad = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted || requestId != _slotsRequestId) return;
      setState(() {
        _slotsLoading = false;
        _slotsError = e;
      });
    }
  }

  /// ТЗ: цена слота = базовая цена × k_slot (вечер после 18:00 — 1.2)
  int _slotCredits(DateTime start) => SlotPricing.credits(_service?.creditsPrice ?? 0, start);

  String? get _creditsBlockReason {
    if (!_creditsAvailableForSalon) return 'Салон не принимает кредиты';
    final start = _selectedStart;
    return _appState.creditsBlockReason(
      salonId: _salonId,
      credits: start == null ? (_service?.creditsPrice ?? 0) : _slotCredits(start),
      dateTime: start ?? _selectedDay,
    );
  }

  // ---------------------------------------------------------------------------
  // Удержание слота
  // ---------------------------------------------------------------------------

  void _startHoldTimer() {
    _holdTimer?.cancel();
    _tickHold();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tickHold());
  }

  /// Оставшееся время — разница между сроком сервера и текущими часами
  void _tickHold() {
    final hold = _hold;
    if (!mounted || hold == null) return;
    final left = hold.expiresAt.difference(AppClock.now()).inSeconds;
    if (left > 0) {
      setState(() => _holdSecondsLeft = left);
      return;
    }
    _holdTimer?.cancel();
    setState(() {
      _hold = null;
      _selectedStart = null;
      _holdSecondsLeft = 0;
    });
    _showTimeoutDialog();
    unawaited(_reloadSlots());
  }

  /// Сбросить выбор и освободить удержание (смена даты, мастера, услуги)
  void _clearSlot() {
    _holdTimer?.cancel();
    final hold = _hold;
    _hold = null;
    _selectedStart = null;
    _holdSecondsLeft = 0;
    _idempotencyKey = Uuid.v4();
    if (hold != null) unawaited(_deps.slots.releaseHold(hold.id));
  }

  /// Выбор слота: просим сервер закрепить его за клиентом (прежнее удержание заменяется)
  Future<void> _onSlotSelected(DateTime start) async {
    if (_holding || _submitting) return;
    final previous = _hold;
    setState(() {
      _holding = true;
      _selectedStart = start;
    });
    final service = _service!;
    try {
      final result = await _deps.slots.holdSlot(
        salonId: _salonId,
        masterId: _masterId,
        serviceId: service.id,
        startsAt: start,
        durationMinutes: service.durationMinutes,
        replaceHoldId: previous?.id,
      );
      if (!mounted) {
        if (result case Success(:final value)) unawaited(_deps.slots.releaseHold(value.id));
        return;
      }
      switch (result) {
        case Success(:final value):
          setState(() {
            _hold = value;
            _idempotencyKey = Uuid.v4();
          });
          _startHoldTimer();
        case Failure(:final error):
          _holdTimer?.cancel();
          setState(() {
            _hold = null;
            _selectedStart = null;
            _holdSecondsLeft = 0;
          });
          showAppSnack(context, error.message);
          unawaited(_reloadSlots()); // слот мог занять другой клиент — обновляем список
      }
    } on RepositoryException catch (e) {
      if (!mounted) return;
      _holdTimer?.cancel();
      setState(() {
        _hold = null;
        _selectedStart = null;
      });
      showAppSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _holding = false);
    }
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.timer_off_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text('Время брони истекло', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: const Text(
            '10 минут удержания слота истекли, и он снова доступен другим клиентам. Выберите время повторно.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Выбрать время',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTimer(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ---------------------------------------------------------------------------
  // Действия
  // ---------------------------------------------------------------------------

  void _pickService() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSheetHandle(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Выберите услугу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: _services.map((s) {
                    final isSelected = s.id == _service?.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      title: Text(
                        s.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? AppColors.primary : AppColors.ink,
                        ),
                      ),
                      subtitle: Text(
                        '${s.duration} · ${Formatters.formatSum(s.sumPrice)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      trailing: Text(
                        s.creditsPrice > 0 ? Formatters.formatCredits(s.creditsPrice) : '',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryText),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _service = s;
                          _ensureMasterOffersService();
                          // Другая услуга — другая длительность: прежний слот мог перестать подходить
                          _clearSlot();
                          if (!_creditsAvailableForSalon && _paymentMethod == PaymentMethods.credits) {
                            _paymentMethod = PaymentMethods.online;
                          }
                        });
                        unawaited(_reloadSlots());
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final service = _service;
    final hold = _hold;
    final start = _selectedStart;
    if (_submitting || _holding || service == null || hold == null || start == null) return;

    setState(() => _submitting = true);
    final draft = BookingDraft(
      salonId: _salonId,
      salonName: _salonName,
      serviceId: service.id,
      serviceName: service.name,
      durationMinutes: service.durationMinutes,
      masterId: _masterId,
      masterName: _masterLabel,
      dateTime: start,
      baseCredits: service.creditsPrice,
      sumPrice: service.sumPrice,
      holdId: hold.id,
      holdExpiresAt: hold.expiresAt,
      idempotencyKey: _idempotencyKey,
    );

    // Пока идёт оформление, экран может закрыться (успех) — удержание тогда принадлежит дальнейшему потоку
    _handedOff = true;
    var accepted = false;
    try {
      accepted = await widget.onConfirm(draft, _paymentMethod);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (accepted) {
      _holdTimer?.cancel();
    } else {
      // Отказ: удержание остаётся нашим, а следующая попытка — это новый запрос с новым ключом
      _handedOff = false;
      _idempotencyKey = Uuid.v4();
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Запись на услугу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: Column(
          children: [
            Expanded(
              child: _service == null
                  ? const Center(
                      child: Text('В этом салоне пока нет услуг для записи', style: TextStyle(color: AppColors.muted)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHoldTimerBanner(),
                          const SizedBox(height: 14),
                          _buildServiceSummary(),
                          const SizedBox(height: 20),
                          _buildMasterSelector(),
                          const SizedBox(height: 20),
                          _buildDateSelector(),
                          const SizedBox(height: 20),
                          _buildTimeSlots(),
                          const SizedBox(height: 20),
                          _buildPaymentMethodSelector(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),
            if (_service != null) _buildBottomConfirmation(),
          ],
        ),
      ),
    );
  }

  /// ТЗ M-08: Индикатор удержания слота на 10 минут
  Widget _buildHoldTimerBanner() {
    final hasSlot = _hold != null;
    final isLowTime = hasSlot && _holdSecondsLeft < 120;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLowTime ? const Color(0xFFFFECEF) : AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLowTime ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            hasSlot ? Icons.access_time_filled : Icons.touch_app_outlined,
            size: 20,
            color: isLowTime ? Colors.red : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: hasSlot
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Слот закреплён за вами: ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                          ),
                          Text(
                            _formatTimer(_holdSecondsLeft),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: isLowTime ? Colors.red : AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Подтвердите запись, пока таймер не истёк',
                        style: TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  )
                : const Text(
                    'Выберите время — слот закрепится за вами на 10 минут',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceSummary() {
    final service = _service!;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: _services.length > 1 ? _pickService : null,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              _salon.imageAsset,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 60,
                height: 60,
                color: AppColors.primaryTint,
                child: const Icon(Icons.spa, color: AppColors.primary, size: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text(_salonName, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(service.duration, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(width: 8),
                    const Icon(Icons.star, size: 13, color: AppColors.primary),
                    const SizedBox(width: 2),
                    Text(
                      '${_salon.rating} (${_salon.reviewsCount})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_services.length > 1)
            const Column(
              children: [
                Icon(Icons.swap_horiz, color: AppColors.primary, size: 20),
                Text(
                  'Сменить',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMasterSelector() {
    final masters = _mastersForService;
    // null — «Любой мастер»
    final options = <MasterProfileModel?>[null, ...masters];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Мастер', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final master = options[index];
              final name = master?.shortName ?? _anyMaster;
              final isSelected = master?.id == _masterId;
              return _SelectableTile(
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _masterId = master?.id;
                    _clearSlot();
                  });
                  unawaited(_reloadSlots());
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: isSelected ? AppColors.primary : AppColors.primaryTint,
                      backgroundImage: master != null ? AssetImage(master.avatarAsset) : null,
                      child: master == null
                          ? Icon(
                              Icons.groups_2_outlined,
                              size: 20,
                              color: isSelected ? Colors.white : AppColors.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        if (master != null)
                          Row(
                            children: [
                              const Icon(Icons.star, size: 11, color: AppColors.primary),
                              const SizedBox(width: 2),
                              Text(
                                '${master.rating}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        else
                          const Text('Ближайший свободный', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите дату', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final d = _days[index];
              final isSelected = index == _selectedDayIndex;
              final isFull = !_slotsLoading && _slotsForDay(index).isEmpty;
              final caption = index == 0 ? 'Сег.' : (index == 1 ? 'Завт.' : Formatters.weekDaysShort[d.weekday - 1]);
              return Opacity(
                opacity: isFull ? 0.45 : 1,
                child: InkWell(
                  onTap: isFull || _holding || _submitting
                      ? null
                      : () => setState(() {
                          _selectedDayIndex = index;
                          _clearSlot();
                        }),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: AppSizes.dateWidth,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          caption,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white70 : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSlots() {
    final slots = _slotsForDay(_selectedDayIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Доступное время', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (_selectedStart != null)
              Text(
                'Выбрано: ${Formatters.time(_selectedStart!)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_slotsLoading || _slotsError != null)
          AsyncSection(
            isLoading: _slotsLoading,
            error: _slotsError,
            onRetry: () => unawaited(_reloadSlots()),
            minHeight: 96,
            child: const SizedBox.shrink(),
          )
        else if (slots.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'На этот день свободного времени нет. Выберите другую дату или другого мастера.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 24) / 4;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: slots.map((start) {
                  final isSelected = _selectedStart == start;
                  final costLabel = _creditsAvailableForSalon ? '${_slotCredits(start)} кр.' : 'свободно';
                  return InkWell(
                    onTap: _holding || _submitting ? null : () => _onSlotSelected(start),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: width,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFFF3DCE8)),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            Formatters.time(start),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            costLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white70 : AppColors.primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        if (_creditsAvailableForSalon) ...[
          const SizedBox(height: 8),
          const Text(
            'Вечерние слоты с 18:00 стоят на 20% больше кредитов',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentMethodSelector() {
    final creditsReason = _creditsBlockReason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Способ оплаты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildPayOption(
                method: PaymentMethods.credits,
                title: 'Кредиты',
                subtitle: creditsReason ?? 'Баланс: ${_appState.clientCredits}',
                icon: Icons.account_balance_wallet,
                enabled: creditsReason == null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPayOption(
                method: PaymentMethods.online,
                title: 'Онлайн',
                subtitle: 'Click, Payme, Uzum',
                icon: Icons.credit_card,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPayOption(
                method: PaymentMethods.inSalon,
                title: 'В салоне',
                subtitle: 'При визите',
                icon: Icons.store,
              ),
            ),
          ],
        ),
        if (creditsReason != null && creditsReason.startsWith('Не хватает') && widget.onTopUpCredits != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onTopUpCredits,
              icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
              label: const Text(
                'Пополнить кредиты',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPayOption({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
    bool enabled = true,
  }) {
    final isSelected = enabled && _paymentMethod == method;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: _SelectableTile(
        isSelected: isSelected,
        onTap: enabled ? () => setState(() => _paymentMethod = method) : null,
        height: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.muted),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary : AppColors.ink,
              ),
            ),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: enabled ? AppColors.muted : AppColors.primaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomConfirmation() {
    // Если кредиты стали недоступны (например, выбран вечерний слот дороже баланса) — переключаем на онлайн
    final effectiveMethod = _paymentMethod == PaymentMethods.credits && _creditsBlockReason != null
        ? PaymentMethods.online
        : _paymentMethod;
    if (effectiveMethod != _paymentMethod) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _paymentMethod = effectiveMethod);
      });
    }

    final start = _selectedStart;
    final service = _service!;
    final String buttonText;
    if (start == null) {
      buttonText = 'Выберите время';
    } else if (_hold == null) {
      buttonText = 'Закрепляем слот…';
    } else if (effectiveMethod == PaymentMethods.credits) {
      buttonText = 'Записаться · ${_slotCredits(start)} кр.';
    } else if (effectiveMethod == PaymentMethods.online) {
      buttonText = 'К оплате · ${Formatters.formatSum(service.sumPrice)}';
    } else {
      buttonText = 'Записаться · оплата в салоне';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (start != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${Formatters.dayLabel(start)}, ${Formatters.time(start)} · $_masterLabel',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
            AppGradientButton(
              text: buttonText,
              isLoading: _submitting,
              onPressed: _hold == null || _holding ? null : _confirm,
            ),
            const SizedBox(height: 6),
            const Text(
              'Бесплатная отмена и перенос — не позднее чем за 2 часа до визита',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плитка выбора с рамкой (мастер, способ оплаты)
class _SelectableTile extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget child;
  final double? height;

  const _SelectableTile({required this.isSelected, required this.onTap, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFF3DCE8), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }
}
