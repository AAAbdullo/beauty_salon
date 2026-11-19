import 'package:flutter/material.dart' hide Text;
import '../../core/l10n/app_text.dart';
import '../../core/data/app_scope.dart';
import '../../core/data/repository_exception.dart';
import '../../core/models/master_review.dart';
import '../../core/models/portfolio_work.dart';
import '../../core/widgets/avatars/avatar_image.dart';
import '../../core/services/masters_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons/app_gradient_button.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons/app_pill_button.dart';
import '../../core/widgets/cards/app_card.dart';
import '../../core/widgets/layout/fixed_height_box.dart';
import '../../core/widgets/sheets/app_sheet.dart';
import '../../core/widgets/states/async_screen.dart';
import '../../core/widgets/states/not_found_screen.dart';
import '../reviews/review_widgets.dart';
import 'photo_viewer.dart';
import '../../core/l10n/app_locale.dart';

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
  late final _appState = AppScope.read(context).appState;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _master = widget.master;
    _appState.addListener(_onStateChanged);
    _loadReviews();
    _loadWorks();
  }

  // --- Портфолио: работы мастера (сначала закреплённые), фильтр по услуге
  List<PortfolioWork> _works = const [];
  bool _worksLoading = true;
  String? _worksError;
  String? _serviceFilter; // название услуги; null — «Все»

  Future<void> _loadWorks() async {
    setState(() {
      _worksLoading = true;
      _worksError = null;
    });
    try {
      final works = await AppScope.read(context).portfolio.works(_master.id);
      if (!mounted) return;
      setState(() {
        _works = works;
        _worksLoading = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _worksLoading = false;
        _worksError = e.message;
      });
    }
  }

  List<PortfolioWork> get _visibleWorks =>
      _serviceFilter == null ? _works : _works.where((w) => w.serviceName == _serviceFilter).toList();

  /// Просмотр фото работы: услуга, цена, подпись и «Записаться на эту услугу» — тот же путь записи, что у нижней панели
  void _openWork(List<PortfolioWork> works, int index) {
    PhotoViewer.show(
      context,
      photos: [for (final w in works) w.imageRef],
      initialIndex: index,
      footerBuilder: (ctx, i) => _WorkFooter(
        work: works[i],
        service: _master.services.where((s) => s.id == works[i].serviceId).firstOrNull,
        onBook: (service) {
          Navigator.of(ctx).pop(); // закрыть просмотр, затем открыть запись
          widget.onBookMaster(_master, service);
        },
      ),
    );
  }

  // --- Отзывы: сводка и список страницами по 20 (свежие сверху)
  ReviewSummary? _summary;
  final List<MasterReview> _reviews = [];
  String? _nextCursor;
  bool _reviewsLoading = true;
  bool _loadingMore = false;
  String? _reviewsError;

  Future<void> _loadReviews() async {
    setState(() {
      _reviewsLoading = true;
      _reviewsError = null;
    });
    try {
      final repo = AppScope.read(context).reviews;
      final summary = await repo.masterSummary(_master.id);
      final page = await repo.masterReviews(_master.id);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _reviews
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _reviewsLoading = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewsLoading = false;
        _reviewsError = e.message;
      });
    }
  }

  Future<void> _loadMoreReviews() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await AppScope.read(context).reviews.masterReviews(_master.id, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loadingMore = false;
      });
    } on RepositoryException catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      showAppSnack(context, e.message);
    }
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
            icon: Icon(Icons.arrow_back, color: AppColors.ink, size: 20),
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
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.surface, width: 3),
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
                          border: Border.all(color: AppColors.surface, width: 2),
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
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _master.specialty,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText),
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
                    _master.reviewsCount == 0 ? '—' : '${_master.rating}',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primaryText),
                  ),
                  Text(' (${_master.reviewsCount})', style: TextStyle(color: AppColors.muted, fontSize: 11)),
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
              Icon(Icons.storefront, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                'Салон: ${_master.salonName}',
                style: TextStyle(
                  color: widget.onOpenSalon == null ? AppColors.muted : AppColors.primaryText,
                  fontSize: 13,
                  fontWeight: widget.onOpenSalon == null ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
              if (widget.onOpenSalon != null) Icon(Icons.chevron_right, size: 16, color: AppColors.primaryText),
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
          Text(_master.about, style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
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
        tabs: [
          Tab(text: tr('Услуги')),
          Tab(text: tr('Портфолио')),
          Tab(text: tr('Отзывы')),
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
                      Text(s.duration, style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${s.creditsPrice} кр.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primaryText),
                    ),
                    Text(
                      Formatters.formatSum(s.sumPrice),
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
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
    if (_worksLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }
    if (_worksError != null) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            Text(_worksError!, textAlign: TextAlign.center),
            TextButton(onPressed: _loadWorks, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (_works.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(Icons.photo_library_outlined, size: 40, color: AppColors.muted),
              const SizedBox(height: 8),
              Text('Мастер ещё не добавил работы', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    final visible = _visibleWorks;
    final serviceNames = <String>[
      for (final name in {for (final w in _works) w.serviceName}) name,
    ];
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: FixedHeightBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('Все', _serviceFilter == null, () => setState(() => _serviceFilter = null)),
                for (final name in serviceNames)
                  _filterChip(name, _serviceFilter == name, () => setState(() => _serviceFilter = name)),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final work = visible[index];
            return GestureDetector(
              onTap: () => _openWork(visible, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.pink.shade50,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(
                        image: ResizeImage.resizeIfNeeded(600, null, avatarProvider(work.imageRef)),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.photo_camera_back_outlined, size: 40, color: AppColors.primary),
                        ),
                      ),
                      if (work.pinned)
                        const Positioned(top: 8, right: 8, child: Icon(Icons.push_pin, size: 16, color: Colors.white)),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            work.serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }, childCount: visible.length),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.ink,
        ),
        showCheckmark: false,
      ),
    );
  }

  // 3. Вкладка Отзывы
  Widget _buildReviewsList() {
    final summary = _summary;
    if (_reviewsLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }
    if (_reviewsError != null || summary == null) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            Text(_reviewsError ?? 'Не удалось загрузить данные. Попробуйте ещё раз.', textAlign: TextAlign.center),
            TextButton(onPressed: _loadReviews, child: const Text('Повторить')),
          ],
        ),
      );
    }
    return SliverList(
      delegate: SliverChildListDelegate([
        ReviewSummaryCard(summary: summary),
        const SizedBox(height: 10),
        if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Отзывов пока нет', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
          ),
        for (final r in _reviews) ReviewCard(review: r),
        if (_nextCursor != null)
          Center(
            child: _loadingMore
                ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppColors.primary))
                : TextButton(onPressed: _loadMoreReviews, child: const Text('Показать ещё')),
          ),
      ]),
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

/// Подпись под фото работы: услуга, цена, подпись мастера и кнопка записи.
/// Если услугу у мастера убрали, кнопки записи нет.
class _WorkFooter extends StatelessWidget {
  final PortfolioWork work;
  final MasterServiceItem? service;
  final ValueChanged<MasterServiceItem> onBook;

  const _WorkFooter({required this.work, required this.service, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final service = this.service;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          work.serviceName,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
        ),
        if (service != null) ...[
          const SizedBox(height: 2),
          Text(
            '${service.creditsPrice} кр. · ${Formatters.formatSum(service.sumPrice)}',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
        if (work.caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(work.caption, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        if (service != null)
          AppGradientButton(text: 'Записаться на эту услугу', onPressed: () => onBook(service))
        else
          Text('Услуга больше не оказывается', style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
