import 'package:flutter/material.dart';
import '../../core/models/salon_filter_params.dart';
import '../../core/services/salons_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/cards/app_card.dart';
import 'search_filter_modal.dart';

class ClientHomeScreen extends StatefulWidget {
  final VoidCallback onOpenMap;
  final Function(String salonName) onSalonTap;
  final VoidCallback? onOpenFavorites;

  const ClientHomeScreen({
    super.key,
    required this.onOpenMap,
    required this.onSalonTap,
    this.onOpenFavorites,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final _repository = SalonsRepository();
  final _searchController = TextEditingController();

  SalonFilterParams _filterParams = const SalonFilterParams();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterModal() {
    SearchFilterModal.show(
      context: context,
      currentParams: _filterParams,
      onApply: (updated) {
        setState(() {
          _filterParams = updated;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Получаем список салонов через репозиторий с учетом фильтров
    final filteredSalons = _repository.getSalons(_filterParams).where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.services.toLowerCase().contains(q) ||
          s.district.toLowerCase().contains(q);
    }).toList();

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
                if (_filterParams.hasActiveFilters) ...[
                  const SizedBox(height: 10),
                  _buildActiveFilterChips(),
                ],
                const SizedBox(height: 20),
                _buildPromoBanner(),
                const SizedBox(height: 24),
                _buildCategoriesList(),
                const SizedBox(height: 28),
                _buildPopularSalons(context, filteredSalons),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryTint,
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: const Icon(Icons.person, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Город',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  Row(
                    children: [
                      Text(
                        _filterParams.district ?? 'Ташкент (Все районы)',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.ink),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildTopIcon(
                Icons.favorite_border,
                onTap: widget.onOpenFavorites,
              ),
              const SizedBox(width: 10),
              Stack(
                children: [
                  _buildTopIcon(Icons.notifications_none_rounded),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

  Widget _buildTopIcon(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
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
      ),
    );
  }

  Widget _buildSearchBar() {
    final activeCount = _filterParams.activeFiltersCount;

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
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.muted, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: 'Услуга, салон или мастер',
                        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
                        border: InputBorder.none,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppColors.muted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openFilterModal,
            child: Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: activeCount > 0 ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.tune,
                    color: activeCount > 0 ? Colors.white : AppColors.ink,
                    size: 22,
                  ),
                ),
                if (activeCount > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_filterParams.district != null)
              _buildFilterChip('Район: ${_filterParams.district}', () {
                setState(() => _filterParams = _filterParams.copyWith(clearDistrict: true));
              }),
            if (_filterParams.onlyWomen)
              _buildFilterChip('Только для женщин', () {
                setState(() => _filterParams = _filterParams.copyWith(onlyWomen: false));
              }),
            if (_filterParams.homeVisit)
              _buildFilterChip('Выезд на дом', () {
                setState(() => _filterParams = _filterParams.copyWith(homeVisit: false));
              }),
            if (_filterParams.creditsOnly)
              _buildFilterChip('По кредитам', () {
                setState(() => _filterParams = _filterParams.copyWith(creditsOnly: false));
              }),
            if (_filterParams.availableToday)
              _buildFilterChip('Сегодня', () {
                setState(() => _filterParams = _filterParams.copyWith(availableToday: false));
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText)),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primaryText),
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
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -15,
              child: Opacity(
                opacity: 0.2,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ЕДИНЫЙ АБОНЕМЕНТ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Все салоны красоты\nв одной подписке',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'От 249 000 сум/мес за 60 кредитов',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList() {
    final categories = [
      {'name': 'Все', 'icon': Icons.apps},
      {'name': 'Маникюр', 'icon': Icons.brush},
      {'name': 'Стрижки', 'icon': Icons.content_cut},
      {'name': 'Брови', 'icon': Icons.remove_red_eye},
      {'name': 'Макияж', 'icon': Icons.face},
      {'name': 'Уход', 'icon': Icons.spa},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Text(
            'Категории',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 90,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = (_filterParams.serviceCategory ?? 'Все') == cat['name'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _filterParams = _filterParams.copyWith(
                      serviceCategory: cat['name'] as String,
                    );
                  });
                },
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        cat['icon'] as IconData,
                        color: isSelected ? Colors.white : AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat['name'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? AppColors.primary : AppColors.ink,
                      ),
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

  Widget _buildPopularSalons(BuildContext context, List<SalonModel> salons) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Салоны (${salons.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              GestureDetector(
                onTap: widget.onOpenMap,
                child: const Row(
                  children: [
                    Text(
                      'На карте',
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
        if (salons.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                'По выбранным фильтрам ничего не найдено.\nПопробуйте сбросить некоторые условия.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          )
        else
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
                  onTap: () => widget.onSalonTap(s.name),
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  child: SizedBox(
                    width: 220,
                    child: AppCard(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                        '${s.rating}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (s.onlyWomen)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('Женский', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.district} · ${s.distance}',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'от ${s.minCredits} кр.',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryText),
                              ),
                              AppStatusBadge(text: s.workingHours),
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
      {'name': 'Маникюр комплекс', 'price': '34 кр.', 'time': '60 мин'},
      {'name': 'Женская стрижка', 'price': '40 кр.', 'time': '45 мин'},
      {'name': 'Ламинирование ресниц', 'price': '28 кр.', 'time': '90 мин'},
      {'name': 'Окрашивание волос', 'price': '75 кр.', 'time': '120 мин'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Text(
            'Популярные услуги',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
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
                width: 135,
                child: AppCard(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 70,
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
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(s['time']!, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                      const Spacer(),
                      Text(
                        s['price']!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryText),
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
