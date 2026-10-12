import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons/app_pill_button.dart';
import '../../../core/widgets/cards/app_card.dart';

class MasterDashboardScreen extends StatelessWidget {
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenEarnings;
  final VoidCallback onScanQr;

  const MasterDashboardScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenEarnings,
    required this.onScanQr,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                _buildMasterHeader(),
                const SizedBox(height: 16),
                _buildMetricsRow(),
                const SizedBox(height: 20),
                _buildNextClientCard(),
                const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildTodayAppointments(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.ink, size: 24),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.ink, size: 24),
            onPressed: onScanQr,
          ),
        ],
      ),
    );
  }

  Widget _buildMasterHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: AppColors.primaryTint,
                ),
                child: const Icon(Icons.person, color: AppColors.primary, size: 44),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Sabina Nur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(width: 4),
                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                ],
              ),
              SizedBox(height: 2),
              Text('Мастер · Продавец', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              SizedBox(height: 2),
              Text('Nur Beauty >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Сегодня 8 записей', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    final metrics = [
      {'val': '8', 'label': 'Записи\nсегодня', 'icon': Icons.calendar_today_outlined},
      {'val': '24', 'label': 'Клиенты\nв этом месяце', 'icon': Icons.people_outline},
      {'val': '5', 'label': 'Заказы\nмагазин', 'icon': Icons.shopping_bag_outlined},
      {'val': '2 450 000', 'label': 'Выручка\nсегодня (сум)', 'icon': Icons.bar_chart_outlined, 'action': onOpenEarnings},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: metrics.map((m) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: m['action'] as VoidCallback?,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Column(
                    children: [
                      Icon(m['icon'] as IconData, size: 18, color: AppColors.primary),
                      const SizedBox(height: 4),
                      Text(m['val'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(m['label'] as String, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 8, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNextClientCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ближайший клиент', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFFFECEF), borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Через 20 мин', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primaryTint,
                      child: Icon(Icons.person, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Алина Каримова', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          Text('Маникюр классический', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 12, color: AppColors.muted),
                              SizedBox(width: 4),
                              Text('10:00 – 11:30', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              SizedBox(width: 8),
                              Icon(Icons.location_on_outlined, size: 12, color: AppColors.muted),
                              SizedBox(width: 2),
                              Text('Nur Beauty', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppPillButton(
                        text: 'Принять',
                        backgroundColor: AppColors.primary,
                        textColor: Colors.white,
                        height: 38,
                        onPressed: onScanQr,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppPillButton(
                        text: 'Перенести',
                        backgroundColor: AppColors.primaryTint,
                        textColor: AppColors.primaryText,
                        height: 38,
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'title': 'Расписание', 'sub': 'Управлять записями', 'icon': Icons.calendar_month, 'tap': onOpenSchedule},
      {'title': 'Открыть время', 'sub': 'Добавить свободное время', 'icon': Icons.access_time, 'tap': onOpenSchedule},
      {'title': 'Доход', 'sub': 'История выплат и баланс', 'icon': Icons.payments_outlined, 'tap': onOpenEarnings},
      {'title': 'Услуги', 'sub': 'Управлять услугами', 'icon': Icons.grid_view, 'tap': () {}},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Быстрые действия', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: actions.map((a) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: a['tap'] as VoidCallback?,
                    borderRadius: BorderRadius.circular(16),
                    child: AppCard(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(a['icon'] as IconData, size: 20, color: AppColors.primary),
                          const SizedBox(height: 6),
                          Text(a['title'] as String, maxLines: 1, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          Text(a['sub'] as String, maxLines: 2, style: const TextStyle(fontSize: 8, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayAppointments() {
    final list = [
      {'time': '10:00\n11:30', 'client': 'Алина Каримова', 'service': 'Маникюр классический', 'status': 'Принять'},
      {'time': '12:00\n13:00', 'client': 'Мадина Турсунова', 'service': 'Окрашивание бровей', 'status': 'Принять'},
      {'time': '14:00\n15:30', 'client': 'Санобар Алиева', 'service': 'Стрижка женская', 'status': 'Отменить'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Сегодняшние записи', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('Все записи >', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
            ],
          ),
          const SizedBox(height: 10),
          ...list.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryTint,
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Text(item['time']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['client']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(item['service']!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    AppPillButton(
                      text: item['status']!,
                      backgroundColor: item['status'] == 'Принять' ? AppColors.primary : AppColors.primaryTint,
                      textColor: item['status'] == 'Принять' ? Colors.white : AppColors.primaryText,
                      onPressed: onScanQr,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
