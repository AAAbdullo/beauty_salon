import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/data/app_scope.dart';
import '../../core/data/repositories/catalog_repository.dart';
import '../../core/services/app_state_service.dart';
import '../../core/services/masters_repository.dart';
import '../../core/services/salons_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/badges/app_status_badge.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../../core/widgets/sheets/app_sheet.dart';
import '../../core/widgets/states/async_screen.dart';
import '../../core/widgets/states/not_found_screen.dart';
import 'photo_viewer.dart';

/// Запись из карточки салона: можно сразу передать мастера и/или услугу
typedef SalonBookCallback = void Function({String? masterId, MasterServiceItem? service});

/// Детальная страница салона (ТЗ M-06): галерея, удобства, вкладки Услуги / Мастера / Отзывы / О салоне
class SalonDetailScreen extends StatelessWidget {
  final String salonId;
  final VoidCallback onBack;
  final SalonBookCallback onBook;

  /// Тап по мастеру: передаётся id мастера
  final ValueChanged<String> onMasterTap;

  /// «На карте»: передаётся id салона
  final ValueChanged<String> onShowOnMap;

  const SalonDetailScreen({
    super.key,
    required this.salonId,
    required this.onBack,
    required this.onBook,
    required this.onMasterTap,
    required this.onShowOnMap,
  });

  @override
  Widget build(BuildContext context) {
    // Салон грузится из каталога: загрузка → данные / «не найдено» / ошибка с повтором
    return AsyncScreen<SalonDetails?>(
      title: 'Салон',
      onBack: onBack,
      reloadKey: salonId,
      load: () => AppScope.read(context).catalog.getSalonDetails(salonId),
      builder: (context, details) {
        if (details == null) {
          return NotFoundScreen(
            title: 'Салон',
            message: 'Салон не найден. Возможно, он больше не работает с Go\'zallik.',
            onBack: onBack,
          );
        }
        return _SalonDetailView(
          key: ValueKey(details.salon.id),
          details: details,
          onBack: onBack,
          onBook: onBook,
          onMasterTap: onMasterTap,
          onShowOnMap: onShowOnMap,
        );
      },
    );
  }
}

class _SalonDetailView extends StatefulWidget {
  final SalonDetails details;
  final VoidCallback onBack;
  final SalonBookCallback onBook;
  final ValueChanged<String> onMasterTap;
  final ValueChanged<String> onShowOnMap;

  const _SalonDetailView({
    super.key,
    required this.details,
    required this.onBack,
    required this.onBook,
    required this.onMasterTap,
    required this.onShowOnMap,
  });

  @override
  State<_SalonDetailView> createState() => _SalonDetailViewState();
}

class _SalonDetailViewState extends State<_SalonDetailView> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _appState = AppStateService();

  late final SalonModel _salon;
  late final List<MasterServiceItem> _services;
  late final List<MasterProfileModel> _masters;
  late final List<MasterReviewItem> _reviews;
  late final List<String> _photos;
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final details = widget.details;
    _salon = details.salon;
    _services = details.services;
    _masters = details.masters;
    _reviews = details.reviews;
    _photos = details.photos;
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

  // ---------------------------------------------------------------------------
  // Действия
  // ---------------------------------------------------------------------------

  void _toggleFavorite() {
    final wasFav = _appState.isSalonFavorite(_salon.id);
    _appState.toggleSalonFavorite(_salon.id);
    showAppSnack(
      context,
      wasFav ? 'Салон «${_salon.name}» удалён из Избранного' : 'Салон «${_salon.name}» добавлен в Избранное',
    );
  }

  void _share() {
    // [BACKEND NOTE]: ссылка-приглашение будет вести на deep link / Telegram Mini App
    final link = 'https://gozallik.uz/salon/${_salon.id}';
    Clipboard.setData(ClipboardData(text: '${_salon.name} — $link'));
    showAppSnack(context, 'Ссылка на салон скопирована');
  }

  void _showContacts() {
    showAppSheet<void>(
      context: context,
      title: 'Связаться с салоном',
      subtitle: '${_salon.name} · ${_salon.workingHours}',
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        children: [
          ListTile(
            leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
            title: Text(_salon.phone, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Нажмите, чтобы скопировать номер'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: _salon.phone));
              Navigator.pop(ctx);
              showAppSnack(context, 'Номер салона скопирован');
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
            title: Text(_salon.address, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${_salon.district} район · ${_salon.distance}'),
            trailing: Icon(Icons.chevron_right, color: AppColors.muted),
            onTap: () {
              Navigator.pop(ctx);
              widget.onShowOnMap(_salon.id);
            },
          ),
        ],
      ),
    );
  }

  void _openPhotos(int index) => PhotoViewer.show(context, photos: _photos, initialIndex: index);

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderInfo(),
                  const SizedBox(height: 14),
                  _buildAmenities(),
                  const SizedBox(height: 18),
                  _buildTabs(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  switch (_tabController.index) {
                    case 0:
                      return _buildServicesTab();
                    case 1:
                      return _buildMastersTab();
                    case 2:
                      return _buildReviewsTab();
                    default:
                      return _buildAboutTab();
                  }
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  Widget _circleAction({required IconData icon, required VoidCallback onPressed, Color? color}) {
    final iconColor = color ?? AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: iconColor, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final isFav = _appState.isSalonFavorite(_salon.id);
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 64,
      leading: Center(
        child: _circleAction(icon: Icons.arrow_back, onPressed: widget.onBack),
      ),
      actions: [
        _circleAction(icon: Icons.share_outlined, onPressed: _share),
        _circleAction(
          icon: isFav ? Icons.favorite : Icons.favorite_border,
          color: AppColors.primary,
          onPressed: _toggleFavorite,
        ),
        const SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _photoIndex = i),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openPhotos(index),
                child: Image.asset(
                  _photos[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppColors.primaryTint,
                    child: const Center(child: Icon(Icons.storefront, size: 80, color: AppColors.primary)),
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: GestureDetector(
                onTap: () => _openPhotos(_photoIndex),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '${_photoIndex + 1}/${_photos.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
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
          children: [
            Flexible(
              child: Text(
                _salon.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.verified, color: AppColors.primary, size: 20),
            const Spacer(),
            if (_salon.creditsAccepted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.gold),
                    const SizedBox(width: 4),
                    Text(
                      'У вас ${_appState.clientCredits} кр.',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A5D00)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(_salon.services, style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star, size: 15, color: AppColors.primary),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _tabController.animateTo(2),
              child: Text(
                '${_salon.rating} (${Formatters.reviews(_salon.reviewsCount)})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            AppStatusBadge(text: _salon.workingHours),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${_salon.distance} · ${_salon.address}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => widget.onShowOnMap(_salon.id),
              child: Row(
                children: [
                  Text(
                    'На карте',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: AppColors.primaryText),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Удобства — из реальных атрибутов салона (M-04)
  Widget _buildAmenities() {
    final amenities = <(IconData, String)>[
      if (_salon.creditsAccepted) (Icons.account_balance_wallet_outlined, 'Кредиты'),
      if (_salon.onlyWomen) (Icons.female, 'Женский зал'),
      if (_salon.homeVisit) (Icons.home_outlined, 'Выезд на дом'),
      if (_salon.availableToday) (Icons.event_available_outlined, 'Свободно сегодня'),
      (Icons.credit_card, 'Оплата картой'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amenities.map((a) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(14)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(a.$1, size: 15, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                a.$2,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink),
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
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(text: 'Услуги'),
          Tab(text: 'Мастера'),
          Tab(text: 'Отзывы'),
          Tab(text: 'О салоне'),
        ],
      ),
    );
  }

  // --- Вкладка «Услуги»
  Widget _buildServicesTab() {
    if (_services.isEmpty) {
      return const _EmptyTab(icon: Icons.spa_outlined, text: 'Салон пока не добавил услуги');
    }
    return Column(
      children: _services.map((s) {
        final showCredits = _salon.creditsAccepted && s.creditsPrice > 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => widget.onBook(service: s),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.spa_outlined, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${s.duration} · ${Formatters.formatSum(s.sumPrice)}',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (showCredits)
                      Text(
                        Formatters.formatCredits(s.creditsPrice),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryText),
                      ),
                    const SizedBox(height: 4),
                    AppPillButton(
                      text: 'Записаться',
                      onPressed: () => widget.onBook(service: s),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Вкладка «Мастера»
  Widget _buildMastersTab() {
    if (_masters.isEmpty) {
      return _EmptyTab(
        icon: Icons.groups_2_outlined,
        text: 'Салон подберёт свободного мастера под вашу услугу',
        action: AppPillButton(text: 'Записаться', height: 34, onPressed: () => widget.onBook()),
      );
    }
    return Column(
      children: _masters.map((m) {
        final isFav = _appState.isMasterFavorite(m.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => widget.onMasterTap(m.id),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryTint,
                  backgroundImage: AssetImage(m.avatarAsset),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(m.specialty, style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 13, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(
                            '${m.rating} · ${Formatters.reviews(m.reviewsCount)} · опыт ${Formatters.years(m.experienceYears)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: AppColors.primary, size: 20),
                  onPressed: () => _appState.toggleMasterFavorite(m.id),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- Вкладка «Отзывы»
  Widget _buildReviewsTab() {
    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text('${_salon.rating}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < _salon.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 18,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                    Text(
                      'На основе ${Formatters.reviews(_salon.reviewsCount)} после подтверждённых визитов',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._reviews.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
                  Text(r.date, style: TextStyle(fontSize: 10, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Text(r.comment, style: TextStyle(fontSize: 12, color: AppColors.ink, height: 1.35)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Вкладка «О салоне»
  Widget _buildAboutTab() {
    Widget row(IconData icon, String title, String value, {VoidCallback? onTap}) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: TextStyle(fontSize: 11, color: AppColors.muted)),
        subtitle: Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        trailing: onTap != null ? Icon(Icons.chevron_right, color: AppColors.muted) : null,
        onTap: onTap,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              row(
                Icons.location_on_outlined,
                'Адрес',
                '${_salon.address}, ${_salon.district} район',
                onTap: () => widget.onShowOnMap(_salon.id),
              ),
              row(Icons.schedule, 'Часы работы', _salon.workingHours),
              row(Icons.phone_outlined, 'Телефон', _salon.phone, onTap: _showContacts),
              row(
                Icons.payments_outlined,
                'Цены',
                _salon.creditsAccepted && _salon.minCredits > 0
                    ? 'от ${_salon.minCredits} кр. или ${Formatters.formatSum(_salon.minPriceSum)}'
                    : 'от ${Formatters.formatSum(_salon.minPriceSum)}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text('Фото салона и работ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openPhotos(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    _photos[index],
                    width: 120,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 120,
                      height: 90,
                      color: AppColors.primaryTint,
                      child: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
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

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Material(
              color: AppColors.primaryTint,
              shape: const CircleBorder(),
              child: IconButton(
                iconSize: 22,
                padding: const EdgeInsets.all(13),
                icon: const Icon(Icons.phone, color: AppColors.primary),
                tooltip: 'Связаться с салоном',
                onPressed: _showContacts,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppGradientButton(text: 'Записаться', onPressed: () => widget.onBook()),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _EmptyTab({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 44, color: AppColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
