import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/models/salon_filter_params.dart';
import '../../core/data/app_dependencies.dart';
import '../../core/data/app_scope.dart';
import '../../core/data/repository_exception.dart';
import '../../core/services/masters_repository.dart';
import '../../core/services/salons_repository.dart';
import '../../core/widgets/sheets/app_sheet.dart';
import '../../core/widgets/states/async_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/avatars/avatar_image.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/cards/app_card.dart';
import 'search_filter_modal.dart';
import '../../core/l10n/app_locale.dart';

class ClientHomeScreen extends StatefulWidget {
  final VoidCallback onOpenMap;
  final ValueChanged<String> onSalonTap;
  final ValueChanged<String> onMasterTap;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenCredits;
  final VoidCallback onOpenProfile;

  const ClientHomeScreen({
    super.key,
    required this.onOpenMap,
    required this.onSalonTap,
    required this.onMasterTap,
    required this.onOpenFavorites,
    required this.onOpenNotifications,
    required this.onOpenCredits,
    required this.onOpenProfile,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

/// Популярная услуга на главной: [query] — ключ поиска по полю `services` салона.
class _PopularService {
  final String name;
  final String query;
  final String price;
  final String time;
  final IconData icon;

  const _PopularService(this.name, this.query, this.price, this.time, this.icon);
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  late final AppDependencies _deps;
  late final _appState = AppScope.read(context).appState;
  final _searchController = TextEditingController();

  SalonFilterParams _filterParams = const SalonFilterParams();
  String _searchQuery = '';

  // Салоны (по текущим фильтрам) и мастера (для поиска) приходят из каталога
  List<SalonModel> _salons = const [];
  List<MasterProfileModel> _masters = const [];
  bool _salonsLoading = true;
  Object? _salonsError;
  int _salonsRequestId = 0;

  static const _popularServices = [
    _PopularService('Маникюр комплекс', 'Маникюр', '34 кр.', '60 мин', Icons.back_hand_outlined),
    _PopularService('Женская стрижка', 'Стрижки', '40 кр.', '45 мин', Icons.content_cut),
    _PopularService('Ламинирование ресниц', 'Ресницы', '28 кр.', '90 мин', Icons.remove_red_eye_outlined),
    _PopularService('Окрашивание волос', 'Окрашивание', '75 кр.', '120 мин', Icons.palette_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _deps = AppScope.read(context);
    _appState.addListener(_onAppStateChanged);
    unawaited(_loadSalons());
    unawaited(_loadMasters());
  }

  /// Любое изменение фильтров: сохраняем и перезагружаем список салонов
  void _setFilter(SalonFilterParams params) {
    setState(() => _filterParams = params);
    unawaited(_loadSalons());
  }

  Future<void> _loadSalons() async {
    final requestId = ++_salonsRequestId;
    setState(() {
      _salonsLoading = true;
      _salonsError = null;
    });
    try {
      final result = await _deps.catalog.getSalons(_filterParams);
      // Ответ на устаревший запрос (фильтр успели сменить) отбрасываем
      if (!mounted || requestId != _salonsRequestId) return;
      setState(() {
        _salons = result;
        _salonsLoading = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted || requestId != _salonsRequestId) return;
      setState(() {
        _salonsLoading = false;
        _salonsError = e;
      });
    }
  }

  /// Мастера нужны только для поиска; если загрузить не удалось, поиск идёт по салонам
  Future<void> _loadMasters() async {
    try {
      final masters = await _deps.catalog.getMasters();
      if (mounted) setState(() => _masters = masters);
    } on RepositoryException {
      // не критично
    }
  }

  void _onAppStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Мастера, подходящие под поисковый запрос (по имени или специализации)
  List<MasterProfileModel> _matchingMasters() {
    if (_searchQuery.isEmpty) return const [];
    final q = _searchQuery.toLowerCase();
    return _masters.where((m) => m.name.toLowerCase().contains(q) || m.specialty.toLowerCase().contains(q)).toList();
  }

  /// Выбор района из шапки — тот же фильтр district, что и в модалке фильтров
  void _openDistrictPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final options = <String?>[null, ...SalonsRepository.tashkentDistricts];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.handle, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Район Ташкента',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: options.map((district) {
                      final isSelected = _filterParams.district == district;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        leading: Icon(
                          district == null ? Icons.location_city_outlined : Icons.place_outlined,
                          color: isSelected ? AppColors.primary : AppColors.muted,
                        ),
                        title: Text(
                          district ?? 'Все районы',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? AppColors.primary : AppColors.ink,
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _setFilter(
                            district == null
                                ? _filterParams.copyWith(clearDistrict: true)
                                : _filterParams.copyWith(district: district),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Где сделать популярную услугу: список салонов, у которых она есть
  Future<void> _openServiceSalons(_PopularService service) async {
    final List<SalonModel> salons;
    try {
      salons = (await _deps.catalog.getSalons())
          .where((s) => s.services.toLowerCase().contains(service.query.toLowerCase()))
          .toList();
    } on RepositoryException catch (e) {
      if (mounted) showAppSnack(context, e.message);
      return;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.handle, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  service.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'от ${service.price} · ${service.time} · ${Formatters.plural(salons.length, 'салон', 'салона', 'салонов')}',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: salons.length,
                  itemBuilder: (_, index) {
                    final s = salons[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          s.imageAsset,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 52,
                            height: 52,
                            color: AppColors.primaryTint,
                            child: const Icon(Icons.storefront, color: AppColors.primary),
                          ),
                        ),
                      ),
                      title: Text(
                        s.name,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                      subtitle: Text(
                        '★ ${s.rating} · ${s.district} · ${s.distance}',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      trailing: Icon(Icons.chevron_right, color: AppColors.muted),
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onSalonTap(s.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFilterModal() {
    SearchFilterModal.show(
      context: context,
      currentParams: _filterParams,
      onApply: _setFilter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final matchingMasters = _matchingMasters();
    final masterSalonNames = matchingMasters.map((m) => m.salonName).toSet();

    // Получаем список салонов через репозиторий с учетом фильтров.
    // Поиск: название, услуги, район или мастер, работающий в салоне.
    final filteredSalons = _salons.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.name.toLowerCase().contains(q) ||
          s.services.toLowerCase().contains(q) ||
          s.district.toLowerCase().contains(q) ||
          masterSalonNames.contains(s.name);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          bottom: false,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  if (_filterParams.hasActiveFilters) ...[const SizedBox(height: 10), _buildActiveFilterChips()],
                  if (matchingMasters.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildMatchingMasters(matchingMasters),
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
      ),
    );
  }

  Widget _buildMatchingMasters(List<MasterProfileModel> masters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
          child: Text(
            'Мастера (${masters.length})',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 76,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
            scrollDirection: Axis.horizontal,
            itemCount: masters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final m = masters[index];
              return AppCard(
                padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
                onTap: () => widget.onMasterTap(m.id),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryTint,
                      backgroundImage: AssetImage(m.avatarAsset),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${m.specialty} · ${m.salonName}',
                          style: TextStyle(fontSize: 11, color: AppColors.muted),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onOpenProfile,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryTint,
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              child: ClipOval(
                child: Image(
                  image: avatarProvider(_appState.clientAvatar),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.person, color: AppColors.primary, size: 26),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _openDistrictPicker,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ташкент', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _filterParams.district ?? 'Все районы',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.ink, fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.ink),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildTopIcon(Icons.favorite_border, onTap: widget.onOpenFavorites),
          const SizedBox(width: 10),
          _buildTopIcon(
            Icons.notifications_none_rounded,
            onTap: widget.onOpenNotifications,
            badge: _appState.unreadNotificationsCount,
          ),
        ],
      ),
    );
  }

  Widget _buildTopIcon(IconData icon, {VoidCallback? onTap, int badge = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildTopIconCircle(icon),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopIconCircle(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Icon(icon, color: AppColors.ink, size: 22),
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: AppColors.muted, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: InputDecoration(
                        hintText: tr('Услуга, салон или мастер'),
                        hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                        border: InputBorder.none,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: AppColors.muted),
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
                  child: Icon(Icons.tune, color: activeCount > 0 ? Colors.white : AppColors.ink, size: 22),
                ),
                if (activeCount > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
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
                _setFilter(_filterParams.copyWith(clearDistrict: true));
              }),
            if (_filterParams.onlyWomen)
              _buildFilterChip('Только для женщин', () {
                _setFilter(_filterParams.copyWith(onlyWomen: false));
              }),
            if (_filterParams.homeVisit)
              _buildFilterChip('Выезд на дом', () {
                _setFilter(_filterParams.copyWith(homeVisit: false));
              }),
            if (_filterParams.creditsOnly)
              _buildFilterChip('По кредитам', () {
                _setFilter(_filterParams.copyWith(creditsOnly: false));
              }),
            if (_filterParams.availableToday)
              _buildFilterChip('Свободно сегодня', () {
                _setFilter(_filterParams.copyWith(availableToday: false));
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
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: AppColors.primaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: GestureDetector(
        onTap: widget.onOpenCredits,
        child: Container(
          width: double.infinity,
          height: 160,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            gradient: AppGradients.promo,
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                bottom: -40,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.14)),
                ),
              ),
              Positioned(
                right: 40,
                top: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.08)),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 60, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
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
                    Text(
                      'Все салоны красоты\nв одной подписке',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'От 249 000 сум/мес за 60 кредитов',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryText),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        Padding(
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
                  final name = cat['name'] as String;
                  // Повторный тап по активной категории сбрасывает её на «Все»
                  _setFilter(
                    (isSelected || name == 'Все')
                        ? _filterParams.copyWith(clearCategory: true)
                        : _filterParams.copyWith(serviceCategory: name),
                  );
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
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
        if (_salonsLoading || _salonsError != null)
          AsyncSection(
            isLoading: _salonsLoading,
            error: _salonsError,
            onRetry: () => unawaited(_loadSalons()),
            minHeight: 140,
            child: const SizedBox.shrink(),
          )
        else if (salons.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
            child: Center(
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
                return SizedBox(
                  width: 220,
                  child: AppCard(
                    onTap: () => widget.onSalonTap(s.id),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                s.imageAsset,
                                height: 105,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  height: 105,
                                  color: AppColors.soft(Colors.pink.shade50),
                                  child: const Center(
                                    child: Icon(Icons.storefront, size: 40, color: AppColors.primary),
                                  ),
                                ),
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
                                  child: const Text(
                                    'Женский',
                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.name,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.district} · ${s.distance}',
                          style: TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.minPriceLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryText,
                              ),
                            ),
                            AppStatusBadge(text: s.workingHours),
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

  Widget _buildPopularServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
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
            itemCount: _popularServices.length,
            separatorBuilder: (_, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final s = _popularServices[index];
              return SizedBox(
                width: 135,
                child: AppCard(
                  padding: const EdgeInsets.all(8),
                  onTap: () => _openServiceSalons(s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Icon(s.icon, color: AppColors.primary, size: 28)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.name,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(s.time, style: TextStyle(fontSize: 10, color: AppColors.muted)),
                      const Spacer(),
                      Text(
                        'от ${s.price}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryText),
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
