import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/badges/app_status_badge.dart';
import '../../../core/widgets/cards/app_card.dart';

class MasterEarningsScreen extends StatelessWidget {
  final VoidCallback onBack;

  const MasterEarningsScreen({
    super.key,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          onPressed: onBack,
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Мастер · Nur Beauty', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            Text('Мой доход', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3DCE8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primary),
                SizedBox(width: 6),
                Text('Октябрь 2024', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthToggle(),
              const SizedBox(height: 16),
              _buildIncomeSummaryCard(),
              const SizedBox(height: 16),
              _buildMetricsGrid(),
              const SizedBox(height: 24),
              _buildRecentVisitsHeader(),
              const SizedBox(height: 12),
              _buildRecentVisitsList(),
              const SizedBox(height: 20),
              _buildBottomActionCards(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthToggle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Октябрь', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Сентябрь', style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildIncomeSummaryCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Начислено за месяц', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text('+32%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    Icon(Icons.arrow_upward, size: 12, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '1 240 000 сум',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Расчёт в конце месяца: процент или фиксированная ставка, как задал салон.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final metrics = [
      {'title': 'Выполнено\nвизитов', 'val': '21', 'icon': Icons.calendar_today_outlined},
      {'title': 'Средний чек', 'val': '59 000 сум', 'icon': Icons.payments_outlined},
      {'title': 'Комиссия\nсалона', 'val': '10%', 'icon': Icons.percent},
      {'title': 'В выплате\n(примерно)', 'val': '1 116 000 сум', 'icon': Icons.account_balance_wallet_outlined},
    ];

    return Row(
      children: metrics.map((m) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(m['icon'] as IconData, size: 18, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(m['title'] as String, maxLines: 2, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Text(m['val'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentVisitsHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Последние визиты', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Row(
          children: [
            Text('Все визиты', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
            Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryText),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentVisitsList() {
    final visits = [
      {'title': 'Маникюр классический', 'sub': 'Сегодня, 10:00 · Алина Р.', 'sum': '+60 000 сум'},
      {'title': 'Маникюр с покрытием', 'sub': '9 окт, 14:00 · Дилноза К.', 'sum': '+72 000 сум'},
      {'title': 'Маникюр классический', 'sub': '9 окт, 11:00 · Сабина М.', 'sum': '+60 000 сум'},
      {'title': 'Педикюр', 'sub': '8 окт, 16:30 · Марьям Т.', 'sum': '+90 000 сум'},
      {'title': 'Окрашивание бровей', 'sub': '7 окт, 12:00 · Нигина С.', 'sum': '+50 000 сум'},
    ];

    return Column(
      children: visits.map((v) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.spa_outlined, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v['title']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(v['sub']!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
                const AppStatusBadge(text: 'Услуга'),
                const SizedBox(width: 10),
                Text(
                  v['sum']!,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomActionCards() {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                Icon(Icons.pie_chart_outline, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Подробная статистика', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      Text('Графики, услуги, клиенты', style: TextStyle(fontSize: 9, color: AppColors.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                Icon(Icons.history, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('История выплат', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      Text('Переводы и комиссии', style: TextStyle(fontSize: 9, color: AppColors.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
