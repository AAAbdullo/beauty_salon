import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/salons_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/cards/app_card.dart';
import 'master_profile_screen.dart';

class SalonDetailScreen extends StatefulWidget {
  final String salonName;
  final VoidCallback onBack;
  final VoidCallback onBookNow;
  final Function(String masterName)? onMasterTap;

  const SalonDetailScreen({
    super.key,
    required this.salonName,
    required this.onBack,
    required this.onBookNow,
    this.onMasterTap,
  });

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _appState = AppStateService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _appState.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onStateChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderInfo(),
                      const SizedBox(height: 16),
                      _buildAmenitiesRow(),
                      const SizedBox(height: 20),
                      _buildTabs(),
                      const SizedBox(height: 20),
                      _buildPopularServices(),
                      const SizedBox(height: 24),
                      _buildMastersSection(),
                      const SizedBox(height: 24),
                      _buildSalonPhotos(),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final allSalons = SalonsRepository().getSalons(null);
    final salon = allSalons.firstWhere(
      (s) => s.name == widget.salonName,
      orElse: () => allSalons.first,
    );

    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: AppColors.surface,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.ink, size: 20),
            onPressed: widget.onBack,
          ),
        ),
      ),
      actions: [
        CircleAvatar(
          backgroundColor: AppColors.surface,
          child: IconButton(
            icon: const Icon(
              Icons.share_outlined,
              color: AppColors.ink,
              size: 20,
            ),
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: AppColors.surface,
          child: IconButton(
            icon: Icon(
              _appState.isSalonFavorite(widget.salonName)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: AppColors.primary,
              size: 20,
            ),
            onPressed: () {
              final isFav = _appState.isSalonFavorite(widget.salonName);
              _appState.toggleSalonFavorite(widget.salonName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.ink,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: Text(
                    !isFav
                        ? 'Салон «${widget.salonName}» добавлен в Избранное'
                        : 'Салон «${widget.salonName}» удален из Избранного',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              salon.imageAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD1DC), Color(0xFFFFB6C1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.storefront, size: 80, color: Colors.white70),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '1/12',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  widget.salonName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.verified, color: AppColors.primary, size: 20),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.monetization_on_outlined,
                    size: 14,
                    color: AppColors.gold,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '86 кредитов',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8A5D00),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Маникюр · Педикюр · Брови',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.star, size: 15, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              '4.8 (126 отзывов)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            Spacer(),
            AppStatusBadge(text: 'Открыто до 21:00'),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: AppColors.muted,
            ),
            const SizedBox(width: 4),
            const Text(
              '0,6 км · Ташкент',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'На карте >',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmenitiesRow() {
    final amenities = [
      {'icon': Icons.diamond_outlined, 'title': 'Мастера'},
      {'icon': Icons.verified_user_outlined, 'title': 'Чистота'},
      {'icon': Icons.percent, 'title': 'Скидки'},
      {'icon': Icons.credit_card, 'title': 'Оплата картой'},
      {'icon': Icons.local_parking, 'title': 'Парковка'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: amenities.map((a) {
        return Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(a['icon'] as IconData, size: 20, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                a['title'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Услуги'),
          Tab(text: 'Мастера'),
          Tab(text: 'Отзывы'),
          Tab(text: 'О салоне'),
        ],
      ),
    );
  }

  Widget _buildPopularServices() {
    final services = [
      {
        'name': 'Маникюр классический',
        'time': '60 мин',
        'price': '150 000 сум',
      },
      {
        'name': 'Педикюр классический',
        'time': '90 мин',
        'price': '200 000 сум',
      },
      {'name': 'Окрашивание бровей', 'time': '40 мин', 'price': '80 000 сум'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Популярные услуги',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: services.length,
            separatorBuilder: (_, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final s = services[index];
              return SizedBox(
                width: 145,
                child: AppCard(
                  padding: const EdgeInsets.all(10),
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
                          child: Icon(
                            Icons.spa,
                            color: AppColors.primary,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s['name']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        s['time']!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              s['price']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryText,
                              ),
                            ),
                          ),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
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

  Widget _buildMastersSection() {
    final masters = [
      {'name': 'Алена', 'role': 'Маникюр · Педикюр', 'rating': '4.9', 'avatar': 'assets/images/masters/master_alena.jpg'},
      {'name': 'Сабина', 'role': 'Брови · Ресницы', 'rating': '4.8', 'avatar': 'assets/images/masters/master_sabina.jpg'},
      {'name': 'Дилноза', 'role': 'Стрижки · Укладка', 'rating': '4.7', 'avatar': 'assets/images/masters/master_dilnoza.jpg'},
      {'name': 'Мадина', 'role': 'Косметология', 'rating': '4.9', 'avatar': 'assets/images/masters/master_madina.jpg'},
      {'name': 'Тимур', 'role': 'Барбер · Стиль', 'rating': '4.8', 'avatar': 'assets/images/masters/master_timur.jpg'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Мастера салона',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: masters.length,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final m = masters[index];
              return InkWell(
                onTap: () {
                  if (widget.onMasterTap != null) {
                    widget.onMasterTap!(m['name']!);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MasterProfileScreen(
                          masterName: m['name']!,
                          onBack: () => Navigator.pop(context),
                          onBookMaster: () {
                            Navigator.pop(context);
                            widget.onBookNow();
                          },
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              m['avatar']!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppColors.primaryTint,
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m['name']!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      m['role']!,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.muted,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 10,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          m['rating']!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

  Widget _buildSalonPhotos() {
    final photos = [
      'assets/images/salons/salon_nur_beauty.jpg',
      'assets/images/salons/salon_mira_hair.jpg',
      'assets/images/salons/salon_lola_studio.jpg',
      'assets/images/portfolio/portfolio_manicure_1.jpg',
      'assets/images/portfolio/portfolio_hair_1.jpg',
      'assets/images/portfolio/portfolio_brows_1.jpg',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Фото салона и работ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 85,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  photos[index],
                  width: 120,
                  height: 85,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 120,
                    height: 85,
                    color: Colors.pink.shade50,
                    child: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.phone, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppGradientButton(
                  text: 'Записаться',
                  onPressed: widget.onBookNow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
