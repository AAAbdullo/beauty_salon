import 'package:flutter/material.dart';
import '../../core/data/app_scope.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/masters_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../../core/widgets/sheets/app_sheet.dart';
import '../../core/widgets/states/async_screen.dart';
import '../../core/widgets/states/not_found_screen.dart';
import 'photo_viewer.dart';

/// Экран отдельного мастера (ТЗ M-07: Usta sahifasi)
/// Портфолио, услуги, отзывы, рейтинг, прямая запись
class MasterProfileScreen extends StatelessWidget {
  final String masterId;
  final VoidCallback onBack;

  /// Запись к мастеру; [service] — если клиент выбрал конкретную услугу
  final void Function(MasterProfileModel master, MasterServiceItem? service) onBookMaster;

  /// Открыть салон мастера (передаётся id салона)
  final ValueChanged<String>? onOpenSalon;

  const MasterProfileScreen({
    super.key,
    required this.masterId,
    required this.onBack,
    required this.onBookMaster,
    this.onOpenSalon,
  });

  @override
  Widget build(BuildContext context) {
    return AsyncScreen<MasterProfileModel?>(
      title: 'Мастер',
      onBack: onBack,
      reloadKey: masterId,
      load: () => AppScope.read(context).catalog.getMaster(masterId),
      builder: (context, master) {
        if (master == null) {
          return NotFoundScreen(
            title: 'Мастер',
            message: 'Мастер не найден. Возможно, он больше не работает в салоне.',
            onBack: onBack,
          );
        }
        return _MasterProfileView(
          key: ValueKey(master.id),
          master: master,
          onBack: onBack,
          onBookMaster: onBookMaster,
          onOpenSalon: onOpenSalon,
        );
      },
    );
  }
}

class _MasterProfileView extends StatefulWidget {
  final MasterProfileModel master;
  final VoidCallback onBack;
  final void Function(MasterProfileModel master, MasterServiceItem? service) onBookMaster;
  final ValueChanged<String>? onOpenSalon;

  const _MasterProfileView({
    super.key,
    required this.master,
    required this.onBack,
    required this.onBookMaster,
    this.onOpenSalon,
  });

  @override
  State<_MasterProfileView> createState() => _MasterProfileViewState();
}

class _MasterProfileViewState extends State<_MasterProfileView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MasterProfileModel _master;
  final _appState = AppStateService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _master = widget.master;
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
      bottomNavigationBar: _buildBottomBookingBar(),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  const SizedBox(height: 16),
                  _buildExperienceBadges(),
                  const SizedBox(height: 16),
                  _buildAboutSection(),
                  const SizedBox(height: 20),
                  _buildTabBar(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildTabContent(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primary,
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
      actions: [
        CircleAvatar(
          backgroundColor: AppColors.surface,
          child: IconButton(
            icon: Icon(
              _appState.isMasterFavorite(_master.id) ? Icons.favorite : Icons.favorite_border,
              color: AppColors.primary,
              size: 20,
            ),
            onPressed: () {
              final isFav = _appState.isMasterFavorite(_master.id);
              _appState.toggleMasterFavorite(_master.id);
              showAppSnack(
                context,
                isFav ? 'Удалено из Избранного: ${_master.name}' : 'Добавлено в Избранное: ${_master.name}',
              );
            },
          ),
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE4178C), Color(0xFF8F1258)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          _master.avatarAsset,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Icon(Icons.person, size: 55, color: AppColors.primary)),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _master.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _master.specialty,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppColors.primary, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_master.rating}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryText),
                  ),
                  Text(' (${_master.reviewsCount})', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: widget.onOpenSalon == null ? null : () => widget.onOpenSalon!(_master.salonId),
          child: Row(
            children: [
              const Icon(Icons.storefront, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                'Салон: ${_master.salonName}',
                style: TextStyle(
                  color: widget.onOpenSalon == null ? AppColors.muted : AppColors.primaryText,
                  fontSize: 13,
                  fontWeight: widget.onOpenSalon == null ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              if (widget.onOpenSalon != null) const Icon(Icons.chevron_right, size: 16, color: AppColors.primaryText),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceBadges() {
    return Row(
      children: [
        _buildBadgeItem('Опыт работы', Formatters.years(_master.experienceYears), Icons.workspace_premium),
        const SizedBox(width: 10),
        _buildBadgeItem('Отзывы', '${_master.reviewsCount}', Icons.forum_outlined),
        const SizedBox(width: 10),
        _buildBadgeItem('Статус', 'На смене', Icons.check_circle_outline, isGreen: true),
      ],
    );
  }

  Widget _buildBadgeItem(String title, String val, IconData icon, {bool isGreen = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isGreen ? AppColors.successBg : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isGreen ? AppColors.successText : AppColors.primary),
            const SizedBox(height: 4),
            Text(
              val,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isGreen ? AppColors.successText : AppColors.ink,
              ),
            ),
            Text(title, style: TextStyle(fontSize: 10, color: isGreen ? AppColors.successText : AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('О мастере', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(_master.about, style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        tabs: const [
          Tab(text: 'Услуги'),
          Tab(text: 'Портфолио'),
          Tab(text: 'Отзывы'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      sliver: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          switch (_tabController.index) {
            case 0:
              return _buildServicesList();
            case 1:
              return _buildPortfolioGrid();
            case 2:
            default:
              return _buildReviewsList();
          }
        },
      ),
    );
  }

  // 1. Вкладка Услуги мастера
  Widget _buildServicesList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final s = _master.services[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => widget.onBookMaster(_master, s),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.spa, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(s.duration, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${s.creditsPrice} кр.',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryText),
                    ),
                    Text(
                      Formatters.formatSum(s.sumPrice),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 4),
                    AppPillButton(text: 'Записаться', onPressed: () => widget.onBookMaster(_master, s)),
                  ],
                ),
              ],
            ),
          ),
        );
      }, childCount: _master.services.length),
    );
  }

  // 2. Вкладка Портфолио (ТЗ M-07)
  Widget _buildPortfolioGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final imgAsset = _master.portfolioImages[index];
        return GestureDetector(
          onTap: () => PhotoViewer.show(context, photos: _master.portfolioImages, initialIndex: index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.pink.shade50,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    imgAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.photo_camera_back_outlined, size: 40, color: AppColors.primary)),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'Работа #${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }, childCount: _master.portfolioImages.length),
    );
  }

  // 3. Вкладка Отзывы
  Widget _buildReviewsList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final r = _master.reviews[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.authorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.gold, size: 14),
                        const SizedBox(width: 2),
                        Text('${r.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
                Text(r.date, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                const SizedBox(height: 6),
                Text(r.comment, style: const TextStyle(fontSize: 12, color: AppColors.ink, height: 1.3)),
              ],
            ),
          ),
        );
      }, childCount: _master.reviews.length),
    );
  }

  Widget _buildBottomBookingBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: AppGradientButton(text: 'Записаться к мастеру', onPressed: () => widget.onBookMaster(_master, null)),
      ),
    );
  }
}
