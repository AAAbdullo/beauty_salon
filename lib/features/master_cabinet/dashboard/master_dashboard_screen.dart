import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import '../../../core/l10n/app_text.dart';
import '../../../core/data/app_scope.dart';
import '../../../core/data/repository_exception.dart';
import '../../../core/data/repositories/master_cabinet_repository.dart';
import '../../../core/widgets/states/async_screen.dart';
import '../../../core/services/master_cabinet_store.dart';
import '../../../core/services/masters_repository.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/sheets/app_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/avatars/avatar_image.dart';
import '../../../core/widgets/buttons/app_pill_button.dart';
import '../../../core/widgets/cards/app_card.dart';

class MasterDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenEarnings;
  final VoidCallback onScanQr;

  /// Открыть профиль клиента (из уведомлений и списка клиентов месяца)
  final ValueChanged<String>? onOpenClient;

  const MasterDashboardScreen({
    super.key,
    required this.onOpenSchedule,
    required this.onOpenEarnings,
    required this.onScanQr,
    this.onOpenClient,
  });

  @override
  State<MasterDashboardScreen> createState() => _MasterDashboardScreenState();
}

class _MasterDashboardScreenState extends State<MasterDashboardScreen> {
  // Данные кабинета приходят асинхронно: пока грузятся — индикатор, при сбое — «Повторить»
  MasterDashboardData? _data;
  Object? _error;
  bool _isLoading = true;

  // Секция «Записи»: к ней прокручивает нажатие на плитки «Записи сегодня / завтра»
  final _appointmentsKey = GlobalKey();

  /// ТЗ, раздел 6: мастер видит брони на сегодня и завтра.
  bool _showTomorrow = false;

  // Брони и доход — проекции единого стора записей: обновляемся, когда он меняется
  // (новая запись клиента, отмена, подтверждение визита по QR)
  late final _appState = AppScope.read(context).appState;

  @override
  void initState() {
    super.initState();
    _appState.bookingChanges.addListener(_onStateChanged);
    unawaited(_loadProfile());
    unawaited(_load());
  }

  // Номер последнего запроса: ответ на более старый запрос не должен затереть более новый
  int _loadId = 0;

  Future<void> _load({bool silent = false}) async {
    final id = ++_loadId;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final data = await AppScope.read(context).masterCabinet.dashboard();
      if (mounted && id == _loadId) {
        setState(() {
          _data = data;
          _error = null;
          _isLoading = false;
        });
      }
    } on RepositoryException catch (e) {
      // Тихое обновление не затирает уже показанные данные ошибкой
      if (mounted && !silent && id == _loadId) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  // Записи изменились (новая запись клиента, отмена, визит по QR) — перечитываем данные
  void _onStateChanged() {
    if (mounted) unawaited(_load(silent: true));
  }

  List<MasterAppointment> _appointments({required bool tomorrow}) {
    final data = _data;
    if (data == null) return const [];
    return tomorrow ? data.tomorrow : data.today;
  }

  @override
  void dispose() {
    _appState.bookingChanges.removeListener(_onStateChanged);
    super.dispose();
  }

  VoidCallback get onOpenSchedule => widget.onOpenSchedule;
  VoidCallback get onOpenEarnings => widget.onOpenEarnings;
  VoidCallback get onScanQr => widget.onScanQr;

  int _activeCount({required bool tomorrow}) =>
      _appointments(tomorrow: tomorrow).where((a) => !a.isCancelled).length;

  // Профиль мастера (специализация, услуги) приходит из каталога
  MasterProfileModel? _profile;

  Future<void> _loadProfile() async {
    try {
      final profile = await AppScope.read(context).catalog.getMaster(AppScope.read(context).appState.masterId);
      if (mounted) setState(() => _profile = profile);
    } on RepositoryException {
      // Остаёмся с подписями по умолчанию
    }
  }

  int get _nowMinutes {
    final now = AppClock.now();
    return now.hour * 60 + now.minute;
  }

  /// Ближайшая неотменённая бронь: ещё не закончившаяся сегодня, иначе первая завтрашняя
  ({MasterAppointment appointment, bool tomorrow})? get _nextAppointment {
    final today = _appointments(tomorrow: false).where((a) => a.isActive && a.time.end > _nowMinutes).toList()
      ..sort((a, b) => a.time.start.compareTo(b.time.start));
    if (today.isNotEmpty) return (appointment: today.first, tomorrow: false);
    final tomorrow = _appointments(tomorrow: true).where((a) => a.isActive).toList()
      ..sort((a, b) => a.time.start.compareTo(b.time.start));
    if (tomorrow.isNotEmpty) return (appointment: tomorrow.first, tomorrow: true);
    return null;
  }

  String _startsInLabel(MasterAppointment a, bool tomorrow) {
    if (tomorrow) return 'Завтра в ${formatMinutes(a.time.start)}';
    final diff = a.time.start - _nowMinutes;
    if (diff <= 0) return 'Идёт сейчас';
    if (diff < 60) return 'Через $diff мин';
    return 'Через ${diff ~/ 60} ч ${diff % 60} мин';
  }

  /// Услуги и цены мастера (редактирует администратор салона)
  void _openServices() {
    final services = _profile?.services ?? const <MasterServiceItem>[];
    showAppSheet<void>(
      context: context,
      title: 'Мои услуги',
      subtitle: 'Цены и состав услуг настраивает администратор салона',
      builder: (ctx) => services.isEmpty
          ? Padding(
              padding: EdgeInsets.all(20),
              child: Text('Услуги пока не добавлены', style: TextStyle(color: AppColors.muted)),
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: services
                  .map(
                    (svc) => ListTile(
                      title: Text(svc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      subtitle: Text(svc.duration),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Formatters.formatCredits(svc.creditsPrice),
                            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryText),
                          ),
                          Text(
                            Formatters.formatSum(svc.sumPrice),
                            style: TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.page),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 16),
                _buildMasterHeader(),
                const SizedBox(height: 16),
                AsyncSection(
                  isLoading: _isLoading && _data == null,
                  error: _data == null ? _error : null,
                  onRetry: _load,
                  minHeight: 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMetricsRow(),
                      const SizedBox(height: 20),
                      _buildNextClientCard(),
                      const SizedBox(height: 20),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      KeyedSubtree(key: _appointmentsKey, child: _buildTodayAppointments()),
                    ],
                  ),
                ),
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
                icon: Icon(Icons.notifications_none_rounded, color: AppColors.ink, size: 24),
                onPressed: _openNotifications,
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: Text(
                    '${_data?.notifications.length ?? 0}',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: AppColors.ink, size: 24),
            onPressed: onScanQr,
          ),
        ],
      ),
    );
  }

  Widget _buildMasterHeader() {
    final appState = AppScope.read(context).appState;
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
                ),
                child: ClipOval(
                  child: Image(
                    image: avatarProvider(appState.masterAvatar),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.primaryTint,
                      child: const Icon(Icons.person, color: AppColors.primary, size: 44),
                    ),
                  ),
                ),
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
                    Flexible(
                      child: Text(
                        appState.masterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  _profile?.specialty ?? 'Мастер салона',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  appState.masterSalon,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryText),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(16)),
            child: Text(
              'Сегодня: ${Formatters.plural(_activeCount(tomorrow: false), 'запись', 'записи', 'записей')}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }

  /// Нажатие на «Записи сегодня / завтра»: переключает день и прокручивает к списку записей
  void _showAppointments({required bool tomorrow}) {
    setState(() => _showTomorrow = tomorrow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _appointmentsKey.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.05,
      );
    });
  }

  /// Клиенты текущего месяца: нажатие открывает профиль клиента
  void _openMonthClients() {
    final clients = _data?.monthClients ?? const <MasterMonthClient>[];
    showAppSheet<void>(
      context: context,
      title: 'Клиенты в этом месяце',
      subtitle: clients.isEmpty ? null : 'Нажмите на клиента, чтобы открыть его профиль',
      builder: (ctx) => clients.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text('В этом месяце ещё нет подтверждённых визитов', style: TextStyle(color: AppColors.muted)),
            )
          : ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              children: [
                for (final c in clients)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryTint,
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(Formatters.plural(c.visits, 'визит', 'визита', 'визитов')),
                    trailing: Icon(Icons.chevron_right, color: AppColors.muted),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onOpenClient?.call(c.clientId);
                    },
                  ),
              ],
            ),
    );
  }

  Widget _buildMetricsRow() {
    final metrics = [
      {
        'val': '${_activeCount(tomorrow: false)}',
        'label': 'Записи\nсегодня',
        'icon': Icons.calendar_today_outlined,
        'action': () => _showAppointments(tomorrow: false),
      },
      {
        'val': '${_activeCount(tomorrow: true)}',
        'label': 'Записи\nзавтра',
        'icon': Icons.event_outlined,
        'action': () => _showAppointments(tomorrow: true),
      },
      {
        'val': '${_data?.monthClients.length ?? 0}',
        'label': 'Клиенты\nв этом месяце',
        'icon': Icons.people_outline,
        'action': _openMonthClients,
      },
      {
        'val': Formatters.formatSum(_data?.revenueToday ?? 0).replaceAll(' сум', ''),
        'label': 'Выручка\nсегодня (сум)',
        'icon': Icons.bar_chart_outlined,
        'action': onOpenEarnings,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Row(
        children: metrics.map((m) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AppCard(
                onTap: m['action'] as VoidCallback?,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  children: [
                    Icon(m['icon'] as IconData, size: 18, color: AppColors.primary),
                    const SizedBox(height: 4),
                    Text(
                      m['val'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m['label'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(fontSize: 9, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNextClientCard() {
    final next = _nextAppointment;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ближайший клиент', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              if (next != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.soft(const Color(0xFFFFECEF)), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        _startsInLabel(next.appointment, next.tomorrow),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (next == null)
            AppCard(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.event_available_outlined, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'На сегодня и завтра записей нет',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryTint,
                        backgroundImage: next.appointment.clientAvatar != null
                            ? avatarProvider(next.appointment.clientAvatar!)
                            : null,
                        child: next.appointment.clientAvatar == null
                            ? const Icon(Icons.person, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              next.appointment.clientName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              next.appointment.serviceName,
                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 12, color: AppColors.muted),
                                const SizedBox(width: 4),
                                Text(
                                  next.appointment.time.label,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.location_on_outlined, size: 12, color: AppColors.muted),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    AppScope.read(context).appState.masterSalon,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (!next.tomorrow) ...[
                    const SizedBox(height: 12),
                    AppPillButton(
                      text: 'Принять по QR',
                      width: double.infinity,
                      backgroundColor: AppColors.primary,
                      textColor: Colors.white,
                      height: 38,
                      onPressed: onScanQr,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'title': 'График', 'sub': 'Рабочие дни и часы', 'icon': Icons.calendar_month, 'tap': onOpenSchedule},
      {'title': 'Сканер', 'sub': 'Подтвердить визит', 'icon': Icons.qr_code_scanner, 'tap': onScanQr},
      {'title': 'Доход', 'sub': 'История выплат и баланс', 'icon': Icons.payments_outlined, 'tap': onOpenEarnings},
      {'title': 'Услуги', 'sub': 'Мои услуги и цены', 'icon': Icons.grid_view, 'tap': _openServices},
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
                  child: AppCard(
                    onTap: a['tap'] as VoidCallback?,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(a['icon'] as IconData, size: 20, color: AppColors.primary),
                        const SizedBox(height: 6),
                        Text(
                          a['title'] as String,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          a['sub'] as String,
                          maxLines: 2,
                          style: TextStyle(fontSize: 9, color: AppColors.muted),
                        ),
                      ],
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
    final list = _appointments(tomorrow: _showTomorrow);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _showTomorrow ? 'Записи на завтра' : 'Сегодняшние записи',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              _dayChip('Сегодня', !_showTomorrow, () => setState(() => _showTomorrow = false)),
              const SizedBox(width: 6),
              _dayChip('Завтра', _showTomorrow, () => setState(() => _showTomorrow = true)),
            ],
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Записей нет', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ),
          ...list.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Opacity(
                opacity: item.isCancelled ? 0.55 : 1,
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryTint,
                        child: Icon(Icons.person, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${formatMinutes(item.time.start)}\n${formatMinutes(item.time.end)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.clientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(item.serviceName, style: TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                      if (!item.isActive || _showTomorrow)
                        _statusLabel(item)
                      else
                        AppPillButton(
                          text: 'Принять',
                          backgroundColor: AppColors.primary,
                          textColor: Colors.white,
                          onPressed: onScanQr,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _dayChip(String text, bool selected, VoidCallback onTap) {
    return AppPillButton(
      text: text,
      backgroundColor: selected ? AppColors.primary : AppColors.primaryTint,
      textColor: selected ? Colors.white : AppColors.primaryText,
      onPressed: onTap,
    );
  }

  Widget _statusLabel(MasterAppointment item) {
    final color = item.isCancelled ? AppColors.onSoft(const Color(0xFFD64545)) : AppColors.successText;
    return Text(
      item.status,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    );
  }

  /// ТЗ, раздел 6: мгновенные уведомления о новых бронях и отменах.
  void _openNotifications() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Уведомления', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final n in _data?.notifications ?? const <MasterNotification>[])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: n.isCancellation ? AppColors.soft(const Color(0xFFFFECEF)) : AppColors.successBg,
                    child: Icon(
                      n.isCancellation ? Icons.event_busy_outlined : Icons.event_available_outlined,
                      color: n.isCancellation ? AppColors.onSoft(const Color(0xFFD64545)) : AppColors.successText,
                    ),
                  ),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(n.body),
                  trailing: Text(n.timeAgo, style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  // Нажатие открывает профиль клиента, который записался (или отменил запись)
                  onTap: n.clientId == null || widget.onOpenClient == null
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          widget.onOpenClient!(n.clientId!);
                        },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
