import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/booking_draft.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/masters_repository.dart';
import '../../core/services/salons_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../../core/widgets/sheets/app_sheet.dart';

/// Экран бронирования слота (ТЗ M-08)
/// - Выбор услуги и мастера салона
/// - Выбор даты (7 ближайших дней) и свободного слота
/// - Таймер удержания выбранного слота на 10 минут
/// - Способ оплаты: кредиты (с проверкой баланса, заморозки и лимита K-03), онлайн, в салоне
class BookingScreen extends StatefulWidget {
  final String salonName;
  final String? initialMasterName;
  final MasterServiceItem? initialService;
  final VoidCallback onBack;

  /// Клиент подтвердил запись выбранным способом оплаты ([PaymentMethods])
  final void Function(BookingDraft draft, String paymentMethod) onConfirm;

  /// Переход к покупке кредитов, если их не хватает
  final VoidCallback? onTopUpCredits;

  const BookingScreen({
    super.key,
    required this.salonName,
    this.initialMasterName,
    this.initialService,
    required this.onBack,
    required this.onConfirm,
    this.onTopUpCredits,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const _anyMaster = 'Любой мастер';
  static const _holdDuration = 600; // ТЗ M-08: слот удерживается 10 минут
  static const _slotHours = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

  final _appState = AppStateService();
  final _salonsRepo = SalonsRepository();
  final _mastersRepo = MastersRepository();

  late final SalonModel? _salon;
  late final List<MasterServiceItem> _services;
  late final List<MasterProfileModel> _salonMasters;
  late final List<DateTime> _days;

  late MasterServiceItem? _service;
  late String _masterName;
  int _selectedDayIndex = 0;
  int? _selectedHour;
  String _paymentMethod = PaymentMethods.credits;

  Timer? _holdTimer;
  int _holdSecondsLeft = _holdDuration;

  @override
  void initState() {
    super.initState();
    _salon = _salonsRepo.getSalonByName(widget.salonName);
    _services = _salonsRepo.getSalonServices(widget.salonName);
    _salonMasters = _mastersRepo.getMastersForSalon(widget.salonName);

    final today = DateTime.now();
    _days = List.generate(7, (i) => DateTime(today.year, today.month, today.day + i));

    _service = widget.initialService ?? (_services.isNotEmpty ? _services.first : null);

    final initialMaster = widget.initialMasterName == null ? null : _mastersRepo.findMaster(widget.initialMasterName!);
    _masterName = initialMaster != null && _salonMasters.any((m) => m.id == initialMaster.id)
        ? initialMaster.shortName
        : _anyMaster;
    _ensureMasterOffersService();

    // Если сегодня свободных слотов уже нет — сразу открываем завтрашний день
    if (_availableHours(0).isEmpty) _selectedDayIndex = 1;

    if (!_creditsAvailableForSalon) _paymentMethod = PaymentMethods.online;
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Данные
  // ---------------------------------------------------------------------------

  bool get _creditsAvailableForSalon => (_salon?.creditsAccepted ?? true) && (_service?.creditsPrice ?? 0) > 0;

  /// Мастера салона, оказывающие выбранную услугу
  List<MasterProfileModel> get _mastersForService {
    final service = _service;
    if (service == null) return const [];
    return _salonMasters.where((m) => m.offers(service.name)).toList();
  }

  void _ensureMasterOffersService() {
    if (_masterName == _anyMaster) return;
    if (!_mastersForService.any((m) => m.shortName == _masterName)) _masterName = _anyMaster;
  }

  DateTime get _selectedDay => _days[_selectedDayIndex];

  /// Слот «занят» — детерминированный мок занятости (до появления API слотов)
  bool _isBusy(int dayIndex, int hour) {
    final seed = '${widget.salonName}|$_masterName|${_days[dayIndex].day}|$hour'.hashCode;
    return seed % 5 == 0;
  }

  /// Слот в прошлом или начинается меньше чем через 30 минут
  bool _isPast(int dayIndex, int hour) {
    final slot = DateTime(_days[dayIndex].year, _days[dayIndex].month, _days[dayIndex].day, hour);
    return slot.isBefore(DateTime.now().add(const Duration(minutes: 30)));
  }

  List<int> _availableHours(int dayIndex) =>
      _slotHours.where((h) => !_isPast(dayIndex, h) && !_isBusy(dayIndex, h)).toList();

  /// ТЗ: цена слота = базовая цена × k_slot (вечер после 18:00 — 1.2)
  int _slotCredits(int hour) {
    final base = _service?.creditsPrice ?? 0;
    final k = hour >= 18 ? 1.2 : 1.0;
    return (base * k).ceil();
  }

  DateTime? get _selectedDateTime =>
      _selectedHour == null ? null : DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, _selectedHour!);

  String? get _creditsBlockReason {
    if (!_creditsAvailableForSalon) return 'Салон не принимает кредиты';
    final dateTime = _selectedDateTime ?? _selectedDay;
    return _appState.creditsBlockReason(
      salonName: widget.salonName,
      credits: _selectedHour == null ? (_service?.creditsPrice ?? 0) : _slotCredits(_selectedHour!),
      dateTime: dateTime,
    );
  }

  // ---------------------------------------------------------------------------
  // Удержание слота
  // ---------------------------------------------------------------------------

  void _startHoldTimer() {
    _holdTimer?.cancel();
    setState(() => _holdSecondsLeft = _holdDuration);
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_holdSecondsLeft > 1) {
        setState(() => _holdSecondsLeft--);
      } else {
        timer.cancel();
        setState(() {
          _holdSecondsLeft = 0;
          _selectedHour = null;
        });
        _showTimeoutDialog();
      }
    });
  }

  void _clearSlot() {
    _holdTimer?.cancel();
    _selectedHour = null;
  }

  void _onSlotSelected(int hour) {
    setState(() => _selectedHour = hour);
    _startHoldTimer();
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
                    final isSelected = s.name == _service?.name;
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
                          if (!_creditsAvailableForSalon && _paymentMethod == PaymentMethods.credits) {
                            _paymentMethod = PaymentMethods.online;
                          }
                        });
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

  void _confirm() {
    final service = _service;
    final dateTime = _selectedDateTime;
    if (service == null || dateTime == null) return;
    _holdTimer?.cancel();
    widget.onConfirm(
      BookingDraft(
        salonName: widget.salonName,
        serviceName: service.name,
        durationLabel: service.duration,
        masterName: _masterName,
        dateTime: dateTime,
        credits: _slotCredits(dateTime.hour),
        sumPrice: service.sumPrice,
      ),
      _paymentMethod,
    );
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
    final hasSlot = _selectedHour != null;
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
              _salon?.imageAsset ?? '',
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
                Text(widget.salonName, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 13, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(service.duration, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    if (_salon != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star, size: 13, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        '${_salon.rating} (${_salon.reviewsCount})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
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
    final options = <String>[_anyMaster, ...masters.map((m) => m.shortName)];

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
              final name = options[index];
              final master = index == 0 ? null : masters[index - 1];
              final isSelected = name == _masterName;
              return _SelectableTile(
                isSelected: isSelected,
                onTap: () => setState(() {
                  _masterName = name;
                  _clearSlot();
                }),
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
              final isFull = _availableHours(index).isEmpty;
              final caption = index == 0 ? 'Сег.' : (index == 1 ? 'Завт.' : Formatters.weekDaysShort[d.weekday - 1]);
              return Opacity(
                opacity: isFull ? 0.45 : 1,
                child: InkWell(
                  onTap: isFull
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Доступное время', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (_selectedHour != null)
              Text(
                'Выбрано: ${_selectedHour.toString().padLeft(2, '0')}:00',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 24) / 4;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _slotHours.map((hour) {
                final isSelected = _selectedHour == hour;
                final isPast = _isPast(_selectedDayIndex, hour);
                final isBusy = !isPast && _isBusy(_selectedDayIndex, hour);
                final enabled = !isPast && !isBusy;
                final costLabel = isPast
                    ? 'прошло'
                    : isBusy
                    ? 'занято'
                    : (_creditsAvailableForSalon ? '${_slotCredits(hour)} кр.' : 'свободно');
                return Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: InkWell(
                    onTap: enabled ? () => _onSlotSelected(hour) : null,
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
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : AppColors.ink,
                              decoration: enabled ? null : TextDecoration.lineThrough,
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
        height: 78,
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

    final hour = _selectedHour;
    final service = _service!;
    final String buttonText;
    if (hour == null) {
      buttonText = 'Выберите время';
    } else if (effectiveMethod == PaymentMethods.credits) {
      buttonText = 'Записаться · ${_slotCredits(hour)} кр.';
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
            if (hour != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${Formatters.dayLabel(_selectedDateTime!)}, ${Formatters.time(_selectedDateTime!)} · $_masterName',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
            AppGradientButton(text: buttonText, onPressed: hour == null ? null : _confirm),
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
