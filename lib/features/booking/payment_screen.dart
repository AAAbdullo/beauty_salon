import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/data/app_scope.dart';
import '../../core/data/repositories/payments_repository.dart';
import '../../core/data/repository_exception.dart';
import '../../core/models/booking_draft.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../core/utils/uuid.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/cards/app_card.dart';

/// Онлайн-оплата записи (ТЗ M-09): депозит 20% или полная сумма через Click / Payme / Uzum / карту.
class PaymentScreen extends StatefulWidget {
  final BookingDraft draft;
  final VoidCallback onBack;

  /// Платёж прошёл: создать запись. Возвращает `true`, если запись создана.
  final Future<bool> Function(PaymentReceipt receipt) onPaid;

  /// Идёт ли оплата: пока идёт, «Назад» не должна закрывать экран (иначе деньги спишутся без записи)
  final ValueChanged<bool>? onBusyChanged;

  const PaymentScreen({
    super.key,
    required this.draft,
    required this.onBack,
    required this.onPaid,
    this.onBusyChanged,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isDeposit = true;
  int _selectedProvider = 0; // 0: Click, 1: Payme, 2: Uzum, 3: Карта
  bool _isProcessing = false;
  String? _error;

  // Ключ идемпотентности попытки оплаты: двойной тап платит один раз
  String _payKey = Uuid.v4();

  // Слот закреплён за клиентом до срока удержания; оплачивать нужно успеть
  Timer? _holdTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _secondsLeft = _remaining();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    if (_isProcessing) widget.onBusyChanged?.call(false);
    super.dispose();
  }

  void _setBusy(bool busy) {
    setState(() => _isProcessing = busy);
    widget.onBusyChanged?.call(busy);
  }

  int _remaining() => widget.draft.holdExpiresAt.difference(AppClock.now()).inSeconds.clamp(0, 1 << 30);

  void _tick() {
    if (!mounted || _isProcessing) return; // пока идёт оплата, сервер сам продлевает удержание
    final left = _remaining();
    if (left > 0) {
      setState(() => _secondsLeft = left);
      return;
    }
    _holdTimer?.cancel();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Время брони истекло', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          'Слот больше не закреплён за вами. Выберите время заново — деньги не списаны.',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Выбрать время', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) {
      if (mounted) widget.onBack();
    });
  }

  String get _timerLabel =>
      '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';

  static final _providers = [
    ('Click', Icons.radio_button_checked, AppColors.onSoft(const Color(0xFF007AFF))),
    ('Payme', Icons.account_balance_wallet, Color(0xFF00C7B5)),
    ('Uzum', Icons.shopping_bag, Color(0xFF7000FF)),
    ('Сохранённая карта ···· 4417', Icons.credit_card, Color(0xFFFF5A00)),
  ];

  int get _amount => _isDeposit ? widget.draft.depositSum : widget.draft.sumPrice;

  Future<void> _pay() async {
    if (_isProcessing) return; // второй тап в том же кадре
    _error = null;
    _setBusy(true);
    final provider = _providers[_selectedProvider].$1;
    try {
      final result = await AppScope.read(context).payments.pay(
        amount: _amount,
        provider: provider,
        holdId: widget.draft.holdId,
        idempotencyKey: _payKey,
      );
      if (!mounted) return;
      switch (result) {
        case Success(:final value):
          // Платёж прошёл — создаём запись; при отказе платёж вернёт вызывающий код
          await widget.onPaid(value);
          if (mounted) _setBusy(false);
        case Failure(:final error):
          _setBusy(false);
          setState(() {
            _error = error.message;
            _payKey = Uuid.v4(); // следующая попытка — новый платёж
          });
      }
    } on RepositoryException catch (e) {
      // Связь оборвалась: ключ сохраняется, повтор не спишет деньги дважды
      if (mounted) {
        _setBusy(false);
        setState(() => _error = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: _isProcessing ? null : widget.onBack,
          ),
          title: Text(
            'Оплата',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(gradient: AppGradients.page),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHoldBanner(),
                      const SizedBox(height: 12),
                      _buildServiceCostCard(),
                      const SizedBox(height: 16),
                      _buildDepositToggle(),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _isDeposit
                              ? 'Остаток ${Formatters.formatSum(widget.draft.sumPrice - widget.draft.depositSum)} оплатите в салоне.'
                              : 'Услуга будет полностью оплачена.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Способ оплаты', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _buildPaymentMethods(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.muted),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Данные карты мы не храним, платёж проходит через провайдера. '
                              'При отмене не позднее чем за 2 часа деньги вернутся полностью.',
                              style: TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomPayButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoldBanner() {
    final low = _secondsLeft < 120;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: low ? AppColors.soft(const Color(0xFFFFECEF)) : AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: low ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_filled, size: 20, color: low ? Colors.red : AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Слот закреплён за вами: $_timerLabel',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCostCard() {
    final d = widget.draft;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.serviceName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '${d.salonName} · ${d.masterName}',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(Formatters.formatSum(d.sumPrice), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          Divider(height: 20, color: AppColors.line),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '${Formatters.dayLabel(d.dateTime)}, ${Formatters.time(d.dateTime)} · ${d.durationLabel}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepositToggle() {
    Widget option(bool deposit, String label) {
      final isSelected = _isDeposit == deposit;
      return Expanded(
        child: Material(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          elevation: isSelected ? 2 : 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          child: InkWell(
            onTap: _isProcessing ? null : () => setState(() => _isDeposit = deposit),
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 46,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(true, 'Депозит ${Formatters.formatSum(widget.draft.depositSum)}'),
        const SizedBox(width: 10),
        option(false, 'Полностью'),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      children: List.generate(_providers.length, (index) {
        final (name, icon, color) = _providers[index];
        final isSelected = _selectedProvider == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: isSelected ? AppColors.primary : AppColors.line, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _isProcessing ? null : () => setState(() => _selectedProvider = index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? AppColors.primary : AppColors.muted,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(icon, size: 18, color: color),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomPayButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AppGradientButton(
          text: 'Оплатить ${Formatters.formatSum(_amount)}',
          isLoading: _isProcessing,
          onPressed: _pay,
        ),
      ),
    );
  }
}
