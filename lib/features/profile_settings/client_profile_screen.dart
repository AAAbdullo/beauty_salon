import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/cards/app_card.dart';

class ClientProfileScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenQr;
  final VoidCallback? onOpenFavorites;

  const ClientProfileScreen({
    super.key,
    required this.onOpenSettings,
    required this.onOpenQr,
    this.onOpenFavorites,
  });

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
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
                _buildUserCard(),
                const SizedBox(height: 16),
                _buildStatsRow(),
                const SizedBox(height: 16),
                _buildSubscriptionCard(),
                const SizedBox(height: 20),
                _buildQuickActionsGrid(),
                const SizedBox(height: 24),
                _buildRecentBookings(),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.hexagon_outlined, color: AppColors.ink, size: 24),
            onPressed: () {},
          ),
          Row(
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
                onPressed: widget.onOpenQr,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: AppColors.primaryTint,
                ),
                child: const Icon(Icons.person, size: 45, color: AppColors.primary),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_appState.clientName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_appState.clientPhone, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.workspace_premium, size: 14, color: AppColors.primaryText),
                    SizedBox(width: 4),
                    Text('Постоянный клиент', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Row(
              children: [
                Text('Редактировать', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      {'val': '${_appState.bookings.length}', 'label': 'Записей', 'icon': Icons.calendar_today_outlined},
      {'val': '${_appState.totalFavoritesCount}', 'label': 'Любимых', 'icon': Icons.favorite_border, 'action': widget.onOpenFavorites},
      {'val': '1 900', 'label': 'Бонусных баллов', 'icon': Icons.star_border},
      {'val': '${_appState.clientCredits}', 'label': 'Кредитов', 'icon': Icons.account_balance_wallet_outlined},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: stats.map((s) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: s['action'] as VoidCallback?,
                borderRadius: BorderRadius.circular(16),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Icon(s['icon'] as IconData, size: 18, color: AppColors.primary),
                      const SizedBox(height: 6),
                      Text(s['val'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(s['label'] as String, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
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

  Widget _buildSubscriptionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE8F5), Color(0xFFFDD5EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  child: const Icon(Icons.workspace_premium, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ваш тариф', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    Text('Премиум', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 8),
            const Text('До 12 ноября 2024', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: const LinearProgressIndicator(
                value: 14 / 20,
                minHeight: 6,
                backgroundColor: Colors.white70,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Использовано 14 из 20 кредитов', style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      {'title': 'Мои записи', 'icon': Icons.calendar_month_outlined},
      {'title': 'Оплата и кредиты', 'icon': Icons.credit_card_outlined},
      {'title': 'Избранное', 'icon': Icons.favorite_border, 'action': widget.onOpenFavorites},
      {'title': 'Отзывы', 'icon': Icons.chat_bubble_outline},
      {'title': 'Адреса салонов', 'icon': Icons.location_on_outlined},
      {'title': 'Бонусы и промокоды', 'icon': Icons.card_giftcard_outlined},
      {'title': 'Поддержка', 'icon': Icons.help_outline},
      {'title': 'Настройки', 'icon': Icons.settings_outlined, 'action': widget.onOpenSettings},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: actions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.9,
        ),
        itemBuilder: (context, index) {
          final item = actions[index];
          return InkWell(
            onTap: item['action'] as VoidCallback?,
            borderRadius: BorderRadius.circular(16),
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item['icon'] as IconData, size: 22, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    item['title'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentBookings() {
    final bookings = [
      {'title': 'Маникюр классический', 'salon': 'Nur Beauty · Алена', 'date': '12 окт 2024 · 16:30'},
      {'title': 'Окрашивание бровей', 'salon': 'Lola Studio · Сабина', 'date': '5 окт 2024 · 14:00'},
      {'title': 'Стрижка женская', 'salon': 'Mira Hair · Дилноза', 'date': '28 сен 2024 · 10:00'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Недавние записи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('Все записи >', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
            ],
          ),
          const SizedBox(height: 12),
          ...bookings.map((b) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.check_circle_outline, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['title']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          Text(b['salon']!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          Text(b['date']!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const AppStatusBadge(text: 'Завершено'),
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
