import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/cards/app_card.dart';

class PaymentScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onPaymentSuccess;

  const PaymentScreen({
    super.key,
    required this.onBack,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isDeposit = true;
  int _selectedProvider = 0; // 0: Click, 1: Payme, 2: Uzum, 3: Карта

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: widget.onBack,
        ),
        title: const Text('Оплата', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
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
                    const Center(
                      child: Text(
                        'Остаток 120 000 сум оплатите в салоне.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
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
                            'Данные карты мы не храним, платёж проходит через провайдера.',
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
    );
  }

  Widget _buildServiceCostCard() {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Услуга', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              SizedBox(height: 4),
              Text('Nur Beauty · маникюр классический', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          Text(
            '150 000 сум',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositToggle() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _isDeposit = true),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: _isDeposit ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Center(
                child: Text(
                  'Депозит 30 000 сум',
                  style: TextStyle(
                    color: _isDeposit ? Colors.white : AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _isDeposit = false),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: !_isDeposit ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Center(
                child: Text(
                  'Полностью 150 000',
                  style: TextStyle(
                    color: !_isDeposit ? Colors.white : AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethods() {
    final providers = [
      {'name': 'Click', 'icon': Icons.radio_button_checked, 'logoColor': const Color(0xFF007AFF)},
      {'name': 'Payme', 'icon': Icons.account_balance_wallet, 'logoColor': const Color(0xFF00C7B5)},
      {'name': 'Uzum', 'icon': Icons.shopping_bag, 'logoColor': const Color(0xFF7000FF)},
      {'name': 'Сохранённая карта\n···· 4417', 'icon': Icons.credit_card, 'logoColor': const Color(0xFFFF5A00)},
    ];

    return Column(
      children: List.generate(providers.length, (index) {
        final p = providers[index];
        final isSelected = _selectedProvider == index;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => setState(() => _selectedProvider = index),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFF3DCE8),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? AppColors.primary : AppColors.muted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p['name'] as String,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (p['logoColor'] as Color).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(p['icon'] as IconData, size: 18, color: p['logoColor'] as Color),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomPayButton() {
    final amount = _isDeposit ? '30 000 сум' : '150 000 сум';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AppGradientButton(
          text: 'Оплатить $amount',
          onPressed: widget.onPaymentSuccess,
        ),
      ),
    );
  }
}
