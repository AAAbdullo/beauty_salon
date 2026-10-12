import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/cards/app_card.dart';

class ClientHomeScreen extends StatelessWidget {
  final VoidCallback onOpenMap;
  final Function(String salonName) onSalonTap;

  const ClientHomeScreen({
    super.key,
    required this.onOpenMap,
    required this.onSalonTap,
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
                _buildHeader(),
                const SizedBox(height: 16),
                _buildSearchBar(),
                const SizedBox(height: 20),
                _buildPromoBanner(),
                const SizedBox(height: 24),
                _buildCategoriesList(),
                const SizedBox(height: 28),
                _buildPopularSalons(context),
                const SizedBox(height: 28),
                _buildPopularServices(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ташкент',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: AppColors.ink, size: 20),
            ],
          ),
          Row(
            children: [
              _buildRoundIcon(Icons.favorite_border),
              const SizedBox(width: 10),
              Stack(
                children: [
                  _buildRoundIcon(Icons.notifications_none_rounded),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoundIcon(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.ink, size: 22),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: AppColors.muted, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Услуга, салон или мастер',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.tune, color: AppColors.ink, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE8F5), Color(0xFFFDD5EC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'ВАША КРАСОТА\nВ НАДЁЖНЫХ РУКАХ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Лучшие салоны\nрядом с вами',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: onOpenMap,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Найти салон',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 110,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.pink.shade100,
              ),
              child: const Center(
                child: Icon(Icons.face_retouching_natural, size: 64, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList() {
    final categories = [
      {'name': 'Макияж', 'icon': Icons.brush_outlined},
      {'name': 'Волосы', 'icon': Icons.content_cut_outlined},
      {'name': 'Маникюр', 'icon': Icons.front_hand_outlined},
      {'name': 'Уход и гигиена', 'icon': Icons.spa_outlined},
      {'name': 'Косметология', 'icon': Icons.sanitizer_outlined},
      {'name': 'Ещё', 'icon': Icons.grid_view_outlined},
    ];

    return SizedBox(
      height: 94,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Column(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(cat['icon'] as IconData, color: AppColors.primary, size: 26),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 60,
                child: Text(
                  cat['name'] as String,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPopularSalons(BuildContext context) {
    final salons = [
      {
        'name': 'Nur Beauty',
        'tags': 'Маникюр · Педикюр',
        'dist': '0,6 км · Ташкент',
        'time': 'Сегодня 16:30',
        'price': 'от 27 000 сум',
        'rating': '4.8',
      },
      {
        'name': 'Lola Studio',
        'tags': 'Окрашивание · Стрижки',
        'dist': '1,2 км · Ташкент',
        'time': 'Сегодня 18:00',
        'price': 'от 26 000 сум',
        'rating': '4.7',
      },
      {
        'name': 'Mira Hair',
        'tags': 'Стрижки · Укладка',
        'dist': '1,9 км · Ташкент',
        'time': 'Завтра 10:00',
        'price': 'от 24 000 сум',
        'rating': '4.9',
      },
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Популярные салоны',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              GestureDetector(
                onTap: onOpenMap,
                child: const Row(
                  children: [
                    Text(
                      'Смотреть все',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 250,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            scrollDirection: Axis.horizontal,
            itemCount: salons.length,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final s = salons[index];
              return InkWell(
                onTap: () => onSalonTap(s['name']!),
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                child: SizedBox(
                  width: 210,
                  child: AppCard(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Превью с бейджем рейтинга
                        Stack(
                          children: [
                            Container(
                              height: 105,
                              decoration: BoxDecoration(
                                color: Colors.pink.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Icon(Icons.storefront, size: 40, color: AppColors.primary),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 3),
                                    Text(
                                      s['rating']!,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s['name']!,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          s['tags']!,
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                        Text(
                          s['dist']!,
                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppStatusBadge(text: s['time']!),
                            Text(
                              s['price']!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ],
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

  Widget _buildPopularServices() {
    final services = [
      {'name': 'Наращивание ресниц', 'price': 'от 120 000 сум'},
      {'name': 'Маникюр гель-лак', 'price': 'от 80 000 сум'},
      {'name': 'Женская стрижка', 'price': 'от 90 000 сум'},
      {'name': 'Чистка лица', 'price': 'от 150 000 сум'},
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Популярные услуги',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const Row(
                children: [
                  Text(
                    'Смотреть все',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 160,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            scrollDirection: Axis.horizontal,
            itemCount: services.length,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final s = services[index];
              return SizedBox(
                width: 130,
                child: AppCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 75,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 28),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s['name']!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        s['price']!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
