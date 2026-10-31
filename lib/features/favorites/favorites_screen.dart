import 'package:flutter/material.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/masters_repository.dart';
import '../../core/services/salons_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';

/// Экран «Избранное» (ТЗ M-15: Избранные салоны и мастера)
class FavoritesScreen extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<String> onSalonTap;
  final ValueChanged<String> onMasterTap;
  final ValueChanged<String> onBookSalon;

  const FavoritesScreen({
    super.key,
    required this.onBack,
    required this.onSalonTap,
    required this.onMasterTap,
    required this.onBookSalon,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _appState = AppStateService();
  final _salonsRepo = SalonsRepository();
  final _mastersRepo = MastersRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    // Получаем избранные салоны и мастера
    final allSalons = _salonsRepo.getSalons();
    final favoriteSalons = allSalons
        .where((s) => _appState.isSalonFavorite(s.name))
        .toList();

    final allMasters = _mastersRepo.getMasters();
    final favoriteMasters = allMasters
        .where((m) => _appState.isMasterFavorite(m.name))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Избранное',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: AppColors.surface,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.ink, size: 20),
              onPressed: widget.onBack,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            child: Container(
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
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: 'Салоны (${favoriteSalons.length})'),
                  Tab(text: 'Мастера (${favoriteMasters.length})'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.page,
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildSalonsList(favoriteSalons),
            _buildMastersList(favoriteMasters),
          ],
        ),
      ),
    );
  }

  Widget _buildSalonsList(List<SalonModel> salons) {
    if (salons.isEmpty) {
      return _buildEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Нет избранных салонов',
        subtitle:
            'Нажимайте на сердечко на странице салона, чтобы добавить его сюда.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: salons.length,
      itemBuilder: (context, index) {
        final s = salons[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: () => widget.onSalonTap(s.name),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD1DC), Color(0xFFFFB6C1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${s.district} · ${s.address}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFFFA800), size: 16),
                                const SizedBox(width: 2),
                                Text(
                                  '${s.rating}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${s.reviewsCount})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'от ${s.minCredits} кр.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _appState.toggleSalonFavorite(s.name);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.ink,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              content: Text(
                                  '«${s.name}» удален из избранного'),
                              action: SnackBarAction(
                                label: 'Отменить',
                                textColor: AppColors.primaryBright,
                                onPressed: () =>
                                    _appState.toggleSalonFavorite(s.name),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.favorite,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (s.onlyWomen)
                        const AppStatusBadge(
                          text: 'Faqat ayollar',
                          backgroundColor: Color(0xFFFFECEF),
                          textColor: AppColors.primary,
                        ),
                      if (s.homeVisit)
                        AppStatusBadge(
                          text: 'Uyga chiqish',
                          backgroundColor: Colors.blue.shade50,
                          textColor: Colors.blue.shade800,
                        ),
                      if (s.creditsAccepted)
                        const AppStatusBadge(
                          text: 'Kredit bilan',
                          backgroundColor: Color(0xFFE8F5E9),
                          textColor: Color(0xFF2E7D32),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: () => widget.onBookSalon(s.name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Записаться в салон',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMastersList(List<MasterProfileModel> masters) {
    if (masters.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_outline,
        title: 'Нет избранных мастеров',
        subtitle:
            'Добавляйте лучших мастеров в избранное, чтобы быстро записываться к ним.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: masters.length,
      itemBuilder: (context, index) {
        final m = masters[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: () => widget.onMasterTap(m.name),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE4178C), Color(0xFF8F1258)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.person,
                                  size: 30, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1AAA4C),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${m.specialty} · ${m.salonName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFFFA800), size: 16),
                                const SizedBox(width: 2),
                                Text(
                                  '${m.rating}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${m.reviewsCount} отзывов)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Стаж ${m.experienceYears} лет',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _appState.toggleMasterFavorite(m.name);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.ink,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              content:
                                  Text('Мастер ${m.name} удалена из избранного'),
                              action: SnackBarAction(
                                label: 'Отменить',
                                textColor: AppColors.primaryBright,
                                onPressed: () =>
                                    _appState.toggleMasterFavorite(m.name),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.favorite,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton(
                      onPressed: () => widget.onMasterTap(m.name),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Перейти в профиль мастера',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 54, color: AppColors.muted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            AppPillButton(
              text: 'В каталог',
              backgroundColor: AppColors.primary,
              textColor: Colors.white,
              height: 38,
              onPressed: widget.onBack,
            ),
          ],
        ),
      ),
    );
  }
}
