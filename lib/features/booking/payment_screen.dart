import 'package:flutter/material.dart';
import '../../core/models/booking_draft.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/cards/app_card.dart';

/// Онлайн-оплата записи (ТЗ M-09): депозит 20% или полная сумма через Click / Payme / Uzum / карту.
class PaymentScreen extends StatefulWidget {
  final BookingDraft draft;
  final VoidCallback onBack;

  /// Платёж прошёл (провайдер эмулируется до подключения бэкенда)
  final VoidCallback onPaymentSuccess;

  const PaymentScreen({super.key, required this.draft, required this.onBack, required this.onPaymentSuccess});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isDeposit = true;
  int _selectedProvider = 0; // 0: Click, 1: Payme, 2: Uzum, 3: Карта
  bool _isProcessing = false;

  static const _providers = [
    ('Click', Icons.radio_button_checked, Color(0xFF007AFF)),
    ('Payme', Icons.account_balance_wallet, Color(0xFF00C7B5)),
    ('Uzum', Icons.shopping_bag, Color(0xFF7000FF)),
    ('Сохранённая карта ···· 4417', Icons.credit_card, Color(0xFFFF5A00)),
  ];

  int get _amount => _isDeposit ? widget.draft.depositSum : widget.draft.sumPrice;

  Future<void> _pay() async {
    setState(() => _isProcessing = true);
    // [BACKEND NOTE]: POST /api/v1/payments → redirect на провайдера → webhook подтверждения
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isProcessing = false);
    widget.onPaymentSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: _isProcessing ? null : widget.onBack,
          ),
          title: const Text(
            'Оплата',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.page),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildServiceCostCard(),
                      const SizedBox(height: 16),
                      _buildDepositToggle(),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _isDeposit
                              ? 'Остаток ${Formatters.formatSum(widget.draft.sumPrice - widget.draft.depositSum)} оплатите в салоне.'
                              : 'Услуга будет полностью оплачена.',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Способ оплаты', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _buildPaymentMethods(),
                      const SizedBox(height: 16),
                      const Row(
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
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(Formatters.formatSum(d.sumPrice), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFF3DCE8)),
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
              side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFF3DCE8), width: 1.5),
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
