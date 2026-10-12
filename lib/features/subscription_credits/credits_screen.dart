import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  final _appState = AppStateService();

  @override
  void initState() {
    super.initState();
    _appState.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _showFreezeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_appState.isFrozen ? 'Разморозить абонемент?' : 'Заморозить абонемент?'),
        content: Text(
          _appState.isFrozen
              ? 'Ваш абонемент станет активен сразу после подтверждения.'
              : 'По правилам ТЗ (K-08) абонемент можно заморозить на 7–30 дней 1 раз в 3 месяца. Срок действия кредитов приостанавливается.',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _appState.toggleFreeze();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_appState.isFrozen ? 'Абонемент успешно заморожен' : 'Абонемент разморожен'),
                ),
              );
            },
            child: Text(_appState.isFrozen ? 'Разморозить' : 'Заморозить', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _buyPackage(String name, int credits, int price) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Купить пакет «$name»', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Вам будет начислено +$credits кредитов на баланс.', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 20),
              AppGradientButton(
                text: 'Оплатить $price сум',
                onPressed: () {
                  _appState.addCredits(credits);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Пакет «$name» активирован! Начислено +$credits кр.')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packages = [
      {'name': 'Lite', 'credits': 60, 'price': 249000, 'costPer': '4 150 сум/кр.'},
      {'name': 'Standart', 'credits': 120, 'price': 449000, 'costPer': '3 742 сум/кр.', 'popular': true},
      {'name': 'Premium', 'credits': 250, 'price': 849000, 'costPer': '3 396 сум/кр.'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Кредиты и Абонемент', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Карточка баланса
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE8F5), Color(0xFFFDD5EC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                              child: const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Текущий тариф', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                                Text(_appState.subscriptionPlan, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ],
                        ),
                        if (_appState.isFrozen)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
                            child: const Text('Заморожен', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Доступно кредитов', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                            const SizedBox(height: 2),
                            Text(
                              '${_appState.clientCredits} кр.',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary),
                            ),
                          ],
                        ),
                        AppPillButton(
                          text: _appState.isFrozen ? 'Разморозить' : 'Заморозить',
                          backgroundColor: Colors.white,
                          textColor: AppColors.ink,
                          onPressed: _showFreezeDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Действует до ${_appState.subscriptionExpiry}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Text('Купить пакет кредитов (по ТЗ)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Кредиты действуют во всех салонах-партнерах Go\'zallik', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 16),

              ...packages.map((pkg) {
                final isPopular = pkg['popular'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    border: isPopular ? Border.all(color: AppColors.primary, width: 2) : null,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.monetization_on_outlined, color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(pkg['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  if (isPopular) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                                      child: const Text('ХИТ', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              Text('${pkg["credits"]} кредитов / месяц', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              Text(pkg['costPer'] as String, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${pkg["price"]} сум', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            AppPillButton(
                              text: 'Купить',
                              backgroundColor: AppColors.primary,
                              textColor: Colors.white,
                              height: 30,
                              onPressed: () => _buyPackage(pkg['name'] as String, pkg['credits'] as int, pkg['price'] as int),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
